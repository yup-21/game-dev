extends SceneTree
## R10: action timings are data, while BattleModel stays deterministic.
const Timeline = preload("res://scripts/battle_action_timeline.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("R10_ACTION_TIMELINE: " + reason)

func _run() -> void:
    var clips = Timeline.new()
    _check(clips.load_error.is_empty(), "authored action clips validate")
    _check(is_equal_approx(clips.duration_for("attack"), 0.62),
        "attack keeps existing total duration")
    _check(clips.phase_at("attack",0.08)=="startup" and
        clips.phase_at("attack",0.22)=="active" and
        clips.phase_at("attack",0.50)=="recovery",
        "startup, active and recovery are deterministic")
    _check(clips.window_open("attack","cancel",0.45) and
        not clips.window_open("attack","cancel",0.15),
        "cancel window is authored and bounded")
    _check(clips.window_open("evade","invulnerable",0.15) and
        not clips.window_open("evade","invulnerable",0.35),
        "visual evade window is queryable without granting rule permissions")
    _check(clips.cues_between("attack",0.0,0.24).size()==1,
        "semantic strike cue is scheduled at its authored time")
    _check(clips.animation_for_event("MOVE_FREE")=="move" and
        clips.animation_for_event("COMBO_TRIGGERED")=="combo",
        "semantic events select authored clips")
    var invalid := WuxiaActionClipDefinition.new()
    invalid.clip_id = "invalid"
    invalid.duration_sec = 0.5
    invalid.startup_sec = 0.4
    invalid.active_sec = 0.4
    invalid.recovery_sec = 0.1
    _check(not clips._valid_profile(invalid),"invalid typed clip duration is rejected")
    var scene: Node2D = load("res://battle_hd2d.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var model = scene.get("model")
    var revision: int=int(model.state.revision)
    var presenter = scene.get("presentation_player")
    presenter.consume([{"type":"ATTACK_DECLARED","actor_id":0,
        "target_id":1}],scene.get("actor_nodes"))
    _check(presenter.phase()=="startup","live animator begins authored startup")
    presenter.tick(0.22,{},false)
    _check(presenter.phase()=="active","live animator enters active stage")
    _check(not presenter.take_action_cues().is_empty(),
        "presentation exposes cues without writing rules")
    _check(int(model.state.revision)==revision and
        not model.state.animation_pending,"timeline playback never commits combat")
    print("R10_ACTION_TIMELINE_PASS failures=%d" % failures)
    quit(1 if failures else 0)
