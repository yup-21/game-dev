extends SceneTree
## Regression for continuous feet coordinates and attack approach, independent
## of the legacy grid-based BattleModel.
const Spatial = preload("res://scripts/battle_spatial_service.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    if not condition:
        failures += 1
        push_error("CONTINUOUS_SPACE: " + label)

func _run() -> void:
    var space = Spatial.new()
    _check(space.bake.error.is_empty(), "map loads")
    if not space.bake.error.is_empty():
        quit(1)
        return
    var a: Vector2 = space.bake.cell_center(Vector2i(4, 4)) + Vector2(9, 6)
    var b: Vector2 = a + Vector2(25, 0)
    _check(space.is_valid_position(a, 5.0), "fractional position is legal")
    var straight: PackedVector2Array = space.find_path(a, b, 5.0)
    _check(straight.size() == 2, "unobstructed route has arbitrary endpoints")
    _check(absf(space.path_length(straight) - 25.0) < 0.01, "continuous path cost")
    var trimmed: PackedVector2Array = space.trim_path(straight, 10.0)
    _check(trimmed.size() == 2 and trimmed[-1].distance_to(a + Vector2(10, 0)) < 0.01,
        "movement budget clips at arbitrary point")
    _check(space.attack_in_range(a, b, 10.0, 20.0, 3.0, 3.0),
        "edge-to-edge weapon range")
    _check(not space.attack_in_range(a, b, 0.0, 10.0, 3.0, 3.0),
        "out of range attack rejected")
    var approach: Dictionary = space.find_attack_approach(a, b, 0.0, 20.0, 30.0, 3.0, 3.0)
    _check(not approach.is_empty() and float(approach.get("cost", 999.0)) <= 30.0,
        "automatic attack approach fits movement budget")
    var impossible: Dictionary = space.find_attack_approach(a, b, 0.0, 10.0, 1.0, 3.0, 3.0)
    _check(impossible.is_empty(), "unreachable approach does not spend resources")
    space.set_actors({42: {"position": b, "radius": 8.0, "alive": true}})
    _check(not space.is_valid_position(b + Vector2(5, 0), 4.0),
        "actor collision rejects overlapping feet")
    _check(space.is_valid_position(b, 4.0, 42), "self excluded from collision")
    print("CONTINUOUS_SPACE_PASS failures=%d" % failures)
    quit(1 if failures else 0)
