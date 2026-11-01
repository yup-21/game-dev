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

func _run() -> void:
    var native = Native.new()
    check(native.load_error.is_empty(), "native manifest imports")
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
    check(timeline.profiles.size() == 9 and timeline.event_animations.size() == 13,
        "all nine clips and thirteen semantic events registered")
    for id in timeline.profiles:
        var clip: WuxiaActionClipDefinition = timeline.clip_definition(str(id))
        check(clip != null and clip.valid_clip(), "typed clip validates: " + str(id))
    check(timeline.animation_for_event("ATTACK_DECLARED") == "attack"
        and timeline.animation_for_event("COMBO_TRIGGERED") == "combo"
        and timeline.animation_for_event("HP_DAMAGED") == "hit",
        "fixed gameplay event-to-animation bindings")
    check(timeline.phase_at("attack", 0.1) == "startup"
        and timeline.phase_at("attack", 0.2) == "active"
        and timeline.phase_at("attack", 0.4) == "recovery",
        "fixed attack startup, active and recovery windows")
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
    check(timeline.window_open("evade", "invulnerable", 0.15) and
        not timeline.window_open("evade", "invulnerable", 0.35),
        "visual window is still a read-only presentation query")
    check(timeline.cues_between("attack", 0.0, 0.2).size() == 1,
        "native cue tracks keep authored trigger times")
    print("R32_NATIVE_TIMELINE_PASS failures=", failures)
    quit(1 if failures > 0 else 0)
