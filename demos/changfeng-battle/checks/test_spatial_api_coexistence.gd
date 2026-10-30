extends SceneTree
## Integration regression: restored PR #62 and merged PR #57 must expose
## both public spatial APIs on the same authority object.
const Spatial = preload("res://scripts/battle_spatial_service.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, description: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("SPATIAL_API_COEXIST: " + description)

func _run() -> void:
    var space = Spatial.new()
    _check(space.bake.error.is_empty(), "authoritative map loads")
    if not space.bake.error.is_empty():
        quit(1)
        return
    var start: Vector2 = space.bake.cell_center(Vector2i(3, 4))
    var end: Vector2 = start + Vector2(12.5, 7.25)
    _check(space.valid_position(start) and space.is_valid_position(start, 8.0),
        "both PR57 and PR62 clearance entrypoints are valid")
    _check(space.clear_segment(start, end, []) and space.clear_segment(start, end, 8.0),
        "clear_segment accepts PR57 occupied Array or PR62 radius Float")
    var old_path: PackedVector2Array = space.shortest_path(start, end)
    var free_path: PackedVector2Array = space.find_path(start, end, 8.0)
    _check(old_path.size() == 2 and free_path.size() == 2,
        "PR57 visibility graph and PR62 combat path both retain arbitrary endpoints")
    _check(absf(space.path_length(old_path) - start.distance_to(end)) < 0.01,
        "legacy path length remains continuous")
    _check(absf(space.within_budget(old_path, 5.0).distance_to(start) - 5.0) < 0.01,
        "PR57 within_budget still clips arbitrary paths")
    _check(space.trim_path(free_path, 5.0)[-1].distance_to(start) <= 5.01,
        "PR62 trim_path retains its distance budget")
    var blockers := [{"id": 8, "position": end, "radius": 10.0, "alive": true}]
    _check(not space.valid_position(end, blockers) and space.valid_position(end, blockers, 8),
        "PR57 actor occupancy and ignore_id remain functional")
    space.set_actors({8: {"position": end, "radius": 10.0, "alive": true}})
    _check(not space.is_valid_position(end, 10.0) and space.is_valid_position(end, 10.0, 8),
        "PR62 actor occupancy and ignore_id remain functional")
    var water: Vector2 = space.bake.cell_center(Vector2i(7, 2))
    _check(not space.valid_position(water) and not space.is_valid_position(water, 8.0),
        "authored obstacles block movement in both APIs")
    var old_attack: Dictionary = space.attack_position(start, end, 12.0, 80.0, 300.0)
    _check(not old_attack.is_empty() and float(old_attack.get("cost", INF)) <= 300.0,
        "PR57 attack-position search is preserved")
    _check(space.attack_in_range(start, end, 0.0, 80.0, 0.0, 0.0),
        "PR62 attack distance remains usable")
    var adjustable = Spatial.new("res://data/maps/rainy_bridge.json", 12.0)
    _check(absf(float(adjustable.waypoint_compat.clearance) - 12.0) < 0.01,
        "PR57 configurable actor clearance survives API integration")
    print("SPATIAL_API_COEXIST_PASS checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)
