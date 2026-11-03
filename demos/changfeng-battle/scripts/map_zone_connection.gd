extends RefCounted
## Reusable native map connection validation; map art and gameplay remain
## independent of route topology. A zone_exit must resolve to a named SPAWN
## on a DIFFERENT native map, not to another live exit/trigger marker.
static func resolve_exit(source_bake, exit_id: String, target_bake,
        actor_radius: float) -> Dictionary:
    if source_bake == null or target_bake == null or actor_radius < 0.0:
        return {}
    if not source_bake.error.is_empty() or not target_bake.error.is_empty():
        return {}
    var exit_marker: Dictionary = source_bake.markers.get(exit_id, {})
    if str(exit_marker.get("kind", "")) != "zone_exit":
        return {}
    var target_id := str(exit_marker.get("target_zone_id", ""))
    var entry_id := str(exit_marker.get("target_entry_id", ""))
    if target_id != target_bake.id or target_id == source_bake.id:
        return {}
    var entry: Dictionary = target_bake.markers.get(entry_id, {})
    if str(entry.get("kind", "")) != "spawn":
        return {}
    var spawn: Vector2 = target_bake.marker_position(entry_id)
    if spawn == Vector2.INF or not target_bake.is_walkable_point(spawn, actor_radius):
        return {}
    return {
        "target_zone_id": target_id,
        "target_entry_id": entry_id,
        "spawn": spawn,
        "exit_side": str(exit_marker.get("exit_side", "none"))
    }
