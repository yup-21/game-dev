extends Node2D
## Presentation-only FREE movement range and path preview.
## The circle is a geometric upper bound; walls and actor occupancy can make
## some points inside it unreachable. BattleModel validates every actual move.
var range_fill := Polygon2D.new()
var range_outline := Line2D.new()
var route := Line2D.new()
var marker := Polygon2D.new()
var cost_label := Label.new()
var _range_origin := Vector2.INF
var _range_radius := -1.0

func _ready() -> void:
    name = "ContinuousMovePreview"
    z_index = 110
    range_fill.color = Color(0.31, 0.84, 0.65, 0.055)
    add_child(range_fill)
    range_outline.width = 1.5
    range_outline.default_color = Color(0.45, 0.93, 0.72, 0.48)
    range_outline.antialiased = true
    add_child(range_outline)
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
    clear_all()

func show_range(origin: Vector2, radius: float) -> void:
    if radius <= 0.0 or not is_finite(radius):
        clear_all()
        return
    visible = true
    range_fill.visible = true
    range_outline.visible = true
    if _range_origin == origin and is_equal_approx(_range_radius, radius):
        return
    _range_origin = origin
    _range_radius = radius
    # Logical FREE range is circular in the current screen-space rules.
    # An ellipse would be misleading until a ground projection is introduced.
    var points := PackedVector2Array()
    for index in range(64):
        var angle: float = TAU * float(index) / 64.0
        points.append(Vector2(cos(angle), sin(angle)) * radius)
    range_fill.polygon = points
    range_fill.position = origin
    var closed := points.duplicate()
    closed.append(points[0])
    range_outline.points = closed
    range_outline.position = origin

func clear_preview() -> void:
    route.visible = false
    marker.visible = false
    cost_label.visible = false
    route.clear_points()
    visible = range_fill.visible

func clear_all() -> void:
    clear_preview()
    range_fill.visible = false
    range_outline.visible = false
    _range_origin = Vector2.INF
    _range_radius = -1.0
    visible = false

func show_preview(path: PackedVector2Array, cost: float, reachable: bool, max_distance: float = INF) -> void:
    if path.size() < 2 or cost > max_distance + 0.001:
        clear_preview()
        return
    visible = true
    route.visible = true
    marker.visible = true
    cost_label.visible = true
    route.points = path
    route.default_color = Color(0.48,0.96,0.77,0.9) if reachable else Color(0.97,0.43,0.36,0.9)
    marker.position = path[-1]
    marker.color = route.default_color
    cost_label.position = path[-1] + Vector2(13,-24)
    cost_label.text = "%.0f" % cost
