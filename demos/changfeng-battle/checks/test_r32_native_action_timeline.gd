extends SceneTree
## R32: all nine clips and thirteen semantic event bindings are typed .tres cards.
const Native = preload("res://scripts/content/content_registry.gd")
const Timeline = preload("res://scripts/battle_action_timeline.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("R32_NATIVE_TIMELINE: " + label)

func same(a: Variant, b: Variant) -> bool:
    if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
        return is_equal_approx(float(a), float(b))
    if a is Array and b is Array:
        if a.size() != b.size(): return false
        for i in range(a.size()):
            if not same(a[i], b[i]): return false
        return true
    if a is Dictionary and b is Dictionary:
        if a.size() != b.size(): return false
        for key in a:
            if not b.has(key) or not same(a[key], b[key]): return false
        return true
    return a == b

func _run() -> void:
    var native = Native.new()
    check(native.load_error.is_empty(), "native manifest imports")
    check(native.document("r25_action_timelines").is_empty(),
        "opaque action timeline document removed from production")
    var entry: Dictionary = native.entries("action_timeline").get(
        "r32_default_action_timeline", {})
    check(entry.get("clip_count", -1) == 9 and entry.get("event_count", -1) == 13,
        "manifest registers the authored clip and event counts")
    var definition: Resource = native.resource_for(
        "action_timeline", "r32_default_action_timeline")
    check(definition is WuxiaActionTimelineDefinition,
        "runtime receives typed timeline Resource")
    if not definition is WuxiaActionTimelineDefinition:
        quit(1)
        return
    var timeline = Timeline.new()
    check(timeline.load_error.is_empty(), "typed timeline validates: " + timeline.load_error)
    var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(
        "res://data/action_timelines.json"))
    check(old is Dictionary, "historical fixture is test-only")
    if not old is Dictionary:
        quit(1)
        return
    check(timeline.profiles.size() == old.profiles.size() and
        timeline.event_animations.size() == old.events.size(),
        "no clips or event mappings lost")
    for id in old.profiles:
        var clip: WuxiaActionClipDefinition = timeline.clip_definition(str(id))
        check(clip != null and clip.valid_clip(),
            "typed clip exists and validates: " + str(id))
        check(same(timeline.clip(str(id)), old.profiles[id]),
            "all phase, window and cue values unchanged: " + str(id))
    for event in old.events:
        check(timeline.animation_for_event(str(event)) == str(old.events[event]),
            "event binding unchanged: " + str(event))
    var invalid := WuxiaActionClipDefinition.new()
    invalid.clip_id = "invalid"
    invalid.duration_sec = 0.5
    invalid.startup_sec = 0.4
    invalid.active_sec = 0.4
    invalid.recovery_sec = 0.1
    check(not invalid.valid_clip() and not timeline._valid_profile(invalid),
        "invalid typed phase sum is rejected")
    var attack: WuxiaActionClipDefinition = timeline.clip_definition("attack")
    var broken := WuxiaActionClipDefinition.new()
    broken.clip_id = "broken"
    broken.duration_sec = attack.duration_sec
    broken.startup_sec = attack.startup_sec
    broken.active_sec = attack.active_sec
    broken.recovery_sec = attack.recovery_sec
    var invalid_window := WuxiaActionTimeWindow.new()
    invalid_window.from_sec = 0.65
    invalid_window.to_sec = 0.75
    broken.cancel_window = invalid_window
    check(not broken.valid_clip() and attack.valid_clip(),
        "out-of-bounds typed window rejects without mutating shared content")
    var duplicate_loader = Timeline.new(
        "res://data/native/action_timelines/r32_default.tres")
    check(duplicate_loader.load_error.is_empty() and
        same(duplicate_loader.clip("combo"), old.profiles.combo),
        "explicit .tres authoring path has identical semantics")
    check(timeline.window_open("evade", "invulnerable", 0.15) and
        not timeline.window_open("evade", "invulnerable", 0.35),
        "visual window is still a read-only presentation query")
    check(timeline.cues_between("attack", 0.0, 0.2).size() == 1,
        "native cue tracks keep authored trigger times")
    print("R32_NATIVE_TIMELINE_PASS failures=", failures)
    quit(1 if failures > 0 else 0)
