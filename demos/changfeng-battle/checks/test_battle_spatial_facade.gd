extends SceneTree
const Model = preload("res://scripts/battle_model.gd")
const Geometry = preload("res://scripts/battle_spatial_facade.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("SPATIAL_FACADE: " + message)

func _run() -> void:
    var model = Model.new()
    model.reset(2026, -1, "tingfeng",
        {"map_definition_path": "res://data/maps/rainy_bridge.tres",
            "spatial_mode": "GRID"})
    var actor = model.state.get_actor(0)
    var target = model.state.get_actor(1)
    var grid = Geometry.new(model.state)
    _check(not grid.can_land(actor, target.cell),
        "GRID cannot land inside another living actor")
    _check(grid.can_attack(actor,target,0.0,1.0,true)
        == (absi(actor.cell.x-target.cell.x) + absi(actor.cell.y-target.cell.y)==1),
        "GRID basic attack preserves Manhattan adjacency")
    var path: Array = []
    for cell in model.state.reachable_paths(actor.cell,actor.id):
        path = grid.find_path(actor,cell)
        if not path.is_empty():
            break
    _check(not path.is_empty() and grid.path_cost(path)==float(path.size()),
        "GRID paths preserve old reachable-path steps")

    model.reset(2026, -1, "tingfeng",
        {"map_definition_path": "res://data/maps/rainy_bridge.tres",
            "spatial_mode": "FREE"})
    actor = model.state.get_actor(0)
    target = model.state.get_actor(1)
    var free = Geometry.new(model.state)
    var before: int = int(model.state.revision)
    _check(not free.can_land(actor,target.position),
        "FREE circular collision rejects occupied enemy center")
    var landing: Vector2 = free.safe_landing(actor,actor.position+Vector2(38,0))
    var route: PackedVector2Array = free.find_path(actor,landing)
    _check(route.size() >= 2 and free.path_cost(route) >= 0.0,
        "FREE route reuses baked-space shortest path")
    var unit: float = free.unit_distance()
    var expected: bool = (model.state.spatial.attack_in_range(
        actor.position,target.position,0.0,unit,8.0,8.0)
        and model.state.spatial.attack_line_clear(
            actor.position,target.position,[actor.id,target.id]))
    _check(free.can_attack(actor,target,0.0,1.0,true)==expected,
        "FREE attack range/LOS delegates without geometric drift")
    _check(int(model.state.revision)==before,
        "facade queries cannot commit battle revisions")

    print("SPATIAL_FACADE_PASS checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)
