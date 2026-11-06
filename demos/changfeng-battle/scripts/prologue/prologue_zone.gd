@tool
extends Node2D
## Editable native prologue zone. The Walkable Polygon2D and the blocker
## Polygon2D nodes remain the single authority for collision.
## Candidate raster art is optional: all three aligned layers must be present
## before the original blockout is visually replaced.

@export var zone_id: String = ""
@export var zone_title: String = ""

const ART_FOLDER := "res://assets/candidates/prologue/"
const ART_SIZE := Vector2(1600, 1000)
const ART_Z := [0, 1, 17]
const ART_LAYERS := ["background", "ground", "foreground"]

var painted_layer_count: int = 0
var walkable: Polygon2D:
	get: return get_node("Navigation/Walkable") as Polygon2D
var blockers: Node2D:
	get: return get_node("Navigation/Blockers") as Node2D

func _ready() -> void:
	_load_painted_candidate()

func _load_painted_candidate() -> void:
	painted_layer_count = 0
	if zone_id not in ["temple_hall", "mountain_road"]:
		return
	var textures: Array[Texture2D] = []
	# Prefer lossless PNG when imported locally. Remote PR carries aligned
	# high-quality WebP in all three layers; never combine mixed partial sets.
	for extension in [".png", ".webp"]:
		if extension == ".webp":
			# WebP authoring is declared in the native SceneArtProfile Resource,
			# not only hidden in hardcoded file paths.
			var art_path := (
				"res://data/native/scene_art/prologue_%s.tres" % zone_id)
			if ResourceLoader.exists(art_path):
				var art := load(art_path) as WuxiaSceneArtProfile
				if art != null and art.valid_for(Vector2i(1600, 1000)) and art.foreground != null:
					textures.append(art.background)
					textures.append(art.ground)
					textures.append(art.foreground)
					break
		var candidate: Array[Texture2D] = []
		for role in ART_LAYERS:
			var file_path: String = ART_FOLDER + zone_id + "/" + role + extension
			if not ResourceLoader.exists(file_path):
				break
			var tex := load(file_path) as Texture2D
			if tex == null or tex.get_size() != ART_SIZE:
				push_warning("Invalid prologue candidate texture (must be 1600x1000): " + file_path)
				break
			candidate.append(tex)
		if candidate.size() == 3:
			textures = candidate
			break
	if textures.size() != 3:
		return
	var holder := get_node_or_null("PaintedLayers") as Node2D
	if holder == null:
		holder = Node2D.new()
		holder.name = "PaintedLayers"
		add_child(holder)
	for i in range(ART_LAYERS.size()):
		var sprite := holder.get_node_or_null(ART_LAYERS[i].capitalize()) as Sprite2D
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.name = ART_LAYERS[i].capitalize()
			holder.add_child(sprite)
		sprite.texture = textures[i]
		sprite.centered = false
		sprite.position = Vector2.ZERO
		sprite.z_index = ART_Z[i]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		painted_layer_count += 1
	# Existing editable geometry / event markers remain in the scene.
	var blockout_path := "Architecture" if zone_id == "temple_hall" else "BlockoutArt"
	var blockout := get_node_or_null(blockout_path) as CanvasItem
	if blockout != null:
		blockout.visible = false
	if zone_id == "temple_hall":
		# Flames stay visible above the painted ground, below the hero.
		var fire := get_node_or_null("Campfire") as CanvasItem
		if fire != null:
			fire.z_index = 12
	else:
		# This cart is already painted into the foreground layer.
		var old_cart := get_node_or_null("BrokenCart") as CanvasItem
		if old_cart != null:
			old_cart.visible = false

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
