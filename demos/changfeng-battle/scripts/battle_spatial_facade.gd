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
        # Basic melee adjacency is always clear. Other GRID LOS checks
        # remain in the existing ability validator.
        return float(d) >= min_steps and float(d) <= max_steps
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

func forced_move_preview(actor: Variant, goal: Variant, max_cost: float) -> Dictionary:
    # Geometry-only proposal. CombatResolver must authorize and commit
    # any knockback or forced movement separately.
    var path: Variant = find_path(actor,goal)
    if path.size() == 0:
        return {}
    if state.spatial_mode == "GRID":
        var allowed: int = mini(path.size(),maxi(0,int(max_cost)))
        if allowed == 0:
            return {}
        return {"position":path[allowed-1],
            "path":path.slice(0,allowed),"cost":float(allowed)}
    var trimmed: PackedVector2Array = state.spatial.trim_path(
        PackedVector2Array(path),maxf(0.0,max_cost))
    if trimmed.is_empty():
        return {}
    return {"position":trimmed[trimmed.size()-1],
        "path":trimmed,"cost":state.spatial.path_length(trimmed)}
