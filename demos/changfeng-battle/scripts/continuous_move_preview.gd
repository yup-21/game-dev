extends Node2D
## Presentation-only continuous movement preview. Never commits a BattleModel action.
var route := Line2D.new()
var marker := Polygon2D.new()
var cost_label := Label.new()

func _ready() -> void:
    name = "ContinuousMovePreview"
    z_index = 110
    route.width = 3.0
    route.default_color = Color(0.48, 0.96, 0.77, 0.9)
    route.antialiased = true
    add_child(route)
    marker.polygon = PackedVector2Array([
        Vector2(0,-9),Vector2(9,0),Vector2(0,9),Vector2(-9,0)])
    marker.color = Color(0.9, 0.8, 0.4, 0.9)
    add_child(marker)
    cost_label.add_theme_font_size_override("font_size", 14)
    cost_label.add_theme_color_override("font_color", Color.WHITE)
    add_child(cost_label)
    clear_preview()

func clear_preview() -> void:
    visible = false
    route.clear_points()

func show_preview(path: PackedVector2Array, cost: float, reachable: bool) -> void:
    if path.size() < 2:
        clear_preview()
        return
    visible = true
    route.points = path
    route.default_color = Color(0.48,0.96,0.77,0.9) if reachable else Color(0.97,0.43,0.36,0.9)
    marker.position = path[-1]
    marker.color = route.default_color
    cost_label.position = path[-1] + Vector2(13,-24)
    cost_label.text = "%.0f" % cost
