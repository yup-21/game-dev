extends SceneTree
## Focused continuous movement regression, independent of CTB and UI.
const Spatial = preload("res://scripts/battle_spatial_service.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var space = Spatial.new()
    if not space.bake.error.is_empty():
        push_error(space.bake.error)
        quit(1)
        return
    print("SPATIAL57_STAGE: map loaded")
    var start: Vector2 = space.bake.cell_center(Vector2i(3, 4))
    var near: Vector2 = start + Vector2(12.5, 7.25)
    assert(space.valid_position(start))
    assert(space.valid_position(near))
    print("SPATIAL57_STAGE: before shortest_path direct")
    var direct: PackedVector2Array = space.shortest_path(start, near)
    print("SPATIAL57_STAGE: after shortest_path direct")
    assert(direct.size() == 2)
    assert(absf(space.path_length(direct) - start.distance_to(near)) < 0.01)
    var partial: Vector2 = space.within_budget(direct, 5.0)
    assert(absf(partial.distance_to(start) - 5.0) < 0.01)
    print("SPATIAL57_STAGE: before water rejection")
    var water: Vector2 = space.bake.cell_center(Vector2i(7, 2))
    assert(not space.valid_position(water))
    assert(space.shortest_path(start, water).is_empty())
    var occupied := [{"id": 8, "position": near, "radius": 10.0, "alive": true}]
    assert(not space.valid_position(near, occupied))
    assert(space.valid_position(near, occupied, 8))
    print("SPATIAL57_STAGE: before attack_position")
    var attack: Dictionary = space.attack_position(start, near, 12.0, 80.0, 300.0)
    print("SPATIAL57_STAGE: after attack_position")
    assert(not attack.is_empty())
    assert(float(attack.cost) <= 300.0)
    assert(Vector2(attack.position).distance_to(near) >= 12.0 - 0.01)
    assert(Vector2(attack.position).distance_to(near) <= 80.0 + 0.01)
    print("CONTINUOUS_SPACE_PASS free landing, blocked water, clearance, budget, attack")
    quit(0)
