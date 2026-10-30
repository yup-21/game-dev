extends SceneTree
## Hand visibility is sourced from the private owner snapshot, not the set
## of currently legal actions. Eligible distant attacks now stay clickable
## for automatic approach; other unavailable attacks remain visible and disabled.
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, why: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("HAND_VISIBILITY: " + why)

func _rendered_cards(view: Node) -> Dictionary:
    var found: Dictionary = {}
    var buttons: HBoxContainer = view.get("card_actions") as HBoxContainer
    for node in buttons.get_children():
        if not node is Button or not node.has_meta("card_uid"):
            continue
        var uid := str(node.get_meta("card_uid"))
        if not found.has(uid):
            found[uid] = []
        found[uid].append(node)
    return found

func _run() -> void:
    var packed := load("res://battle_hd2d.tscn") as PackedScene
    _check(packed != null, "HD-2D scene must load")
    if packed == null:
        quit(1)
        return
    var view: Node3D = packed.instantiate() as Node3D
    root.add_child(view)
    await process_frame
    var model = view.get("model")
    _check(model.state.mode == "ACTION" and int(model.state.active_id) == 0,
        "quick demo begins with the player making a decision")
    var initial: Dictionary = model.snapshot(0)
    var drawn: Dictionary = {}
    var attack_uids: Dictionary = {}
    for card in initial.get("hand", []):
        var uid := str(card.get("uid", ""))
        drawn[uid] = true
        for usage in card.get("usages", []):
            if str(usage.get("timing", "")) == "ACTION" and str(usage.get("target", {}).get("kind", "")) == "enemy_actor":
                attack_uids[uid] = true
    _check(drawn.size() == 5, "first draw has five actual card instances")
    _check(attack_uids.size() > 0, "seeded 12-card school deck draws actual attacks")
    _check(model.state.spatial_mode=="GRID","legacy grid mode remains default")
    var grid_rendered: Dictionary = _rendered_cards(view)
    var grey_attacks := 0
    for uid in attack_uids:
        for button in grid_rendered.get(uid,[]):
            if button.disabled: grey_attacks+=1
    _check(grey_attacks>0,"grid mode still greys out-of-range attacks")
    var mode_change: Dictionary=model.submit(model.request("SET_SPATIAL_MODE",0,{"spatial_mode":"FREE"}))
    _check(bool(mode_change.get("success",false)),"switch to free mode through the battle model")
    if not bool(mode_change.get("success",false)):
        view.queue_free()
        quit(1)
        return
    view.call("_accept",mode_change)
    var acknowledged: Dictionary=model.acknowledge_animation(int(mode_change.ticket))
    view.set("animation_ticket",-1)
    view.call("_accept",acknowledged)
    _check(model.state.spatial_mode=="FREE","free geometry mode active")
    var before_revision := int(model.state.revision)
    var before_hand: Array = model.state.get_actor(0).hand.duplicate()
    view.call("_refresh")
    await process_frame
    var rendered := _rendered_cards(view)
    _check(rendered.size() == drawn.size(),
        "every drawn UID is shown, including cards without legal targets")
    for uid in drawn:
        _check(rendered.has(uid), "hidden drawn hand UID: " + str(uid))
    var approachable := 0
    for uid in attack_uids:
        if not rendered.has(uid):
            continue
        var visible: Array = rendered[uid]
        for button in visible:
            if not button.disabled:
                var usage_id: String = str(button.get_meta("usage_id", ""))
                _check(bool(view.call("_can_approach_card", str(uid), usage_id)),
                    "out-of-range selectable attacks must be eligible for auto-approach")
                approachable += 1
            else:
                _check(button.tooltip_text.contains("靠近敌人"),
                    "unavailable attack cards must explain their limits")
    _check(approachable > 0,
        "two-cell opening gap must show at least one selectable auto-approach attack")
    _check(model.state.get_actor(0).cell.distance_squared_to(model.state.get_actor(1).cell) == 4,
        "regression is built on the real two-cell opening gap")
    # Simulate a legal adjacency without submitting an action; move only the
    # enemy fixture from (8,4) to the free bridge cell (7,4).
    model.state.get_actor(1).cell = Vector2i(7, 4)
    model.state.get_actor(1).position=model.state.spatial.bake.cell_center(Vector2i(7,4))
    view.call("_refresh")
    await process_frame
    rendered = _rendered_cards(view)
    var enabled_attack := false
    for uid in attack_uids:
        for node in rendered.get(uid, []):
            if not node.disabled:
                enabled_attack = true
    _check(enabled_attack, "approaching enemy enables an existing attack card")
    _check(int(model.state.revision) == before_revision
        and model.state.get_actor(0).hand == before_hand,
        "HUD rebuild must not draw, discard or change authoritative revision")
    # During animation/AI response, keep the observer's hand present but lock
    # interactions: no accidental temporary zero-card display.
    model.state.animation_pending = true
    view.call("_refresh")
    await process_frame
    rendered = _rendered_cards(view)
    _check(rendered.size() == drawn.size(), "pending animation retains visual hand")
    var all_disabled := true
    for buttons in rendered.values():
        for button in buttons:
            if not button.disabled:
                all_disabled = false
    _check(all_disabled, "pending animation cannot submit a stale card")
    print("HAND_VISIBILITY_PASS checks=%d failures=%d" % [checks, failures])
    view.queue_free()
    await process_frame
    quit(1 if failures > 0 else 0)
