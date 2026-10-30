extends RefCounted
## Continuous-space rules prototype. Positions are in MapBake foot-anchor units.
## The authored tile mask is a coarse obstacle source, NOT a landing-point grid.
## Deterministic waypoint search is deliberately independent of scene nodes.
const MapBake = preload("res://scripts/map_bake.gd")
const EPSILON := 0.001
var bake
var clearance: float = 10.0

func _init(map_path: String = MapBake.DEFAULT_PATH, actor_clearance: float = 10.0) -> void:
    bake = MapBake.new(map_path)
    clearance = maxf(0.0, actor_clearance)

func valid_position(point: Vector2, occupied: Array = [], exclude_id: int = -1) -> bool:
    if not is_finite(point.x) or not is_finite(point.y) or not bake.error.is_empty():
        return false
    # Clearance checks sample the circumference; a character must not clip
    # river banks or rocks even when its centre is on traversable ground.
    for i in range(9):
        var sample := point
        if i > 0:
            var angle := TAU * float(i - 1) / 8.0
            sample += Vector2(cos(angle), sin(angle)) * clearance
        var cell: Vector2i = bake.cell_at_screen(sample, true)
        if cell.x < 0:
            return false
    for body in occupied:
        if int(body.get("id", -1)) == exclude_id or not bool(body.get("alive", true)):
            continue
        var other: Vector2 = body.get("position", Vector2.ZERO)
        var minimum: float = clearance + float(body.get("radius", clearance))
        if point.distance_squared_to(other) < minimum * minimum - EPSILON:
            return false
    return true

func clear_segment(start: Vector2, goal: Vector2, occupied: Array = [], exclude_id: int = -1) -> bool:
    var length := start.distance_to(goal)
    var stride := maxf(2.0, minf(bake.step.x, bake.step.y) / 6.0)
    var count := maxi(1, ceili(length / stride))
    for i in range(count + 1):
        if not valid_position(start.lerp(goal, float(i) / float(count)), occupied, exclude_id):
            return false
    return true

func shortest_path(start: Vector2, goal: Vector2, occupied: Array = [], exclude_id: int = -1) -> PackedVector2Array:
    var empty := PackedVector2Array()
    if not valid_position(start, occupied, exclude_id) or not valid_position(goal, occupied, exclude_id):
        return empty
    if clear_segment(start, goal, occupied, exclude_id):
        return PackedVector2Array([start, goal])
    # Visibility graph over obstacle-corner waypoints. The points are offset
    # inward from each traversable cell corner; endpoints remain arbitrary.
    var points: Array[Vector2] = [start, goal]
    var inset := clearance + 2.0
    for y in range(bake.height):
        for x in range(bake.width):
            var cell := Vector2i(x, y)
            if not bake.is_walkable(cell):
                continue
            var rect: Rect2 = bake.cell_rect(cell)
            for corner in [rect.position + Vector2(inset, inset),
                    rect.position + Vector2(rect.size.x - inset, inset),
                    rect.end - Vector2(inset, inset),
                    rect.position + Vector2(inset, rect.size.y - inset)]:
                if valid_position(corner, occupied, exclude_id):
                    points.append(corner)
    var dist: Array[float] = []
    var prev: Array[int] = []
    var done: Dictionary = {}
    for _point in points:
        dist.append(INF)
        prev.append(-1)
    dist[0] = 0.0
    # Cache visibility results: the graph can contain hundreds of waypoints.
    var visibility: Dictionary = {}
    for _iteration in range(points.size()):
        var best := -1
        for i in range(points.size()):
            if not done.has(i) and (best < 0 or dist[i] < dist[best]):
                best = i
        if best < 0 or is_inf(dist[best]):
            break
        if best == 1:
            break
        done[best] = true
        for j in range(points.size()):
            if j == best or done.has(j):
                continue
            var cost: float = points[best].distance_to(points[j])
            if dist[best] + cost + EPSILON >= dist[j]:
                continue
            var edge := Vector2i(mini(best, j), maxi(best, j))
            if not visibility.has(edge):
                visibility[edge] = clear_segment(points[best], points[j], occupied, exclude_id)
            if bool(visibility[edge]):
                dist[j] = dist[best] + cost
                prev[j] = best
    if is_inf(dist[1]):
        return empty
    var reverse: Array[Vector2] = []
    var index := 1
    while index >= 0:
        reverse.append(points[index])
        index = prev[index]
    reverse.reverse()
    return PackedVector2Array(reverse)

func path_length(path: PackedVector2Array) -> float:
    var result := 0.0
    for i in range(1, path.size()):
        result += path[i - 1].distance_to(path[i])
    return result

func within_budget(path: PackedVector2Array, budget: float) -> Vector2:
    if path.is_empty():
        return Vector2(INF, INF)
    var remaining := maxf(0.0, budget)
    for i in range(1, path.size()):
        var distance := path[i - 1].distance_to(path[i])
        if remaining <= distance:
            return path[i - 1].lerp(path[i], remaining / maxf(distance, EPSILON))
        remaining -= distance
    return path[path.size() - 1]

func attack_position(start: Vector2, target: Vector2, minimum_range: float,
        maximum_range: float, move_budget: float, occupied: Array = [],
        exclude_id: int = -1) -> Dictionary:
    # Search candidate points on concentric attack rings. This is a
    # deterministic prototype; cover/LOS and weapon arcs are later phases.
    if maximum_range < minimum_range or minimum_range < 0.0:
        return {}
    var best: Dictionary = {}
    var radii := [maxf(minimum_range, minf(maximum_range, start.distance_to(target))),
            minimum_range, maximum_range, (minimum_range + maximum_range) * 0.5]
    for radius in radii:
        for i in range(32):
            var angle := TAU * float(i) / 32.0
            var destination := target + Vector2(cos(angle), sin(angle)) * radius
            if not valid_position(destination, occupied, exclude_id):
                continue
            var path := shortest_path(start, destination, occupied, exclude_id)
            if path.is_empty():
                continue
            var cost := path_length(path)
            if cost > move_budget + EPSILON:
                continue
            if best.is_empty() or cost < float(best.cost):
                best = {"position": destination, "path": path, "cost": cost}
    return best
