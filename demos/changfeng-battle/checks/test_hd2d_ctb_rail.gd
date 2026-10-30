extends SceneTree
## Validate the right charge axis as read-only CTB presentation.
const SCENE_PATH := "res://battle_hd2d.tscn"
var failures := 0
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("CHARGE_RAIL: " + message)

func _run() -> void:
    var battle: Node = load(SCENE_PATH).instantiate()
    root.add_child(battle)
    await process_frame
    var hud: Control = battle.get_node_or_null("WuxiaCombatHUD/UnifiedHUD")
    var rail: Control
    if hud != null:
        rail = hud.get_node_or_null("ChargeRail") as Control
    _check(rail != null, "vertical charge track is missing")
    if rail == null:
        quit(1)
        return
    _check(rail.anchor_left == 1.0 and rail.anchor_right == 1.0,
        "track must stay against right edge at multiple resolutions")
    _check(rail.size.x <= 120.0, "track steals too much battlefield width")
    var model = battle.get("model")
    var original: Dictionary = model.snapshot(0)
    var actors: Array = original.get("actors", []).duplicate(true)
    _check(actors.size() >= 2, "demo requires both sides on CTB")
    for i in range(actors.size()):
        actors[i]["gauge"] = 0 if i % 2 == 0 else 10000
    rail.call("set_state", actors, int(original.get("active_id", -1)))
    await process_frame
    for actor in actors:
        var id := int(actor.get("id", -1))
        var portrait: Control = rail.get_node_or_null("Charge_%d" % id)
        _check(portrait != null, "missing portrait for actor %d" % id)
        if portrait != null:
            _check(portrait.visible == (float(actor.get("hp", 0)) > 0.0),
                "dead actors must not have a live CTB marker")
    _check(float(rail.call("gauge_y", 10000.0)) < float(rail.call("gauge_y", 0.0)),
        "higher gauge must appear nearer the top")
    _check(int(model.snapshot(0).get("revision", -1)) == int(original.get("revision", -2)),
        "rendering or testing the axis must not advance game time")
    print("CHARGE_RAIL_RESULT checks=%d failures=%d" % [checks, failures])
    battle.queue_free()
    await process_frame
    quit(1 if failures > 0 else 0)
