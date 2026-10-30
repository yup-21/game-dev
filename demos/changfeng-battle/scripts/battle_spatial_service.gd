extends RefCounted
## Continuous battle-space queries. No battle state is mutated here.
## Version 1 uses the authored MapBake mask as an obstacle source; actors
## have continuous feet positions, while detours use baked-cell waypoints.
const MapBake = preload("res://scripts/map_bake.gd")
const EPSILON := 0.001
var bake
var actor_positions: Dictionary = {}

func _init(map_path: String = MapBake.DEFAULT_PATH) -> void:
    bake = MapBake.new(map_path)

func set_actors(positions: Dictionary) -> void:
    actor_positions = positions.duplicate()

func is_valid_position(point: Vector2, radius: float = 0.0, ignore_id: int = -1) -> bool:
    if not is_finite(point.x) or not is_finite(point.y) or radius < 0.0:
        return false
    if bake.error != "" or bake.cell_at_screen(point, true) == Vector2i(-1, -1):
        return false
    # Check the entire footprint against authored blocked cells, not just its centre.
    for cell in bake.tiles:
        if bool(bake.tiles[cell].walkable):
            continue
        var rect: Rect2 = bake.cell_rect(cell)
        var nearest := Vector2(clampf(point.x, rect.position.x, rect.end.x),
            clampf(point.y, rect.position.y, rect.end.y))
        if point.distance_to(nearest) < radius + EPSILON:
            return false
    for id in actor_positions:
        if int(id) == ignore_id:
            continue
        var actor: Dictionary = actor_positions[id]
        if not bool(actor.get("alive", true)):
            continue
        var other: Vector2 = actor.get("position", Vector2.ZERO)
        var other_radius: float = float(actor.get("radius", 0.0))
        if point.distance_to(other) < radius + other_radius - EPSILON:
            return false
    return true

func clear_segment(start: Vector2, finish: Vector2, radius: float = 0.0, ignore_id: int = -1) -> bool:
    var length := start.distance_to(finish)
    var stride: float = maxf(2.0, minf(bake.step.x, bake.step.y) * 0.15)
    var count := maxi(1, ceili(length / stride))
    for index in range(count + 1):
        if not is_valid_position(start.lerp(finish, float(index) / float(count)), radius, ignore_id):
            return false
    return true

func find_path(start: Vector2, finish: Vector2, radius: float = 0.0, ignore_id: int = -1) -> PackedVector2Array:
    if not is_valid_position(start, radius, ignore_id) or not is_valid_position(finish, radius, ignore_id):
        return PackedVector2Array()
    if clear_segment(start, finish, radius, ignore_id):
        return PackedVector2Array([start, finish])
    var grid := AStarGrid2D.new()
    grid.region = Rect2i(0, 0, bake.width, bake.height)
    grid.cell_size = bake.step
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    grid.update()
    for cell in bake.tiles:
        if not is_valid_position(bake.cell_center(cell), radius, ignore_id):
            grid.set_point_solid(cell)
    var from_cell: Vector2i = bake.cell_at_screen(start)
    var to_cell: Vector2i = bake.cell_at_screen(finish)
    if grid.is_point_solid(from_cell) or grid.is_point_solid(to_cell):
        return PackedVector2Array()
    var cells: Array[Vector2i] = grid.get_id_path(from_cell, to_cell)
    if cells.is_empty():
        return PackedVector2Array()
    var raw := PackedVector2Array([start])
    for cell in cells:
        raw.append(bake.cell_center(cell))
    raw.append(finish)
    # Greedy visibility smoothing allows genuinely arbitrary endpoints.
    var result := PackedVector2Array([start])
    var index := 0
    while index < raw.size() - 1:
        var next := raw.size() - 1
        while next > index + 1 and not clear_segment(raw[index], raw[next], radius, ignore_id):
            next -= 1
        if not clear_segment(raw[index], raw[next], radius, ignore_id):
            return PackedVector2Array()
        result.append(raw[next])
        index = next
    return result

func path_length(path: PackedVector2Array) -> float:
    var total := 0.0
    for index in range(1, path.size()):
        total += path[index - 1].distance_to(path[index])
    return total

func trim_path(path: PackedVector2Array, budget: float) -> PackedVector2Array:
    if path.is_empty() or budget < 0.0:
        return PackedVector2Array()
    var result := PackedVector2Array([path[0]])
    var left := budget
    for index in range(1, path.size()):
        var distance := path[index - 1].distance_to(path[index])
        if distance > left:
            if distance > EPSILON:
                result.append(path[index - 1].lerp(path[index], left / distance))
            return result
        result.append(path[index])
        left -= distance
    return result

func attack_in_range(source: Vector2, target: Vector2, min_range: float, max_range: float,
        source_radius: float = 0.0, target_radius: float = 0.0) -> bool:
    if min_range < 0.0 or max_range < min_range:
        return false
    var gap := maxf(0.0, source.distance_to(target) - source_radius - target_radius)
    return gap + EPSILON >= min_range and gap <= max_range + EPSILON

func find_attack_approach(source: Vector2, target: Vector2, min_range: float,
        max_range: float, move_budget: float, radius: float = 0.0,
        target_radius: float = 0.0, ignore_id: int = -1) -> Dictionary:
    if move_budget < 0.0 or min_range < 0.0 or max_range < min_range:
        return {}
    if attack_in_range(source, target, min_range, max_range, radius, target_radius):
        return {"position": source, "path": PackedVector2Array([source]), "cost": 0.0}
    var best: Dictionary = {}
    # Sample the legal attack annulus deterministically. A future navigation
    # mesh can replace this candidate generator without changing the API.
    for ring in range(3):
        var edge_distance := max_range - (max_range - min_range) * float(ring) / 2.0
        var center_distance := edge_distance + radius + target_radius
        for sector in range(48):
            var angle := TAU * float(sector) / 48.0
            var point := target + Vector2(cos(angle), sin(angle)) * center_distance
            if not is_valid_position(point, radius, ignore_id):
                continue
            if not attack_in_range(point, target, min_range, max_range, radius, target_radius):
                continue
            var path := find_path(source, point, radius, ignore_id)
            if path.is_empty():
                continue
            var cost := path_length(path)
            if cost > move_budget + EPSILON:
                continue
            if best.is_empty() or cost < float(best.cost) - EPSILON:
                best = {"position": point, "path": path, "cost": cost}
    return best
