extends RefCounted
## R32: typed Resource clips, events and visual cue windows.
## Presentation timing never grants damage, i-frames, or legal actions.
const Native = preload("res://scripts/content/content_registry.gd")
const DEFAULT_PATH := "res://data/native/action_timelines/r32_default.tres"
const DEFAULT_ID := "r32_default_action_timeline"
const REQUIRED := ["idle", "move", "attack", "guard", "hit", "evade", "skill", "combo", "defeat"]
var profiles: Dictionary = {} # id -> WuxiaActionClipDefinition
var event_animations: Dictionary = {} # semantic event -> clip id
var load_error: String = ""

func _init(path: String = DEFAULT_PATH) -> void:
    var definition: Resource
    if path == DEFAULT_PATH:
        var registry = Native.new()
        if not registry.load_error.is_empty():
            load_error = registry.load_error
            return
        definition = registry.resource_for("action_timeline", DEFAULT_ID)
    elif ResourceLoader.exists(path):
        definition = ResourceLoader.load(path)
    if not definition is WuxiaActionTimelineDefinition:
        load_error = "Native action timeline Resource missing or has wrong type"
        return
    var parsed: WuxiaActionTimelineDefinition = definition as WuxiaActionTimelineDefinition
    if parsed.schema_version != 1:
        load_error = "Invalid native action timeline schema"
        return
    var clips: Dictionary = {}
    for entry in parsed.clips:
        if not _valid_profile(entry):
            load_error = "Invalid native action clip"
            return
        var clip_resource: WuxiaActionClipDefinition = entry as WuxiaActionClipDefinition
        var id: String = clip_resource.clip_id
        if clips.has(id):
            load_error = "Duplicate action clip: " + id
            return
        clips[id] = clip_resource
    for id in REQUIRED:
        if not clips.has(id):
            load_error = "Missing action clip: " + id
            return
    var event_map: Dictionary = {}
    for entry in parsed.event_bindings:
        if not entry is WuxiaActionEventBinding:
            load_error = "Invalid native event binding"
            return
        var binding: WuxiaActionEventBinding = entry as WuxiaActionEventBinding
        var event_type: String = binding.event_type
        var id: String = binding.clip_id
        if event_type.is_empty() or not clips.has(id) or event_map.has(event_type):
            load_error = "Invalid or duplicate event clip binding: " + event_type
            return
        event_map[event_type] = id
    profiles = clips
    event_animations = event_map

func _valid_profile(profile: Variant) -> bool:
    return profile is WuxiaActionClipDefinition and profile.valid_clip()

func clip_definition(id: String) -> WuxiaActionClipDefinition:
    return profiles.get(id) as WuxiaActionClipDefinition

## Transitional read API for presentation callers; authored data is typed Resource.
func clip(id: String) -> Dictionary:
    var source: WuxiaActionClipDefinition = clip_definition(id)
    if source == null:
        return {}
    var record: Dictionary = {
        "duration": source.duration_sec,
        "startup": source.startup_sec,
        "active": source.active_sec,
        "recovery": source.recovery_sec
    }
    for kind in ["cancel", "reaction", "invulnerable"]:
        var window: WuxiaActionTimeWindow = source.window(kind)
        if window != null:
            record[kind] = [window.from_sec, window.to_sec]
    if not source.cues.is_empty():
        var cues: Array = []
        for entry in source.cues:
            var cue: WuxiaActionCueDefinition = entry as WuxiaActionCueDefinition
            cues.append({"name": cue.cue_name, "at": cue.at_sec})
        record["cues"] = cues
    return record

func duration_for(id: String, fallback: float = 0.4) -> float:
    var source: WuxiaActionClipDefinition = clip_definition(id)
    return source.duration_sec if source != null else fallback

func animation_for_event(event_type: String) -> String:
    return str(event_animations.get(event_type, ""))

func _clip_time(id: String, elapsed: float, actual_duration: float) -> float:
    var authored: float = duration_for(id, 0.0)
    if authored <= 0.0:
        return 0.0
    var duration: float = actual_duration if actual_duration > 0.0 else authored
    return clampf(elapsed / duration * authored, 0.0, authored)

func phase_at(id: String, elapsed: float, actual_duration: float = -1.0) -> String:
    var source: WuxiaActionClipDefinition = clip_definition(id)
    if source == null:
        return "none"
    var t: float = _clip_time(id, elapsed, actual_duration)
    if t < source.startup_sec:
        return "startup"
    if t < source.startup_sec + source.active_sec:
        return "active"
    return "recovery"

func window_open(id: String, kind: String, elapsed: float,
        actual_duration: float = -1.0) -> bool:
    var source: WuxiaActionClipDefinition = clip_definition(id)
    if source == null:
        return false
    var window: WuxiaActionTimeWindow = source.window(kind)
    return window != null and window.contains(_clip_time(id, elapsed, actual_duration))

func cues_between(id: String, previous: float, current: float,
        actual_duration: float = -1.0) -> Array:
    var result: Array = []
    var source: WuxiaActionClipDefinition = clip_definition(id)
    if source == null:
        return result
    var start: float = _clip_time(id, previous, actual_duration)
    var end: float = _clip_time(id, current, actual_duration)
    for entry in source.cues:
        var cue: WuxiaActionCueDefinition = entry as WuxiaActionCueDefinition
        if start < cue.at_sec and cue.at_sec <= end:
            result.append({"profile": id, "name": cue.cue_name, "at": cue.at_sec})
    return result
