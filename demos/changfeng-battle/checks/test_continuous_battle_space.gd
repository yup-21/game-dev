extends SceneTree
## PR #57 public geometry contract. Use explicit checks rather than assert():
## a failed assert can abort _run before quit() and hang headless Godot CI.
const Spatial = preload("res://scripts/battle_spatial_service.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("PR57_SPACE: " + label)

func _run() -> void:
    var space = Spatial.new()
    _check(space.bake.error.is_empty(), "baked map loads")
    if not space.bake.error.is_empty():
        print("PR57_SPACE_FAIL: " + space.bake.error)
        quit(1)
        return
    var start: Vector2 = space.bake.cell_center(Vector2i(3, 4))
    var near: Vector2 = start + Vector2(12.5, 7.25)
    _check(space.valid_position(start), "starting world point walkable")
    _check(space.valid_position(near), "fractional landing world point walkable")
    var direct: PackedVector2Array = space.shortest_path(start, near)
    _check(direct.size() == 2, "PR57 shortest_path returns direct arbitrary endpoints")
    if direct.size() == 2:
        _check(absf(space.path_length(direct) - start.distance_to(near)) < 0.01,
            "shortest path length matches Euclidean distance")
        var partial: Vector2 = space.within_budget(direct, 5.0)
        _check(absf(partial.distance_to(start) - 5.0) < 0.01,
            "within_budget can interpolate partial path")
    var water: Vector2 = space.bake.cell_center(Vector2i(7, 2))
    _check(not space.valid_position(water), "river rejects landing")
    _check(space.shortest_path(start, water).is_empty(), "no path ends in water")
    var occupied := [{"id": 8, "position": near, "radius": 10.0, "alive": true}]
    _check(not space.valid_position(near, occupied), "occupied feet rejected")
    _check(space.valid_position(near, occupied, 8), "self excluded from occupancy")
    var attack: Dictionary = space.attack_position(start, near, 12.0, 80.0, 300.0)
    _check(not attack.is_empty(), "find reachable attack position")
    if not attack.is_empty():
        _check(float(attack.cost) <= 300.0, "attack position fits movement budget")
        var separation: float = Vector2(attack.position).distance_to(near)
        _check(separation >= 12.0 - 0.01, "minimum attack distance")
        _check(separation <= 80.0 + 0.01, "maximum attack distance")
    print("PR57_CONTINUOUS_SPACE_%s checks=%d failures=%d" % [
        "PASS" if failures == 0 else "FAIL", checks, failures])
    quit(1 if failures else 0)
