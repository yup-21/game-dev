@tool
extends Control
## Lightweight editor preview. No gameplay state or Resource writes.

var mode: String = "image"
var picture: Texture2D
var layers: Dictionary = {}
var columns: int = 6
var rows: int = 4
var frame: int = 0
var feet_offset: Vector2 = Vector2(0, -102)
var map_resource: Resource


func show_image(texture: Texture2D) -> void:
    mode = "image"
    picture = texture
    layers.clear()
    queue_redraw()


func show_atlas(texture: Texture2D, cols: int, row_count: int, feet: Vector2) -> void:
    mode = "atlas"
    picture = texture
    columns = maxi(cols, 1)
    rows = maxi(row_count, 1)
    feet_offset = feet
    frame = 0
    layers.clear()
    queue_redraw()


func show_scene(new_layers: Dictionary, map: Resource) -> void:
    mode = "scene"
    layers = new_layers
    map_resource = map
    queue_redraw()


func show_frame(index: int) -> void:
    frame = maxi(index, 0)
    queue_redraw()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.10, 0.12), true)
    for y in range(0, int(size.y), 24):
        for x in range(0, int(size.x), 24):
            if (x / 24 + y / 24) % 2 == 0:
                draw_rect(Rect2(x, y, 24, 24), Color(0.12, 0.14, 0.16), true)
    if mode == "scene":
        _draw_scene()
    elif picture != null:
        _draw_picture()


func _fitted(source_size: Vector2) -> Rect2:
    if source_size.x <= 0.0 or source_size.y <= 0.0:
        return Rect2()
    var ratio := minf((size.x - 12.0) / source_size.x, (size.y - 12.0) / source_size.y)
    var box := source_size * ratio
    return Rect2((size - box) * 0.5, box)


func _draw_picture() -> void:
    if mode == "atlas":
        var frame_size := Vector2(float(picture.get_width()) / float(columns),
                                  float(picture.get_height()) / float(rows))
        var cell := frame % maxi(columns * rows, 1)
        var source_rect := Rect2(Vector2(float(cell % columns), float(cell / columns)) * frame_size, frame_size)
        var dest := _fitted(frame_size)
        draw_texture_rect_region(picture, dest, source_rect)
        var marker := dest.position + dest.size * Vector2(0.5, 1.0)
        marker += feet_offset * (dest.size.x / frame_size.x)
        draw_line(marker - Vector2(7, 0), marker + Vector2(7, 0), Color.ORANGE, 2)
        draw_line(marker - Vector2(0, 7), marker + Vector2(0, 7), Color.ORANGE, 2)
    else:
        draw_texture_rect(picture, _fitted(picture.get_size()), false)


func _draw_scene() -> void:
    if not layers.has("primary"):
        return
    var background: Texture2D = layers["primary"]
    var dest := _fitted(background.get_size())
    for layer in ["primary", "ground", "foreground", "weather"]:
        if layers.has(layer):
            draw_texture_rect(layers[layer], dest, false)
    if map_resource == null:
        return
    var viewport: Vector2i = map_resource.get("viewport_size")
    if viewport.x <= 0 or viewport.y <= 0:
        return
    var ratio := dest.size / Vector2(viewport)
    if map_resource is WuxiaMapDefinition:
        var polygon_map := map_resource as WuxiaMapDefinition
        for obstacle in polygon_map.obstacles:
            if not obstacle is WuxiaMapPolygonDefinition:
                continue
            var points := PackedVector2Array()
            var polygon := obstacle as WuxiaMapPolygonDefinition
            for point in polygon.vertices:
                points.append(dest.position + point * ratio)
            if points.size() >= 3:
                draw_colored_polygon(points, Color(1, 0.15, 0.12, 0.14))
                var outline := PackedVector2Array(points)
                outline.append(points[0])
                draw_polyline(outline, Color(1, 0.35, 0.20, 0.85), 1.5)
        for marker in polygon_map.markers:
            if marker is WuxiaMapMarkerDefinition:
                var point_marker := marker as WuxiaMapMarkerDefinition
                draw_circle(dest.position + point_marker.position * ratio, 3.5, Color.YELLOW)
    elif map_resource is WuxiaGridMapDefinition:
        var grid_map := map_resource as WuxiaGridMapDefinition
        var first := grid_map.first_center
        var cell_size := grid_map.cell_size
        for y in range(grid_map.rows_count):
            for x in range(grid_map.columns):
                var center := dest.position + (first + Vector2(x, y) * cell_size) * ratio
                var rectangle := Rect2(center - cell_size * ratio * 0.5, cell_size * ratio)
                draw_rect(rectangle, Color(0.96, 0.72, 0.24, 0.30), false, 1.0)
