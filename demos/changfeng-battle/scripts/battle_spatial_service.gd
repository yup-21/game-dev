extends RefCounted
## Continuous battle-space queries. No battle state is mutated here.
## Version 1 uses the authored MapBake mask as an obstacle source; actors
## have continuous feet positions, while detours use baked-cell waypoints.
const MapBake = preload("res://scripts/map_bake.gd")
## Keep the visibility-graph API introduced by PR #57 available to callers.
const WaypointCompatibility = preload("res://scripts/battle_spatial_waypoint.gd")
const EPSILON := 0.001
var bake
var actor_positions: Dictionary = {}
var waypoint_compat
## Disabled in regular play. Enable only for headless diagnostics; counters
## themselves add overhead and must not be used for timing comparisons.
var diagnostics_enabled: bool = false
var diagnostics: Dictionary = {}

func reset_diagnostics() -> void:
    diagnostics = {"path_queries":0, "failed_paths":0, "graph_builds":0,
        "max_nodes":0, "candidate_pairs":0, "segment_queries":0,
        "total_us":0, "max_us":0}

func diagnostic_snapshot() -> Dictionary:
    return diagnostics.duplicate()

## Compatibility with the public clearance property exposed by PR #57.
var clearance: float:
    get:
        return float(waypoint_compat.clearance) if waypoint_compat != null else 10.0
    set(value):
        if waypoint_compat != null:
            waypoint_compat.clearance = maxf(0.0, value)

func _init(map_path: String = MapBake.DEFAULT_PATH, actor_clearance: float = 10.0) -> void:
    bake = MapBake.new(map_path)
    waypoint_compat = WaypointCompatibility.new(map_path, actor_clearance)
    reset_diagnostics()

func set_actors(positions: Dictionary) -> void:
    actor_positions = positions.duplicate()

func is_valid_position(point: Vector2, radius: float = 0.0, ignore_id: int = -1) -> bool:
    if not is_finite(point.x) or not is_finite(point.y) or radius < 0.0:
        return false
    if bake.error != "":
        return false
    var base: Vector2i = bake.cell_at_screen(point,true)
    if base==Vector2i(-1,-1): return false
    # The footprint must remain INSIDE the calibrated battlefield bounds.
    var bounds_min: Vector2=bake.cell_rect(Vector2i.ZERO).position
    var bounds_max: Vector2=bake.cell_rect(Vector2i(bake.width-1,bake.height-1)).end
    if point.x-radius < bounds_min.x-EPSILON or point.y-radius < bounds_min.y-EPSILON or point.x+radius > bounds_max.x+EPSILON or point.y+radius > bounds_max.y+EPSILON:
        return false
    # Only obstacles within one footprint radius can collide. Iterating all
    # 150 baked cells for every A* sample makes AI approach search O(cells).
    var nearby_x: int=maxi(1,ceili(radius/bake.step.x)+1)
    var nearby_y: int=maxi(1,ceili(radius/bake.step.y)+1)
    for y in range(base.y-nearby_y,base.y+nearby_y+1):
        for x in range(base.x-nearby_x,base.x+nearby_x+1):
            var cell:=Vector2i(x,y)
            if not bake.tiles.has(cell) or bool(bake.tiles[cell].walkable):
                continue
            var rect: Rect2=bake.cell_rect(cell)
            var nearest:=Vector2(clampf(point.x,rect.position.x,rect.end.x),
                clampf(point.y,rect.position.y,rect.end.y))
            if point.distance_to(nearest)<radius+EPSILON:
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

func clear_segment(start: Vector2, finish: Vector2, radius_or_occupied: Variant = 0.0, ignore_id: int = -1) -> bool:
    if diagnostics_enabled:
        diagnostics["segment_queries"] = int(diagnostics.segment_queries) + 1
    if radius_or_occupied is Array:
        return waypoint_compat.clear_segment(start, finish, radius_or_occupied, ignore_id)
    var radius: float = float(radius_or_occupied)
    var vector: Vector2 = finish - start
    var length: float = vector.length()
    # Sampling the ground mask cannot reliably detect a thin actor collision.
    # The exact nearest-point-to-segment check prevents tunnelling through
    # crowded characters when the move endpoint is otherwise legal.
    for id in actor_positions:
        if int(id) == ignore_id:
            continue
        var body: Dictionary = actor_positions[id]
        if not bool(body.get("alive", true)):
            continue
        var centre: Vector2 = body.get("position", Vector2.ZERO)
        var t: float = clampf((centre - start).dot(vector) / maxf(vector.length_squared(), EPSILON), 0.0, 1.0)
        var nearest: Vector2 = start + vector * t
        if nearest.distance_to(centre) < radius + float(body.get("radius", 0.0)) - EPSILON:
            return false
    var stride: float = maxf(2.0, minf(minf(bake.step.x, bake.step.y) * 0.15, maxf(2.0, radius * 0.5)))
    var count := maxi(1, ceili(length / stride))
    for index in range(count + 1):
        if not is_valid_position(start.lerp(finish, float(index) / float(count)), radius, ignore_id):
            return false
    return true

## FREE navigation uses world-space visibility edges. Baked cells describe
## *terrain*, not occupiable tactical squares. A character standing at a cell
## centre must never make that entire tile impassable to another character.
func find_path(start: Vector2, finish: Vector2, radius: float = 0.0, ignore_id: int = -1) -> PackedVector2Array:
    if not diagnostics_enabled:
        return _find_path_impl(start, finish, radius, ignore_id)
    var started_us: int = Time.get_ticks_usec()
    diagnostics["path_queries"] = int(diagnostics.path_queries) + 1
    var path: PackedVector2Array = _find_path_impl(start, finish, radius, ignore_id)
    var elapsed_us: int = Time.get_ticks_usec() - started_us
    diagnostics["total_us"] = int(diagnostics.total_us) + elapsed_us
    diagnostics["max_us"] = maxi(int(diagnostics.max_us), elapsed_us)
    if path.size() < 2:
        diagnostics["failed_paths"] = int(diagnostics.failed_paths) + 1
    return path

func _find_path_impl(start: Vector2, finish: Vector2, radius: float = 0.0, ignore_id: int = -1) -> PackedVector2Array:
    if not is_valid_position(start, radius, ignore_id) or not is_valid_position(finish, radius, ignore_id):
        return PackedVector2Array()
    if clear_segment(start, finish, radius, ignore_id):
        return PackedVector2Array([start, finish])
    var points: Array[Vector2] = [start, finish]
    # A grid is still an authored source of terrain waypoints, never a
    # collision test on *characters' cells*. Include only physically legal
    # centres so the graph does not route through an occupied foot anchor.
    for cell in bake.tiles:
        if not bool(bake.tiles[cell].walkable):
            continue
        var centre: Vector2 = bake.cell_center(cell)
        if is_valid_position(centre, radius, ignore_id):
            points.append(centre)
    # Polygonal approximation of each dynamic body's exclusion circle.
    # Outward offset protects the chords BETWEEN adjacent circle vertices.
    const SECTORS = 16
    for id in actor_positions:
        if int(id) == ignore_id:
            continue
        var body: Dictionary = actor_positions[id]
        if not bool(body.get("alive", true)):
            continue
        var centre: Vector2 = body.get("position", Vector2.ZERO)
        var detour_radius: float = (radius + float(body.get("radius", 0.0)) + 3.0) / cos(PI / float(SECTORS))
        for sector in range(SECTORS):
            var theta: float = TAU * float(sector) / float(SECTORS)
            var candidate: Vector2 = centre + Vector2(cos(theta), sin(theta)) * detour_radius
            if is_valid_position(candidate, radius, ignore_id):
                points.append(candidate)
    if diagnostics_enabled:
        diagnostics["graph_builds"] = int(diagnostics.graph_builds) + 1
        diagnostics["max_nodes"] = maxi(int(diagnostics.max_nodes), points.size())
        diagnostics["candidate_pairs"] = int(diagnostics.candidate_pairs) + points.size() * (points.size() - 1) / 2
    var graph := AStar2D.new()
    for index in range(points.size()):
        graph.add_point(index, points[index])
    # Only local visibility edges are needed: the fixed terrain waypoints
    # bridge long routes, while circle waypoints permit close-quarter sidesteps.
    var max_edge: float = maxf(bake.step.x, bake.step.y) * 2.1
    for i in range(points.size()):
        for j in range(i + 1, points.size()):
            if points[i].distance_to(points[j]) > max_edge:
                continue
            if clear_segment(points[i], points[j], radius, ignore_id):
                graph.connect_points(i, j)
    var route: PackedVector2Array = graph.get_point_path(0, 1)
    if route.size() < 2:
        return PackedVector2Array()
    # Remove redundant centre/ring waypoints without changing endpoints.
    var smoothed := PackedVector2Array([route[0]])
    var cursor := 0
    while cursor < route.size() - 1:
        var next := route.size() - 1
        while next > cursor + 1 and not clear_segment(route[cursor], route[next], radius, ignore_id):
            next -= 1
        smoothed.append(route[next])
        cursor = next
    return smoothed

## In FREE mode a click within an enemy footprint should stop at the
## nearest accessible edge, not freeze because its literal point is occupied.
## Never snap clicks on painted river/rock: those must remain invalid.
func safe_landing(start: Vector2, requested: Vector2, radius: float = 0.0, ignore_id: int = -1) -> Vector2:
    if bake.cell_at_screen(requested, true) == Vector2i(-1, -1):
        return requested
    if is_valid_position(requested, radius, ignore_id):
        return requested
    var nearest: Vector2 = requested
    var best: float = INF
    var blocked_by_actor := false
    for id in actor_positions:
        if int(id) == ignore_id:
            continue
        var body: Dictionary = actor_positions[id]
        if not bool(body.get("alive", true)):
            continue
        var centre: Vector2 = body.get("position", Vector2.ZERO)
        var separation: float = radius + float(body.get("radius", 0.0))
        if requested.distance_to(centre) >= separation - EPSILON:
            continue
        blocked_by_actor = true
        var toward_start: Vector2 = start - centre
        if toward_start.length_squared() < EPSILON:
            toward_start = requested - centre
        if toward_start.length_squared() < EPSILON:
            toward_start = Vector2.LEFT
        var primary: float = toward_start.angle()
        for ring in [separation + 3.0, separation + 8.0]:
            for sector in range(24):
                var offset: float = TAU * float(sector) / 24.0
                var candidate: Vector2 = centre + Vector2(cos(primary + offset), sin(primary + offset)) * float(ring)
                if not is_valid_position(candidate, radius, ignore_id):
                    continue
                # Prefer the near side of the clicked actor. The subsequent
                # find_path still validates actual reachability and budget.
                var quality: float = candidate.distance_to(requested) + 0.14 * candidate.distance_to(start)
                if quality < best:
                    best = quality
                    nearest = candidate
    return nearest if blocked_by_actor and best < INF else requested

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

## Visibility is independent of movement collision: attacker and defender
## themselves are endpoints, while terrain and other living actors can block.
func attack_line_clear(start: Vector2, finish: Vector2, ignore_ids: Array = []) -> bool:
    if bake.error != "" or not is_finite(start.x) or not is_finite(start.y) or not is_finite(finish.x) or not is_finite(finish.y):
        return false
    var separation := start.distance_to(finish)
    var stride: float = maxf(2.0, minf(bake.step.x, bake.step.y) * 0.15)
    var count := maxi(1, ceili(separation / stride))
    for step_index in range(count + 1):
        var point: Vector2 = start.lerp(finish, float(step_index) / float(count))
        if bake.cell_at_screen(point, true) == Vector2i(-1, -1):
            return false
        for actor_id in actor_positions:
            if ignore_ids.has(int(actor_id)):
                continue
            var actor: Dictionary = actor_positions[actor_id]
            if not bool(actor.get("alive", true)):
                continue
            if point.distance_to(Vector2(actor.get("position", Vector2.ZERO))) < float(actor.get("radius", 0.0)):
                return false
    return true

func find_attack_approach(source: Vector2, target: Vector2, min_range: float,
        max_range: float, move_budget: float, radius: float = 0.0,
        target_radius: float = 0.0, ignore_id: int = -1,
        target_id: int = -1, require_line_of_sight: bool = false) -> Dictionary:
    if move_budget < 0.0 or min_range < 0.0 or max_range < min_range:
        return {}
    if attack_in_range(source, target, min_range, max_range, radius, target_radius):
        if not require_line_of_sight or attack_line_clear(source, target, [ignore_id,target_id]):
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
            # Euclidean length is a lower bound for every legal walking route.
            # Skip expensive path search when the candidate cannot beat budget
            # or a shorter legal route already found.
            var straight: float=source.distance_to(point)
            if straight>move_budget+EPSILON:
                continue
            if not best.is_empty() and straight>=float(best.cost)-EPSILON:
                continue
            if require_line_of_sight and not attack_line_clear(point,target,[ignore_id,target_id]):
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

## PR #57 API compatibility: use its exact visibility-graph implementation,
## without changing the continuous battle authority introduced by PR #62.
func valid_position(point: Vector2, occupied: Array = [], exclude_id: int = -1) -> bool:
    return waypoint_compat.valid_position(point, occupied, exclude_id)

func shortest_path(start: Vector2, goal: Vector2, occupied: Array = [], exclude_id: int = -1) -> PackedVector2Array:
    return waypoint_compat.shortest_path(start, goal, occupied, exclude_id)

func within_budget(path: PackedVector2Array, budget: float) -> Vector2:
    return waypoint_compat.within_budget(path, budget)

func attack_position(start: Vector2, target: Vector2, minimum_range: float,
        maximum_range: float, move_budget: float, occupied: Array = [],
        exclude_id: int = -1) -> Dictionary:
    return waypoint_compat.attack_position(start, target, minimum_range,
        maximum_range, move_budget, occupied, exclude_id)
