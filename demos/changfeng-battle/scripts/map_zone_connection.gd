extends RefCounted
## Reusable native map-to-map connector. Authoring is entirely in
## WuxiaMapMarkerDefinition(zone_exit) + a target spawn marker; no screen seam
## arithmetic, stitched map pixels or hard-coded destination coordinates.
static func resolve_exit(source_bake, exit_id: String, target_bake,
        actor_radius: float) -> Dictionary:
    if source_bake == null or target_bake == null or actor_radius < 0.0:
        return {}
    if not source_bake.error.is_empty() or not target_bake.error.is_empty():
        return {}
    var exit_marker: Dictionary = source_bake.markers.get(exit_id, {})
    if str(exit_marker.get("kind", "")) != "zone_exit":
        return {}
    var target_zone_id := str(exit_marker.get("target_zone_id", ""))
    var entry_id := str(exit_marker.get("target_entry_id", ""))
    if target_zone_id != target_bake.id:
        return {}
    var entry: Dictionary = target_bake.markers.get(entry_id, {})
    if str(entry.get("kind", "")) != "spawn":
        return {}
    var destination: Vector2 = target_bake.marker_position(entry_id)
    if destination == Vector2.INF or not target_bake.is_walkable_point(
            destination, actor_radius):
        return {}
    return {
        "target_zone_id": target_zone_id,
        "target_entry_id": entry_id,
        "spawn": destination,
        "exit_side": str(exit_marker.get("exit_side", "none"))
    }
