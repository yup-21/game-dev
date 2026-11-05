extends Node2D
## Editable native prologue zone. The Walkable Polygon2D and the blocker
## Polygon2D nodes are the QA scene's single source of walk/collision geometry.

@export var zone_id: String = ""
@export var zone_title: String = ""

var walkable: Polygon2D:
	get: return get_node("Navigation/Walkable") as Polygon2D
var blockers: Node2D:
	get: return get_node("Navigation/Blockers") as Node2D

func permits_foot(point: Vector2, radius: float = 20.0) -> bool:
	var samples := [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0),
		Vector2(0, radius), Vector2(0, -radius),
		Vector2(radius * 0.7, radius * 0.7), Vector2(-radius * 0.7, radius * 0.7),
		Vector2(radius * 0.7, -radius * 0.7), Vector2(-radius * 0.7, -radius * 0.7)]
	for offset in samples:
		var sample: Vector2 = point + offset
		if not Geometry2D.is_point_in_polygon(sample, walkable.polygon):
			return false
		for obstacle in blockers.get_children():
			if obstacle is Polygon2D and Geometry2D.is_point_in_polygon(sample, obstacle.polygon):
				return false
	return true

func entry_position(entry_id: String) -> Vector2:
	var marker: Marker2D = get_node_or_null("Entries/" + entry_id) as Marker2D
	return marker.position if marker != null else Vector2.INF
