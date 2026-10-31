extends SceneTree
## R40: one continuous navigation implementation, with no PR57 side engine.
const Spatial = preload("res://scripts/battle_spatial_service.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("R40_SPATIAL: " + label)

func _run() -> void:
    var space = Spatial.new()
    check(space.bake.error.is_empty(), "registered native GRID map loads")
    if not space.bake.error.is_empty():
        quit(1)
        return
    check(not FileAccess.file_exists("res://scripts/battle_spatial_waypoint.gd"),
        "obsolete visibility-graph implementation removed")
    var start: Vector2 = space.bake.cell_center(Vector2i(3, 4))
    var goal: Vector2 = start + Vector2(12.5, 7.25)
    check(space.is_valid_position(start, 8.0)
        and space.is_valid_position(goal, 8.0),
        "fractional endpoints accepted with actor clearance")
    check(space.clear_segment(start, goal, 8.0), "single native segment collision")
    var route: PackedVector2Array = space.find_path(start, goal, 8.0)
    check(route.size() == 2, "direct route keeps exact free landing")
    if route.size() == 2:
        check(absf(space.path_length(route) - start.distance_to(goal)) < 0.01,
            "route length matches Euclidean length")
        var clipped: PackedVector2Array = space.trim_path(route, 5.0)
        check(clipped.size() == 2 and
            absf(clipped[-1].distance_to(start) - 5.0) < 0.01,
            "movement budget uses same geometry")
    var river: Vector2 = space.bake.cell_center(Vector2i(7, 2))
    check(not space.is_valid_position(river, 8.0)
        and space.find_path(start, river, 8.0).is_empty(),
        "river cannot become a destination")
    space.set_actors({8:{"position":goal,"radius":10.0,"alive":true}})
    check(not space.is_valid_position(goal, 8.0)
        and space.is_valid_position(goal, 8.0, 8),
        "occupancy collision and ignored self share one implementation")
    space.set_actors({})
    var approach: Dictionary = space.find_attack_approach(
        start, goal, 12.0, 80.0, 300.0)
    check(not approach.is_empty() and float(approach.get("cost", INF)) <= 300.0,
        "native approach result obeys movement budget")
    check(space.attack_in_range(start, goal, 0.0, 80.0),
        "weapon range is a continuous geometry query")
    print("R40_SPATIAL_PASS checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)
