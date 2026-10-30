extends SceneTree
## Regression for the "two fighters in one old tile freeze movement" bug.
const Space = preload("res://scripts/battle_spatial_service.gd")
const Model = preload("res://scripts/battle_model.gd")
const MapBake = preload("res://scripts/map_bake.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("FREE_CROWD: " + description)

func _run() -> void:
    var spatial = Space.new()
    _check(spatial.bake.error.is_empty(), "baked terrain loaded")
    if not spatial.bake.error.is_empty():
        quit(1)
        return
    var middle: Vector2 = spatial.bake.cell_center(Vector2i(5,4))
    var start: Vector2 = middle + Vector2(-25.0, 0.0)
    var finish: Vector2 = middle + Vector2(25.0, 0.0)
    spatial.set_actors({42: {"position": middle, "radius": 8.0, "alive": true}})
    _check(spatial.bake.cell_at_screen(start)==spatial.bake.cell_at_screen(finish),
        "both legal feet reside within one authored legacy tile")
    _check(spatial.is_valid_position(start,8.0) and spatial.is_valid_position(finish,8.0),
        "arbitrary endpoints on either side of an actor are valid")
    _check(not spatial.clear_segment(start,finish,8.0),
        "straight movement must not tunnel through an occupied circle")
    var path: PackedVector2Array=spatial.find_path(start,finish,8.0)
    _check(path.size()>=3,"pathfinder avoids actor without declaring entire tile solid")
    if path.size()>=3:
        _check(path[0]==start and path[-1]==finish,
            "detour preserves precise arbitrary landing")
        for index in range(1,path.size()):
            _check(spatial.clear_segment(path[index-1],path[index],8.0),
                "every waypoint edge respects actor collision and terrain")
        _check(spatial.path_length(path)>start.distance_to(finish),
            "detour uses real path length rather than line-of-sight chord")
    var chosen: Vector2=spatial.safe_landing(start,middle,8.0)
    _check(chosen!=middle and spatial.is_valid_position(chosen,8.0),
        "clicking an enemy selects reachable near-side collision-free feet")
    _check(not spatial.find_path(start,chosen,8.0).is_empty(),
        "snapped landing has a real safe path")
    var water: Vector2=spatial.bake.cell_center(Vector2i(7,2))
    _check(spatial.safe_landing(start,water,8.0)==water,
        "terrain water click never silently snaps onto nearby playable land")
    # Two adjacent blockers in a bridge lane must not turn a reachable
    # click on an actor into an unreachable landing preference.
    var crowded_start: Vector2 = middle + Vector2(-65.0, 0.0)
    spatial.set_actors({
        42: {"position":middle,"radius":8.0,"alive":true},
        43: {"position":middle + Vector2(-30.0, 0.0),"radius":8.0,"alive":true}})
    _check(spatial.is_valid_position(crowded_start, 8.0),
        "crowded fixture starts on legal feet")
    var crowded_landing: Vector2 = spatial.safe_landing(crowded_start, middle, 8.0)
    var crowded_route: PackedVector2Array = spatial.find_path(crowded_start, crowded_landing, 8.0)
    _check(crowded_landing != middle and crowded_route.size() >= 2,
        "multiple body circles still offer a reachable landing")
    if crowded_route.size() >= 2:
        for index in range(1, crowded_route.size()):
            _check(spatial.clear_segment(crowded_route[index - 1], crowded_route[index], 8.0),
                "each crowded path segment remains collision-free")
    spatial.set_actors({42: {"position":middle,"radius":8.0,"alive":false}})
    _check(spatial.find_path(start,finish,8.0).size()==2,
        "dead units are no longer movement obstacles")

    var m=Model.new()
    m.reset(2026,-1,"tingfeng",{"map_definition_path":MapBake.DEFAULT_PATH,"spatial_mode":"FREE"})
    _check(m.state.spatial_mode=="FREE","test uses authoritative free movement")
    var owner=m.state.get_actor(m.state.active_id)
    var opponent=m.state.get_actor(1 if owner.id==0 else 0)
    owner.qi_u=60000
    var old_position: Vector2=owner.position
    var old_qi: int=owner.qi_u
    var result: Dictionary=m.submit(m.request("MOVE_FREE",owner.id,
        {"target_position":opponent.position}))
    _check(bool(result.get("success",false)),
        "authority resolves an accidental click directly on opponent's feet")
    if bool(result.get("success",false)):
        _check(owner.position != opponent.position and owner.position.distance_to(opponent.position)>=16.0,
            "committed landing does not overlap opponent")
        _check(owner.position!=old_position and owner.qi_u<old_qi,
            "safe move commits and charges distance exactly once")
        _check(m.state.spatial.bake.cell_at_screen(owner.position,true)!=Vector2i(-1,-1),
            "resolved feet remain inside the calibrated traversable scene")
    print("FREE_CROWD_PASS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
