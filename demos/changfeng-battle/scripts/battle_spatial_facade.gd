extends RefCounted
## Shared geometric queries. Rules still own timing, costs and state mutation.
## FREE intentionally retains the MapBake/AStarGrid2D implementation.
var state: Variant

func _init(battle_state: Variant) -> void:
    state = battle_state

func unit_distance() -> float:
    if state.spatial == null:
        return 1.0
    return maxf(state.spatial.bake.step.x, state.spatial.bake.step.y)

func _sync_actors() -> void:
    if state.spatial == null:
        return
    var positions: Dictionary = {}
    for actor in state.actors:
        positions[actor.id] = {"position": actor.position,
            "radius": 8.0, "alive": actor.hp_u > 0}
    state.spatial.set_actors(positions)

func can_land(actor: Variant, position: Variant) -> bool:
    if state.spatial_mode == "GRID":
        return (position is Vector2i and state.passable(position)
            and not state.occupied(position, actor.id))
    if state.spatial == null or not position is Vector2:
        return false
    _sync_actors()
    return state.spatial.is_valid_position(position, 8.0, actor.id)

func safe_landing(actor: Variant, requested: Vector2) -> Vector2:
    if state.spatial_mode != "FREE" or state.spatial == null:
        return actor.position
    _sync_actors()
    return state.spatial.safe_landing(actor.position, requested, 8.0, actor.id)

func find_path(actor: Variant, goal: Variant) -> Variant:
    if state.spatial_mode == "GRID":
        if not goal is Vector2i:
            return []
        return state.reachable_paths(actor.cell, actor.id).get(goal, [])
    if state.spatial == null or not goal is Vector2:
        return PackedVector2Array()
    _sync_actors()
    return state.spatial.find_path(actor.position, goal, 8.0, actor.id)

func path_cost(path: Variant) -> float:
    if state.spatial_mode == "GRID":
        return float(path.size()) if path is Array else INF
    if state.spatial == null:
        return INF
    return state.spatial.path_length(PackedVector2Array(path))

func can_attack(actor: Variant, target: Variant, min_steps: float,
        max_steps: float, require_line_of_sight: bool = true) -> bool:
    if max_steps < min_steps or min_steps < 0.0:
        return false
    if state.spatial_mode == "GRID":
        var d: int = absi(actor.cell.x - target.cell.x) + absi(actor.cell.y - target.cell.y)
        if float(d) < min_steps or float(d) > max_steps:
            return false
        # Adjacent basic attacks preserve the original rule. Ranged calls
        # honor LOS instead of silently ignoring the facade parameter.
        if not require_line_of_sight or d <= 1:
            return true
        if actor.cell.x != target.cell.x and actor.cell.y != target.cell.y:
            return false
        var direction := Vector2i(signi(target.cell.x - actor.cell.x),
            signi(target.cell.y - actor.cell.y))
        var cell: Vector2i = actor.cell + direction
        while cell != target.cell:
            if not state.passable(cell) or state.occupied(cell):
                return false
            cell += direction
        return true
    if state.spatial == null:
        return false
    _sync_actors()
    var unit: float = unit_distance()
    if not state.spatial.attack_in_range(actor.position, target.position,
            min_steps * unit, max_steps * unit, 8.0, 8.0):
        return false
    return not require_line_of_sight or state.spatial.attack_line_clear(
        actor.position, target.position, [actor.id, target.id])

func find_attack_approach(actor: Variant, target: Variant, min_range: float,
        max_range: float, budget: float, require_los: bool = true) -> Dictionary:
    if state.spatial_mode != "FREE" or state.spatial == null:
        return {}
    _sync_actors()
    return state.spatial.find_attack_approach(actor.position,target.position,
        min_range,max_range,budget,8.0,8.0,actor.id,target.id,require_los)

## Reusable, non-mutating FREE landing and route preparation.
## CombatRules remains responsible for timing, budget, hooks, and payment.
func plan_free_landing(actor: Variant, requested: Vector2) -> Dictionary:
    if state.spatial_mode != "FREE" or state.spatial == null:
        return {"success":false,"error_code":"WRONG_SPATIAL_MODE"}
    if not is_finite(requested.x) or not is_finite(requested.y) or absf(requested.x) > 100000.0 or absf(requested.y) > 100000.0:
        return {"success":false,"error_code":"INVALID_POSITION"}
    var goal := Vector2(roundf(requested.x * 4.0) * 0.25,
        roundf(requested.y * 4.0) * 0.25)
    if state.spatial.bake.cell_at_screen(goal, true) == Vector2i(-1, -1):
        return {"success":false,"error_code":"INVALID_POSITION"}
    _sync_actors()
    goal = state.spatial.safe_landing(actor.position, goal, 8.0, actor.id)
    goal = Vector2(roundf(goal.x * 4.0) * 0.25,
        roundf(goal.y * 4.0) * 0.25)
    var cell: Vector2i = state.spatial.bake.cell_at_screen(goal, true)
    if cell == Vector2i(-1, -1):
        return {"success":false,"error_code":"INVALID_POSITION"}
    var path: PackedVector2Array = state.spatial.find_path(
        actor.position, goal, 8.0, actor.id)
    if path.size() < 2:
        return {"success":false,"error_code":"UNREACHABLE_POSITION"}
    return {"success":true,"position":goal,"cell":cell,"path":path,
        "distance":state.spatial.path_length(path)}

## Recheck rounded approach endpoints with exactly the same collision and LOS
## requirements as the initial approach search.
func check_attack_approach(actor: Variant, target: Variant, plan: Dictionary,
        min_range: float, max_range: float, require_los: bool) -> Dictionary:
    if state.spatial_mode != "FREE" or state.spatial == null or plan.is_empty():
        return {"success":false,"error_code":"NO_ATTACK_POSITION"}
    _sync_actors()
    var destination: Vector2 = Vector2(plan.position)
    var route: PackedVector2Array = PackedVector2Array(plan.path)
    var travelled: float = float(plan.cost)
    if travelled > 0.0001:
        destination = Vector2(roundf(destination.x * 4.0) * 0.25,
            roundf(destination.y * 4.0) * 0.25)
        if not state.spatial.is_valid_position(destination, 8.0, actor.id):
            return {"success":false,"error_code":"INVALID_POSITION"}
        route = state.spatial.find_path(actor.position, destination, 8.0, actor.id)
        if route.size() < 2:
            return {"success":false,"error_code":"UNREACHABLE_POSITION"}
        travelled = state.spatial.path_length(route)
    var cell: Vector2i = state.spatial.bake.cell_at_screen(destination, true)
    if cell == Vector2i(-1, -1):
        return {"success":false,"error_code":"INVALID_POSITION"}
    if not state.spatial.attack_in_range(destination, target.position,
            min_range, max_range, 8.0, 8.0):
        return {"success":false,"error_code":"INVALID_RANGE"}
    if require_los and not state.spatial.attack_line_clear(
            destination, target.position, [actor.id, target.id]):
        return {"success":false,"error_code":"LINE_BLOCKED"}
    return {"success":true,"position":destination,"cell":cell,
        "path":route,"distance":travelled}

## Forced displacement is an axis-constrained action, never an A* detour.
## This proposal is also used by CombatResolver, so previews and committed
## knockback cannot disagree about the final landing or obstacle stop.
func forced_move_preview(actor: Variant, goal: Variant, max_cost: float) -> Dictionary:
    if max_cost <= 0.0:
        return {}
    if state.spatial_mode == "GRID":
        if not goal is Vector2i:
            return {}
        var offset: Vector2i = Vector2i(goal) - actor.cell
        var delta: Vector2i = Vector2i.ZERO
        if absi(offset.x) >= absi(offset.y):
            delta = Vector2i(signi(offset.x), 0)
        else:
            delta = Vector2i(0, signi(offset.y))
        if delta == Vector2i.ZERO:
            return {}
        var path: Array = []
        var cell: Vector2i = actor.cell
        for _step in range(maxi(0, int(max_cost))):
            var next: Vector2i = cell + delta
            if not state.passable(next) or state.occupied(next, actor.id):
                break
            path.append(next)
            cell = next
        if path.is_empty():
            return {}
        return {"cell":cell,"position":cell,"path":path,"cost":float(path.size())}
    if state.spatial == null or not goal is Vector2:
        return {}
    var direction: Vector2 = Vector2(goal) - actor.position
    var length: float = minf(direction.length(), max_cost)
    if length < 0.25:
        return {}
    direction = direction.normalized()
    _sync_actors()
    var unit: float = unit_distance()
    var samples: int = maxi(1, ceili(length * 24.0 / unit))
    var start: Vector2 = actor.position
    var end: Vector2 = start
    for index in range(1, samples + 1):
        var candidate: Vector2 = start + direction * (float(index) * unit / 24.0)
        if not state.spatial.is_valid_position(candidate, 8.0, actor.id):
            break
        end = candidate
    if end.distance_to(start) < 0.25:
        return {}
    end = Vector2(roundf(end.x * 4.0) * 0.25,
        roundf(end.y * 4.0) * 0.25)
    var cell: Vector2i = state.spatial.bake.cell_at_screen(end)
    if cell == Vector2i(-1, -1):
        return {}
    return {"cell":cell,"position":end,
        "path":PackedVector2Array([start, end]),"cost":end.distance_to(start)}

func forced_displacement(actor: Variant, source: Variant,
        steps: int, towards_attacker: bool) -> Dictionary:
    if actor == null or source == null or steps <= 0:
        return {}
    if state.spatial_mode == "GRID":
        var offset: Vector2i = actor.cell - source.cell
        var delta: Vector2i = Vector2i.ZERO
        if absi(offset.x) >= absi(offset.y):
            delta = Vector2i(signi(offset.x), 0)
        else:
            delta = Vector2i(0, signi(offset.y))
        if towards_attacker:
            delta = -delta
        return forced_move_preview(actor, actor.cell + delta * steps, float(steps))
    if state.spatial == null:
        return {}
    var vector: Vector2 = actor.position - source.position
    if vector.length_squared() < 0.0001:
        return {}
    var direction: Vector2 = vector.normalized()
    if towards_attacker:
        direction = -direction
    var total: float = float(steps) * unit_distance()
    return forced_move_preview(actor, actor.position + direction * total, total)
