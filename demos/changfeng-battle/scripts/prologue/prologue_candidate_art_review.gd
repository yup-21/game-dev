@tool
extends Node2D
## Isolated Godot-editor visual review for prologue scene candidates.
## Never changes formal Chapter/Story state or the normal four-zone QA.
## Candidate PNG layers are intentionally optional until art signoff.

@export_enum("temple_hall", "mountain_road") var scene_id: String = "temple_hall"
@export var show_walkable_guides: bool = true

var imported_layer_count: int = 0
var missing_layers: Array[String] = []

func _ready() -> void:
	_load_candidate()
	_show_review_info()

func _load_candidate() -> void:
	imported_layer_count = 0
	missing_layers.clear()
	var source_dir := "res://assets/candidates/prologue/%s/" % scene_id
	var layer_names := ["background", "ground", "foreground"]
	var textures: Array[Texture2D] = []
	for layer_name in layer_names:
		var resource_path := source_dir + layer_name + ".png"
		if not ResourceLoader.exists(resource_path):
			missing_layers.append(resource_path)
			continue
		var texture := load(resource_path) as Texture2D
		if texture == null or texture.get_size() != Vector2(1600, 1000):
			missing_layers.append(resource_path + " (invalid 1600x1000 texture)")
		else:
			textures.append(texture)
	if not missing_layers.is_empty():
		# Avoid half-layered images; keep the original native blockout visible.
		return
	var native_zone: Node2D = get_node("NativeZone")
	for visual_node in ["Architecture", "BlockoutArt", "Campfire", "BrokenCart"]:
		var visual := native_zone.get_node_or_null(visual_node) as CanvasItem
		if visual:
			visual.visible = false
	for i in range(3):
		var sprite := Sprite2D.new()
		sprite.name = "Preview_" + layer_names[i]
		sprite.texture = textures[i]
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.z_index = [0, 1, 25][i]
		add_child(sprite)
		# Native QA geometry remains the authority; only appearance changes.
		imported_layer_count += 1
	var navigation := native_zone.get_node_or_null("Navigation/Walkable") as CanvasItem
	if navigation:
		navigation.visible = show_walkable_guides

func _show_review_info() -> void:
	var label := Label.new()
	label.name = "ArtReviewStatus"
	label.position = Vector2(20, 15)
	label.z_index = 30
	label.add_theme_color_override("font_color", Color(1, 0.93, 0.72))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	if missing_layers.is_empty():
		label.text = "候选美术预览（未验收）· %s · 三层 1600x1000" % scene_id
	else:
		label.text = "候选图未导入；当前显示原生灰盒。请复制素材包到 assets/candidates/prologue/%s/" % scene_id
	add_child(label)
