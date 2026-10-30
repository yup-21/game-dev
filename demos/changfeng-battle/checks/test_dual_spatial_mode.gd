extends SceneTree
## Dual-geometry authority: default GRID remains stable, FREE is opt-in and
## can be toggled during ACTION without resetting the CTB/cardeck.
const Model=preload("res://scripts/battle_model.gd")
const MapBake=preload("res://scripts/map_bake.gd")
var checks:=0
var failures:=0

func _initialize() -> void:
    call_deferred("_run")

func _check(valid: bool, text: String) -> void:
    checks+=1
    if not valid:
        failures+=1
        push_error("DUAL_MODE: "+text)

func _request(model,kind: String,params: Dictionary={}) -> Dictionary:
    return model.request(kind,int(model.state.active_id),params)

func _ack(model,result: Dictionary) -> void:
    if bool(result.get("success",false)) and model.state.animation_pending:
        model.acknowledge_animation(int(result.ticket))

func _run() -> void:
    var model=Model.new()
    model.reset(2026,-1,"tingfeng",{"map_definition_path":MapBake.DEFAULT_PATH})
    _check(model.state.outcome=="playing" and model.state.spatial_mode=="GRID",
        "painted map defaults to unchanged grid-based combat")
    _check(str(model.snapshot(0).get("spatial_mode",""))=="GRID",
        "authoritative mode is exposed to presentation and AI")
    var owner=model.state.get_actor(model.state.active_id)
    var initial_position: Vector2=owner.position
    var initial_qi: int=owner.qi_u
    var initial_action: int=model.state.action_no
    var denied_free: Dictionary=model.submit(_request(model,"MOVE_FREE",
        {"target_position":owner.position+Vector2(16.25,0)}))
    _check(str(denied_free.get("error_code",""))=="WRONG_SPATIAL_MODE",
        "free movement is forbidden in grid combat")
    var denied_auto: Dictionary=model.submit(_request(model,"MOVE_AND_ATTACK",
        {"attack_kind":"BASIC_ATTACK","target_id":1}))
    _check(str(denied_auto.get("error_code",""))=="WRONG_SPATIAL_MODE",
        "automatic approach cannot bypass grid-mode tactical rules")
    _check(not model.legal_actions(owner.id).filter(
        func(o): return str(o.get("kind",""))=="MOVE").is_empty(),
        "legacy grid MOVE actions are still available")

    var switch: Dictionary=model.submit(_request(model,"SET_SPATIAL_MODE",{"spatial_mode":"FREE"}))
    _check(bool(switch.get("success",false)) and model.state.spatial_mode=="FREE",
        "entering FREE is a committed revisioned combat command")
    _check(owner.position==initial_position and owner.qi_u==initial_qi
        and model.state.action_no==initial_action and owner.normal_moves_used==0,
        "switching modes preserves CTB, positions, cards and resources")
    var blocked: Dictionary=model.submit(_request(model,"SET_SPATIAL_MODE",{"spatial_mode":"GRID"}))
    _check(str(blocked.get("error_code",""))=="PRESENTATION_PENDING",
        "mode switch is blocked during pending animation")
    _ack(model,switch)
    _check(model.legal_actions(owner.id).filter(
        func(o): return str(o.get("kind",""))=="MOVE").is_empty(),
        "free mode does not enumerate discrete grid walks")
    var free_position: Vector2=initial_position+Vector2(16.25,0)
    var moved: Dictionary=model.submit(_request(model,"MOVE_FREE",{"target_position":free_position}))
    _check(bool(moved.get("success",false)) and owner.position==free_position,
        "free combat commits a genuinely non-grid endpoint")
    _ack(model,moved)
    var back: Dictionary=model.submit(_request(model,"SET_SPATIAL_MODE",{"spatial_mode":"GRID"}))
    _check(bool(back.get("success",false)) and model.state.spatial_mode=="GRID",
        "switching back to grid does not reset the battle")
    _check(owner.position==model.state.spatial.bake.cell_center(owner.cell)
        and model.state.action_no==initial_action and owner.normal_moves_used==1,
        "return to grid reanchors feet while keeping already spent movement")
    _ack(model,back)
    _check(not model.legal_actions(owner.id).filter(
        func(o): return str(o.get("kind",""))=="MOVE").is_empty(),
        "legacy grid tactical commands are restored")

    var duplicate=Model.new()
    duplicate.reset(2026,-1,"tingfeng",
        {"map_definition_path":MapBake.DEFAULT_PATH,"spatial_mode":"FREE"})
    _check(duplicate.state.spatial_mode=="FREE","encounters may explicitly start FREE")
    var hero=duplicate.state.get_actor(0)
    var enemy=duplicate.state.get_actor(1)
    var stable_revision: int=duplicate.state.revision
    var stable_qi: int=hero.qi_u
    hero.position=enemy.position+Vector2(-30,0)
    hero.cell=enemy.cell
    var denied_grid: Dictionary=duplicate.submit(duplicate.request("SET_SPATIAL_MODE",
        duplicate.state.active_id,{"spatial_mode":"GRID"}))
    _check(str(denied_grid.get("error_code",""))=="GRID_REANCHOR_BLOCKED",
        "grid mode refuses overlapping compatibility cells instead of teleporting")
    _check(duplicate.state.spatial_mode=="FREE" and duplicate.state.revision==stable_revision
        and hero.qi_u==stable_qi and hero.position.distance_to(enemy.position)==30.0,
        "rejected mode change is completely non-mutating")
    var malformed: Dictionary=duplicate.submit(duplicate.request("SET_SPATIAL_MODE",
        duplicate.state.active_id,{"spatial_mode":"hex"}))
    _check(str(malformed.get("error_code",""))=="MALFORMED_REQUEST",
        "unknown mode string cannot be accepted")

    var old=Model.new()
    var unavailable: Dictionary=old.submit(old.request("SET_SPATIAL_MODE",old.state.active_id,
        {"spatial_mode":"FREE"}))
    _check(str(unavailable.get("error_code",""))=="SPATIAL_UNAVAILABLE",
        "pure legacy unmapped encounters remain grid-only")
    print("DUAL_MODE_PASS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
