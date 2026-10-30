extends SceneTree
## End-to-end continuous MOVE_FREE command regression.
## Run: godot --headless --path demos/changfeng-battle --script res://checks/test_free_move_command.gd
const Model = preload("res://scripts/battle_model.gd")
const MapBake = preload("res://scripts/map_bake.gd")
var failures := 0
var checks := 0

func _check(ok: bool, detail: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("FREE_MOVE_COMMAND: " + detail)

func _initialize() -> void:
    call_deferred("_run")

func _new_model():
    var model = Model.new()
    model.reset(2026,-1,"tingfeng",{"map_definition_path":MapBake.DEFAULT_PATH,"spatial_mode":"FREE"})
    return model

func _run() -> void:
    var model = _new_model()
    _check(model.state.outcome=="playing" and model.state.spatial!=null,
        "map battle creates spatial authority")
    var id: int=model.state.active_id
    var actor=model.state.get_actor(id)
    var start: Vector2=actor.position
    _check(start==model.state.spatial.bake.cell_center(actor.cell),
        "spawn feet are continuous world coordinates")
    var destination := start + Vector2(16.25,0.0)
    var request: Dictionary=model.request("MOVE_FREE",id,{"target_position":destination})
    var verdict: Dictionary=model.validate(request)
    _check(bool(verdict.get("success",false)), "arbitrary non-grid endpoint is precommit legal")
    _check(actor.position==start and actor.normal_moves_used==0,
        "validation does not mutate the authoritative position or budget")
    var before_revision: int=model.state.revision
    var before_qi: int=actor.qi_u
    var result: Dictionary=model.submit(request)
    _check(bool(result.get("success",false)),"valid MOVE_FREE commits")
    _check(model.state.revision==before_revision+1 and actor.position==destination,
        "commit changes position and revision once")
    _check(actor.normal_moves_used==1 and actor.qi_u==before_qi-10000,
        "distance consumes one movement unit and one Qi")
    var event_found := false
    for event in result.get("events",[]):
        if str(event.get("type",""))=="MOVE_FREE":
            event_found=event.get("from_position")==start and event.get("to_position")==destination                 and event.get("path") is PackedVector2Array
    _check(event_found,"MOVE_FREE event carries reproducible world-space path")
    var pending: Dictionary=model.submit(model.request("MOVE_FREE",id,{"target_position":start+Vector2(22.0,0.0)}))
    _check(not bool(pending.get("success",false)) and str(pending.get("error_code",""))=="PRESENTATION_PENDING",
        "animation ticket serializes movement commands")
    _check(bool(model.acknowledge_animation(int(result.ticket)).get("success",false)),
        "movement animation can be acknowledged")
    var replay: Dictionary=model.submit(request)
    _check(not bool(replay.get("success",false)), "stale or replayed movement is rejected")

    # One movement unit remains; a 2-cell move must be rejected before any cost.
    var old_position: Vector2=actor.position
    var old_qi: int=actor.qi_u
    var old_revision: int=model.state.revision
    var too_far: Dictionary=model.submit(model.request("MOVE_FREE",id,
        {"target_position":start+Vector2(165,0)}))
    _check(not bool(too_far.get("success",false)) and actor.position==old_position
        and actor.qi_u==old_qi and model.state.revision==old_revision,
        "out-of-budget movement is rejected with zero state changes")

    var invalid: Dictionary=model.submit(model.request("MOVE_FREE",id,
        {"target_position":Vector2(-500,-500)}))
    _check(not bool(invalid.get("success",false)) and actor.position==old_position,
        "outside-map destination rejected")
    var enemy=model.state.get_actor(1 if id==0 else 0)
    var overlap: Dictionary=model.submit(model.request("MOVE_FREE",id,
        {"target_position":enemy.position}))
    _check(not bool(overlap.get("success",false)) and actor.position==old_position,
        "occupied destination rejected")
    var malformed: Dictionary=model.submit(model.request("MOVE_FREE",id,
        {"target_position":"not-a-Vector2"}))
    _check(str(malformed.get("error_code",""))=="MALFORMED_REQUEST",
        "invalid destination type rejected")
    var invalid_nan: Dictionary=model.submit(model.request("MOVE_FREE",id,
        {"target_position":Vector2(INF, 0)}))
    _check(str(invalid_nan.get("error_code",""))=="INVALID_POSITION",
        "nonfinite destination rejected")
    var legacy = Model.new()
    _check(legacy.state.spatial==null and legacy.state.outcome=="playing",
        "unmapped legacy battles remain grid-authoritative")
    var denied: Dictionary=legacy.submit(legacy.request("MOVE_FREE",legacy.state.active_id,
        {"target_position":Vector2(3,4)}))
    _check(str(denied.get("error_code",""))=="SPATIAL_UNAVAILABLE",
        "free movement disabled for uncalibrated legacy maps")
    print("FREE_MOVE_COMMAND_PASS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures>0 else 0)
