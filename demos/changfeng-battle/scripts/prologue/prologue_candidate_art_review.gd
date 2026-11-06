@tool
extends Node2D
## Isolated Godot-editor review for prologue candidate art.
## Native zones themselves bind complete three-layer sets. No duplicate sprites.
@export_enum("temple_hall", "mountain_road") var scene_id: String = "temple_hall"
@export var show_walkable_guides: bool = true

var imported_layer_count: int = 0
var missing_layers: Array[String] = []

func _ready() -> void:
	_sync_with_zone()
	_show_review_info()

func _sync_with_zone() -> void:
	var native_zone := get_node_or_null("NativeZone") as Node2D
	if native_zone == null:
		return
	imported_layer_count = native_zone.painted_layer_count
	missing_layers.clear()
	if imported_layer_count != 3:
		for role in ["background", "ground", "foreground"]:
			missing_layers.append(
				"res://assets/candidates/prologue/%s/%s.png" % [scene_id, role])
	var navigation := native_zone.get_node_or_null("Navigation/Walkable") as CanvasItem
	if navigation != null:
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
	if imported_layer_count == 3:
		label.text = "候选美术预览（未验收）· %s · 三层 1600×1000" % scene_id
	else:
		label.text = "候选美术未完整导入，显示原生灰盒 · %s" % scene_id
	add_child(label)
