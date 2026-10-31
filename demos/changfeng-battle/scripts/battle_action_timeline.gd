extends RefCounted
## R10: validated, data-driven action clips and semantic cue windows.
## Presentation metadata NEVER grants invulnerability, damage, or legal actions.
const DEFAULT_PATH := "res://data/action_timelines.json"
const REQUIRED := ["idle","move","attack","guard","hit","evade","skill","combo","defeat"]
const Native = preload("res://scripts/content/content_registry.gd")
var profiles: Dictionary = {}
var event_animations: Dictionary = {}
var load_error: String = ""

func _init(path: String = DEFAULT_PATH) -> void:
    if path != DEFAULT_PATH and not FileAccess.file_exists(path):
        load_error = "Action timeline catalog missing"
        return
    var parsed: Variant = Native.new().document("r25_action_timelines") if path == DEFAULT_PATH else JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary or parsed.get("schema_version") != 1 or not parsed.get("profiles") is Dictionary or not parsed.get("events") is Dictionary:
        load_error = "Invalid action timeline schema"
        return
    for id in REQUIRED:
        if not parsed.profiles.has(id) or not _valid_profile(parsed.profiles[id]):
            load_error = "Invalid action clip: " + id
            return
    for name in parsed.events:
        if not name is String or not parsed.events[name] is String or not parsed.profiles.has(parsed.events[name]):
            load_error = "Invalid semantic event animation mapping"
            return
    profiles = parsed.profiles.duplicate(true)
    event_animations = parsed.events.duplicate(true)

func _valid_profile(profile: Variant) -> bool:
    if not profile is Dictionary:
        return false
    for key in ["duration","startup","active","recovery"]:
        if not profile.has(key) or not (profile[key] is float or profile[key] is int):
            return false
        if not is_finite(float(profile[key])) or float(profile[key]) < 0.0:
            return false
    var duration: float = float(profile.duration)
    if duration <= 0.0 or absf(float(profile.startup) + float(profile.active) +
            float(profile.recovery) - duration) > 0.002:
        return false
    for name in ["cancel","reaction","invulnerable"]:
        if not profile.has(name):
            continue
        var window: Variant = profile[name]
        if not window is Array or window.size() != 2 or not (window[0] is float or window[0] is int) or not (window[1] is float or window[1] is int):
            return false
        if not is_finite(float(window[0])) or not is_finite(float(window[1])) or float(window[0]) < 0.0 or float(window[0]) >= float(window[1]) or float(window[1]) > duration + 0.001:
            return false
    if not profile.get("cues", []) is Array:
        return false
    for cue in profile.get("cues", []):
        if not cue is Dictionary or not cue.get("name") is String or not (cue.get("at") is float or cue.get("at") is int):
            return false
        if not is_finite(float(cue.at)) or float(cue.at) < 0.0 or float(cue.at) > duration:
            return false
    return true

func clip(id: String) -> Dictionary:
    return profiles.get(id, {}).duplicate(true)

func duration_for(id: String, fallback: float = 0.4) -> float:
    return float(profiles.get(id, {}).get("duration", fallback))

func animation_for_event(event_type: String) -> String:
    return str(event_animations.get(event_type, ""))

func _clip_time(id: String, elapsed: float, actual_duration: float) -> float:
    var authored: float = duration_for(id, 0.0)
    if authored <= 0.0:
        return 0.0
    var duration: float = actual_duration if actual_duration > 0.0 else authored
    return clampf(elapsed / duration * authored, 0.0, authored)

func phase_at(id: String, elapsed: float, actual_duration: float = -1.0) -> String:
    var profile: Dictionary = profiles.get(id, {})
    if profile.is_empty():
        return "none"
    var t: float = _clip_time(id, elapsed, actual_duration)
    if t < float(profile.startup):
        return "startup"
    if t < float(profile.startup) + float(profile.active):
        return "active"
    return "recovery"

func window_open(id: String, kind: String, elapsed: float,
        actual_duration: float = -1.0) -> bool:
    if kind not in ["cancel","reaction","invulnerable"]:
        return false
    var window: Array = profiles.get(id, {}).get(kind, [])
    if window.size() != 2:
        return false
    var t: float = _clip_time(id, elapsed, actual_duration)
    return t >= float(window[0]) and t < float(window[1])

func cues_between(id: String, previous: float, current: float,
        actual_duration: float = -1.0) -> Array:
    var found: Array = []
    var profile: Dictionary = profiles.get(id, {})
    if profile.is_empty():
        return found
    var start: float = _clip_time(id, previous, actual_duration)
    var end: float = _clip_time(id, current, actual_duration)
    for cue in profile.get("cues", []):
        var at: float = float(cue.at)
        if start < at and at <= end:
            found.append({"profile":id,"name":str(cue.name),"at":at})
    return found
