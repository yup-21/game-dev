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
    var hud: Control = battle.get_node_or_null("WuxiaCombatHUD/UnifiedHUD") as Control
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
        var portrait: Control = rail.get_node_or_null("Charge_%d" % id) as Control
        _check(portrait != null, "missing portrait for actor %d" % id)
        if portrait != null:
            _check(portrait.visible == (float(actor.get("hp", 0)) > 0.0),
                "dead actors must not have a live CTB marker")
    _check(float(rail.call("gauge_y", 10000.0)) < float(rail.call("gauge_y", 0.0)),
        "higher gauge must appear nearer the top")

    # Both sides remain vertically aligned to the same CTB progress, but
    # allied portraits meet the LEFT edge of the axis and enemies the RIGHT.
    var shared_charge: Array = actors.duplicate(true)
    for actor in shared_charge:
        actor["gauge"] = 0
    rail.call("set_state", shared_charge, int(original.get("active_id", -1)))
    rail.call("_process", 1.0)
    var live_portraits: Array[Control] = []
    var ally_portrait: Control
    var enemy_portrait: Control
    for actor in shared_charge:
        if float(actor.get("hp", 0.0)) <= 0.0:
            continue
        var marker := rail.get_node_or_null("Charge_%d" % int(actor.id)) as Control
        if marker == null:
            continue
        live_portraits.append(marker)
        var enemy := int(actor.get("team_id", 0)) != 0
        var inner_edge := marker.position.x if enemy else marker.position.x + marker.size.x
        _check(absf(inner_edge - rail.size.x * 0.5) < 0.1,
            "portrait inner edge must directly touch the CTB axis")
        _check(absf(marker.position.y + marker.size.y * 0.5 -
            float(rail.call("gauge_y", 0.0))) < 0.1,
            "equal charge must use its exact unshifted rail position")
        if enemy:
            enemy_portrait = marker
        else:
            ally_portrait = marker
    _check(ally_portrait != null and enemy_portrait != null,
        "rail test requires both allies and enemies")
    if ally_portrait != null and enemy_portrait != null:
        _check(ally_portrait.position.x < enemy_portrait.position.x and
            absf(ally_portrait.position.y - enemy_portrait.position.y) < 0.1,
            "opposing teams at equal charge must face across the shaft")

    _check(live_portraits.size() >= 2, "overlap test requires two live portraits")
    if live_portraits.size() >= 2:
        # Make two fixture actors allies to verify that same-team collisions
        # never offset their gauge positions, even if their markers overlap.
        var fixture: Array = shared_charge.duplicate(true)
        var first_id := int(live_portraits[0].get_meta("actor_id"))
        var second_id := int(live_portraits[1].get_meta("actor_id"))
        for actor in fixture:
            if int(actor.get("id", -1)) == first_id or int(actor.get("id", -1)) == second_id:
                actor["team_id"] = 0
        rail.call("set_state", fixture, int(original.get("active_id", -1)))
        rail.call("_process", 1.0)
        _check(live_portraits[0].position.distance_to(live_portraits[1].position) < 0.1,
            "same-team equal charge must still permit full overlap")
        rail.call("set_state", shared_charge, int(original.get("active_id", -1)))
        rail.call("_process", 1.0)

        # CTB model updates provide targets; the visual cursor glides to them
        # without mutating model time or teleporting instantaneously.
        var moved: Array = shared_charge.duplicate(true)
        var moving_id := int(live_portraits[0].get_meta("actor_id"))
        for actor in moved:
            if int(actor.get("id", -1)) == moving_id:
                actor["gauge"] = 10000
        var moving_marker := rail.get_node_or_null("Charge_%d" % moving_id) as Control
        var initial_y := moving_marker.position.y
        rail.call("set_state", moved, int(original.get("active_id", -1)))
        _check(absf(moving_marker.position.y - initial_y) < 0.1,
            "new CTB value must start animating from the displayed position")
        rail.call("_process", 0.1)
        var halfway_y := moving_marker.position.y
        var finish_y := float(rail.call("gauge_y", 10000.0)) - moving_marker.size.y * 0.5
        _check(halfway_y < initial_y and halfway_y > finish_y,
            "portrait must glide vertically between old and new gauge values")
        rail.call("_process", 1.0)
        _check(absf(moving_marker.position.y - finish_y) < 0.1,
            "portrait glide must finish at the exact authoritative gauge")
    _check(int(model.snapshot(0).get("revision", -1)) == int(original.get("revision", -2)),
        "rendering or testing the axis must not advance game time")
    print("CHARGE_RAIL_RESULT checks=%d failures=%d" % [checks, failures])
    battle.queue_free()
    await process_frame
    quit(1 if failures > 0 else 0)
