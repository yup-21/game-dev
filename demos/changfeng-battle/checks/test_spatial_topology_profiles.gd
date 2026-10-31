extends SceneTree
## P0 topology regression: exact route geometry plus informational timings.
## Fixture maps reuse test artwork; they are not player-facing scenic maps.
const Space = preload("res://scripts/battle_spatial_service.gd")

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("SPATIAL_TOPOLOGY: " + label)

func _profile(name: String, map_path: String, start_cell: Vector2i,
        goal_cell: Vector2i, occupied_cells: Array,
        expect_detour: bool) -> void:
    var space = Space.new(map_path)
    _check(space.bake.error.is_empty(), name + ": map loads: " + space.bake.error)
    if not space.bake.error.is_empty():
        return
    var occupied: Dictionary = {}
    for index in range(occupied_cells.size()):
        occupied[100 + index] = {
            "position": space.bake.cell_center(occupied_cells[index]),
            "radius": 8.0, "alive": true
        }
    space.set_actors(occupied)
    var start: Vector2 = space.bake.cell_center(start_cell)
    var goal: Vector2 = space.bake.cell_center(goal_cell)
    _check(space.is_valid_position(start, 8.0)
        and space.is_valid_position(goal, 8.0), name + ": legal endpoints")
    var expected: PackedVector2Array = space.find_path(start, goal, 8.0)
    _check(expected.size() >= 2, name + ": path exists")
    if expected.size() < 2:
        return
    _check(expected[0] == start and expected[-1] == goal,
        name + ": exact start and goal")
    for i in range(1, expected.size()):
        _check(space.clear_segment(expected[i - 1], expected[i], 8.0),
            name + ": route segment " + str(i) + " respects collision")
    var direct: float = start.distance_to(goal)
    var cost: float = space.path_length(expected)
    _check(cost >= direct - 0.001, name + ": cost is not shorter than chord")
    if expect_detour:
        _check(cost > direct + 1.0 and expected.size() >= 3,
            name + ": real collision detour")
    else:
        _check(expected.size() == 2, name + ": open arena is direct")

    # Warm cache first; test determinism independently of benchmark timings.
    for _warm in range(3):
        _check(space.find_path(start, goal, 8.0) == expected,
            name + ": cache preserves the route")
    var samples: Array[int] = []
    for _sample in range(16):
        var started_us: int = Time.get_ticks_usec()
        var route: PackedVector2Array = space.find_path(start, goal, 8.0)
        samples.append(Time.get_ticks_usec() - started_us)
        _check(route == expected, name + ": repeated query is deterministic")
    samples.sort()
    var p95: int = samples[ceili(float(samples.size()) * 0.95) - 1]
    print("SPATIAL_TOPOLOGY name=%s path_points=%d distance=%.2f p50_us=%d p95_us=%d max_us=%d" %
        [name, expected.size(), cost, samples[int(samples.size() / 2)], p95, samples[-1]])

func _run() -> void:
    var open: String = "res://checks/fixtures/maps/qa_open_arena.json"
    var obstacles: String = "res://checks/fixtures/maps/qa_obstacle_court.json"
    _profile("open", open, Vector2i(2, 4), Vector2i(12, 4), [], false)
    _profile("obstacles", obstacles, Vector2i(3, 3), Vector2i(11, 3), [], true)
    var crowd: Array[Vector2i] = [
        Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4),
        Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5)
    ]
    _profile("six_actors", open, Vector2i(2, 4), Vector2i(12, 4),
        crowd, true)
    print("SPATIAL_TOPOLOGY_PASS checks=%d failures=%d" % [checks, failures])
    quit(1 if failures > 0 else 0)
