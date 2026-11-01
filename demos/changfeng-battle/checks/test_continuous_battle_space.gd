extends SceneTree
## R40 replacement for historical PR57 API checks: single pathfinder.
const Spatial = preload("res://scripts/battle_spatial_service.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, description: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("R40_CONTINUOUS: " + description)

func _run() -> void:
    var space = Spatial.new()
    check(space.bake.error.is_empty(), "native map registered")
    if not space.bake.error.is_empty():
        quit(1)
        return
    var start: Vector2 = space.bake.cell_center(Vector2i(3,4))
    var near: Vector2 = start + Vector2(12.5,7.25)
    check(space.is_valid_position(start,8.0)
        and space.is_valid_position(near,8.0),
        "world-space endpoints are not restricted to grid centres")
    var path: PackedVector2Array = space.find_path(start,near,8.0)
    check(path.size()==2,"unobstructed path is direct")
    if path.size()==2:
        check(absf(space.path_length(path)-start.distance_to(near))<0.01,
            "authoritative route cost")
        var clipped: PackedVector2Array=space.trim_path(path,5.0)
        check(clipped.size()==2 and absf(clipped[-1].distance_to(start)-5.0)<0.01,
            "fractional move budget")
    var water: Vector2 = space.bake.cell_center(Vector2i(7,2))
    check(not space.is_valid_position(water,8.0)
        and space.find_path(start,water,8.0).is_empty(),
        "painted river rejects both landing and path")
    space.set_actors({8:{"position":near,"radius":10.0,"alive":true}})
    check(not space.is_valid_position(near,8.0)
        and space.is_valid_position(near,8.0,8),
        "collisions use dynamic occupancy and actor exclusion")
    space.set_actors({})
    var approach: Dictionary=space.find_attack_approach(start,near,12.0,80.0,300.0)
    check(not approach.is_empty() and float(approach.cost)<=300.0,
        "single continuous approach algorithm")
    print("R40_CONTINUOUS_PASS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
