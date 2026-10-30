extends SceneTree
## Gameplay-level check that UI controls issue real authority commands instead
## of only drawing the route overlay. Requires imported artwork and Godot scene.
const BattleScene = preload("res://battle_hd2d.tscn")
var checks := 0
var failures := 0

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("APPROACH_UI: " + message)

func _initialize() -> void:
    call_deferred("_run")

func _create_battle() -> Node:
    var battle: Node=BattleScene.instantiate()
    root.add_child(battle)
    return battle

func _run() -> void:
    var view: Node=_create_battle()
    await process_frame
    var model=view.get("model")
    var actor=model.state.get_actor(model.state.active_id)
    var target=model.state.get_actor(1 if actor.id==0 else 0)
    var positions: Dictionary=view.get("actor_nodes")
    _check(positions.has(actor.id) and positions[actor.id] is Node2D,
        "painted battle has an actual Node2D player")
    var from: Vector2=actor.position
    view.call("_submit","MOVE_AND_ATTACK",{"attack_kind":"BASIC_ATTACK","target_id":target.id})
    _check(actor.position != from and model.state.mode=="CLASH",
        "battle UI dispatches authoritative move-plus-attack")
    var routed: Dictionary=view.get("continuous_paths")
    _check(routed.has(actor.id) and not routed[actor.id].is_empty(),
        "Sprite2D presentation receives the committed movement waypoints")
    _check(int(view.get("animation_ticket"))>=0,
        "composite attack holds the presentation ticket")
    for _step in range(4):
        view.call("_process",0.20)
    _check(positions[actor.id].position.distance_to(actor.position)<=1.5,
        "displayed player traverses the actual route to world-space destination")
    view.queue_free()
    await process_frame

    var free_view: Node=_create_battle()
    await process_frame
    var free_model=free_view.get("model")
    var free_actor=free_model.state.get_actor(free_model.state.active_id)
    var origin: Vector2=free_actor.position
    var point: Vector2=origin+Vector2(16.25,0)
    free_view.call("_submit","MOVE_FREE",{"target_position":point})
    _check(free_actor.position==point,
        "free-movement UI submits non-enumerable MOVE_FREE to authority")
    free_view.queue_free()
    await process_frame

    var card_view: Node=_create_battle()
    await process_frame
    var card_model=card_view.get("model")
    var caster=card_model.state.get_actor(card_model.state.active_id)
    var victim=card_model.state.get_actor(1 if caster.id==0 else 0)
    caster.qi_u=60000
    var selected_uid: String=""
    var selected_usage: String=""
    for uid in caster.hand+caster.draw_pile:
        for usage in card_model.cards.canonical_definition(str(uid)).get("usages",[]):
            if str(usage.get("timing",""))!="ACTION" or str(usage.get("target",{}).get("kind",""))!="enemy_actor":
                continue
            var damage := false
            for effect in usage.get("effects",[]):
                if str(effect.get("type",""))=="deal_damage":
                    damage=true
            if not damage:
                continue
            var request: Dictionary=card_model.request("MOVE_AND_ATTACK",caster.id,{
                "attack_kind":"PLAY_CARD","card_uid":str(uid),"usage_id":str(usage.id),"target_id":victim.id})
            if not caster.hand.has(uid):
                caster.draw_pile.erase(uid)
                caster.hand.append(uid)
            if bool(card_model.validate(request).get("success",false)):
                selected_uid=str(uid)
                selected_usage=str(usage.id)
                break
        if not selected_uid.is_empty():
            break
    _check(not selected_uid.is_empty(),"prepared a selectable martial attack for UI")
    if not selected_uid.is_empty():
        card_view.call("_refresh")
        card_view.call("_select_card",selected_uid,selected_usage)
        _check(str(card_view.get("selected_kind"))=="PLAY_CARD",
            "out-of-range attack can remain selected for approach")
        card_view.call("_submit_selected_approach",victim.id)
        _check(card_model.state.mode=="CLASH" and not caster.hand.has(selected_uid),
            "clicking an enemy with a selected card performs one committed attack")
    card_view.queue_free()
    await process_frame
    print("APPROACH_UI_PASS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures>0 else 0)
