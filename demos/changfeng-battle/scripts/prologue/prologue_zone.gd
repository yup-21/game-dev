@tool
extends Node2D
## Editable native prologue zone. The Walkable Polygon2D and the blocker
## Polygon2D nodes remain the single authority for collision.
## Painted layers stay editable in the native scene. Validate against the
## registered SceneArtProfile instead of creating sprites during _ready().

@export var zone_id: String = ""
@export var zone_title: String = ""
@export var scene_art: WuxiaSceneArtProfile

const ART_SIZE := Vector2(1600, 1000)
const ART_LAYERS := ["background", "ground", "foreground"]

var painted_layer_count: int = 0
var walkable: Polygon2D:
	get: return get_node("Navigation/Walkable") as Polygon2D
var blockers: Node2D:
	get: return get_node("Navigation/Blockers") as Node2D

func _ready() -> void:
	_validate_painted_layers()

func _validate_painted_layers() -> void:
	painted_layer_count = 0
	if zone_id not in ["temple_hall", "mountain_road"]:
		return
	if scene_art == null or not scene_art.valid_for(Vector2i(1600, 1000)) \
		or scene_art.foreground == null:
		push_warning("Missing or invalid native scene art: " + zone_id)
		return
	var holder := get_node_or_null("PaintedLayers") as Node2D
	if holder == null:
		push_warning("Missing editable PaintedLayers: " + zone_id)
		return
	for role in ART_LAYERS:
		var sprite := holder.get_node_or_null(role.capitalize()) as Sprite2D
		var expected := scene_art.get(role) as Texture2D
		if sprite == null or sprite.texture == null or expected == null \
			or sprite.texture.resource_path != expected.resource_path \
			or sprite.texture.get_size() != ART_SIZE:
			push_warning("Native scene layer mismatches SceneArtProfile: " + zone_id + "/" + role)
			painted_layer_count = 0
			return
		painted_layer_count += 1

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
