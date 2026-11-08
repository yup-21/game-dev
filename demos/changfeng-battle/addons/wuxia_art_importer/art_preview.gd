@tool
extends Control
## Lightweight editor preview. No gameplay state or Resource writes.

signal cell_clicked(index: int)
signal crop_drawn(index: int, region: Rect2i)
signal mask_drawn(index: int, outline: PackedVector2Array)
signal anchor_picked(index: int, point: Vector2)

var mode: String = "image"
var picture: Texture2D
var layers: Dictionary = {}
var columns: int = 6
var rows: int = 4
var frame: int = 0
var feet_offset: Vector2 = Vector2(0, -102)
var map_resource: Resource
var candidate_display_scale: float = 0.0
var grid_source: Dictionary = {}
var crop_rect: Rect2i = Rect2i()
var edit_mode: String = "select"
var drag_start: Vector2 = Vector2.ZERO
var drag_end: Vector2 = Vector2.ZERO
var dragging: bool = false
var trace_points := PackedVector2Array()
var trace_cell: int = -1
var grid_zoom: float = 1.0
var focus_cell: int = -1
var grid_pan := Vector2.ZERO
var panning: bool = false
const Assembly = preload("res://addons/wuxia_art_importer/sprite_assembly.gd")


func _ready() -> void:
    clip_contents = true


func set_grid_zoom(value: float, cell_index: int) -> void:
    if not is_equal_approx(grid_zoom, value) or focus_cell != cell_index:
        grid_pan = Vector2.ZERO
    grid_zoom = maxf(value, 1.0)
    focus_cell = cell_index
    queue_redraw()


func _grid_box() -> Rect2:
    if grid_zoom <= 1.0 or focus_cell < 0:
        return _fitted(picture.get_size())
    var selected: Rect2i = Assembly.cell_rect(grid_source, focus_cell)
    if not selected.has_area():
        return _fitted(picture.get_size())
    var scale := minf(size.x / float(selected.size.x),
        size.y / float(selected.size.y)) * grid_zoom
    var center := Vector2(selected.position) + Vector2(selected.size) * 0.5
    return Rect2(size * 0.5 - center * scale + grid_pan,
        picture.get_size() * scale)


func set_candidate_display_scale(value: float) -> void:
    candidate_display_scale = value if is_finite(value) and value > 0.0 else 0.0
    queue_redraw()


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


func show_grid(texture: Texture2D, source: Dictionary, selection_mode: String = "select") -> void:
    mode = "grid"
    picture = texture
    grid_source = source.duplicate(true)
    if edit_mode != selection_mode:
        trace_points.clear()
        trace_cell = -1
        dragging = false
    edit_mode = selection_mode
    layers.clear()
    queue_redraw()


func show_sliced_frame(texture: Texture2D, region: Rect2i, feet: Vector2) -> void:
    mode = "slice"
    picture = texture
    crop_rect = region
    feet_offset = feet
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
    if mode == "grid":
        var whole := _grid_box()
        draw_texture_rect(picture, whole, false)
        var factor := whole.size / picture.get_size()
        var cols := int(grid_source.get("columns", 0))
        var rows_count := int(grid_source.get("rows", 0))
        for index in range(cols * rows_count):
            var rect := Assembly.cell_rect(grid_source, index)
            var target := Rect2(whole.position + Vector2(rect.position) * factor,
                Vector2(rect.size) * factor)
            var selected := edit_mode == "anchor" and index == focus_cell
            var border := Color.ORANGE if selected else Color(0.1, 0.96, 0.68, 0.9)
            draw_rect(target, border, false, 2.0 if selected else 1.3)
            if target.size.x > 15.0 and target.size.y > 11.0:
                draw_string(get_theme_default_font(), target.position + Vector2(2, 12),
                    str(index), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.YELLOW)
            var mask: PackedVector2Array = grid_source.get("masks", {}).get(index, PackedVector2Array())
            if mask.size() >= 3:
                var screen_mask := PackedVector2Array()
                for point in mask:
                    screen_mask.append(whole.position + point * factor)
                screen_mask.append(screen_mask[0])
                draw_polyline(screen_mask, Color(1.0, 0.70, 0.12, 0.95), 2.0)
        for point in grid_source.get("anchors", {}).values():
            if point is Vector2:
                _draw_foot_marker(whole.position + point * factor)
        if dragging and edit_mode == "crop":
            var outline := Rect2(drag_start, drag_end - drag_start).abs()
            draw_rect(outline, Color(1.0, 0.66, 0.20), false, 2.0)
        if trace_points.size() >= 2:
            var screen_trace := PackedVector2Array()
            for point in trace_points:
                screen_trace.append(whole.position + point * factor)
            draw_polyline(screen_trace, Color(1.0, 0.36, 0.22), 2.0)
        return
    if mode == "slice":
        _draw_region(Rect2(crop_rect))
        return
    if mode == "atlas":
        var frame_size := Vector2(float(picture.get_width()) / float(columns),
                                  float(picture.get_height()) / float(rows))
        var cell := frame % maxi(columns * rows, 1)
        var source_rect := Rect2(Vector2(float(cell % columns), float(cell / columns)) * frame_size, frame_size)
        _draw_region(source_rect)
    else:
        draw_texture_rect(picture, _fitted(picture.get_size()), false)


func _draw_region(source_rect: Rect2) -> void:
    if not source_rect.has_area():
        return
    var dest := _fitted(source_rect.size)
    if candidate_display_scale > 0.0:
        var screen_size: Vector2 = source_rect.size * candidate_display_scale
        dest = Rect2((size - screen_size) * 0.5, screen_size)
    draw_texture_rect_region(picture, dest, source_rect)
    var marker := dest.position + dest.size * Vector2(0.5, 1.0)
    marker += feet_offset * (dest.size.x / source_rect.size.x)
    _draw_foot_marker(marker)


func _draw_foot_marker(marker: Vector2) -> void:
    draw_line(marker - Vector2(7, 0), marker + Vector2(7, 0), Color.ORANGE, 2)
    draw_line(marker - Vector2(0, 7), marker + Vector2(0, 7), Color.ORANGE, 2)


func _gui_input(event: InputEvent) -> void:
    if mode != "grid" or picture == null:
        return
    var whole := _grid_box()
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
        panning = event.pressed
        accept_event()
        return
    if event is InputEventMouseMotion and panning:
        grid_pan += event.relative
        queue_redraw()
        accept_event()
        return
    if event is InputEventMouseMotion and dragging:
        if edit_mode == "crop":
            drag_end = event.position.clamp(whole.position, whole.end)
        elif edit_mode == "lasso":
            var point := _source_point(event.position, whole)
            if trace_points.is_empty() or trace_points[-1].distance_to(point) >= 2.0:
                if trace_points.size() < 2048:
                    trace_points.append(point)
        queue_redraw()
        accept_event()
        return
    if not event is InputEventMouseButton:
        return
    if edit_mode == "polygon" and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
        _finish_trace()
        accept_event()
        return
    if event.button_index != MOUSE_BUTTON_LEFT:
        return
    if event.pressed:
        if not whole.has_point(event.position):
            return
        if edit_mode == "anchor":
            var pixel := Vector2i(_source_point(event.position, whole).floor())
            if focus_cell >= 0 and Assembly.cell_rect(grid_source, focus_cell).has_point(pixel):
                anchor_picked.emit(focus_cell, Vector2(pixel))
            accept_event()
            return
        if edit_mode == "polygon":
            var clicked_cell := _cell_at(event.position, whole)
            if clicked_cell < 0:
                return
            if trace_cell != clicked_cell:
                trace_points.clear()
                trace_cell = clicked_cell
            if trace_points.size() >= 3 and (event.double_click or \
                    _screen_distance(event.position, trace_points[0], whole) < 8.0):
                _finish_trace()
            elif trace_points.size() < 2048:
                trace_points.append(_source_point(event.position, whole))
            queue_redraw()
            accept_event()
            return
        drag_start = event.position
        drag_end = drag_start
        dragging = edit_mode in ["crop", "lasso"]
        if edit_mode == "lasso":
            trace_cell = _cell_at(drag_start, whole)
            trace_points.clear()
            if trace_cell >= 0:
                trace_points.append(_source_point(drag_start, whole))
            else:
                dragging = false
        if dragging:
            accept_event()
        else:
            _select_cell(event.position, whole)
        return
    if not dragging:
        return
    dragging = false
    if edit_mode == "lasso":
        var point := _source_point(event.position, whole)
        if trace_points.is_empty() or trace_points[-1].distance_to(point) > 0.5:
            trace_points.append(point)
        _finish_trace()
        accept_event()
        return
    drag_end = event.position.clamp(whole.position, whole.end)
    queue_redraw()
    if drag_start.distance_to(drag_end) < 5.0:
        _select_cell(drag_start, whole)
        return
    var start_px := _source_point(drag_start, whole)
    var end_px := _source_point(drag_end, whole)
    var min_point := Vector2i(Vector2(start_px.min(end_px)).floor())
    var max_point := Vector2i(Vector2(start_px.max(end_px)).ceil())
    var rect := Rect2i(min_point, max_point - min_point)
    var index := _cell_at(drag_start, whole)
    if index >= 0 and rect.has_area():
        crop_drawn.emit(index, rect)
    accept_event()


func _source_point(screen_point: Vector2, whole: Rect2) -> Vector2:
    return ((screen_point.clamp(whole.position, whole.end) - whole.position) *
        picture.get_size() / whole.size)


func _screen_distance(screen_point: Vector2, pixel: Vector2, whole: Rect2) -> float:
    return screen_point.distance_to(whole.position + pixel * whole.size / picture.get_size())


func _finish_trace() -> void:
    if trace_cell >= 0 and trace_points.size() >= 3:
        # The artist's path must fit the chosen source rectangle. Reject an
        # invalid outline at preflight, rather than silently chopping vertices.
        mask_drawn.emit(trace_cell, trace_points.duplicate())
    trace_points.clear()
    trace_cell = -1
    queue_redraw()


func _cell_at(screen_point: Vector2, whole: Rect2) -> int:
    var pixel := Vector2i((screen_point - whole.position) * picture.get_size() / whole.size)
    for index in range(int(grid_source["columns"]) * int(grid_source["rows"])):
        if Assembly.cell_rect(grid_source, index).has_point(pixel):
            return index
    return -1


func _select_cell(screen_point: Vector2, whole: Rect2) -> void:
    var index := _cell_at(screen_point, whole)
    if index >= 0:
        cell_clicked.emit(index)
        accept_event()


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
    var chapter_scene: WuxiaChapterSceneDefinition = null
    if map_resource is WuxiaChapterDefinition:
        chapter_scene = map_resource.get("scene") as WuxiaChapterSceneDefinition
    var viewport: Vector2i = Vector2i(1600, 1000) if chapter_scene != null else map_resource.get("viewport_size")
    if viewport.x <= 0 or viewport.y <= 0:
        return
    var ratio := dest.size / Vector2(viewport)
    if chapter_scene != null:
        draw_circle(dest.position + chapter_scene.player_position * ratio, 4.0, Color(0.24, 0.96, 0.65))
        var npcs: Array[Resource] = [chapter_scene.primary_npc]
        npcs.append_array(chapter_scene.npcs)
        for npc in npcs:
            if npc is WuxiaChapterNpcDefinition:
                draw_circle(dest.position + npc.position * ratio, 4.0, Color.ORANGE)
    elif map_resource is WuxiaMapDefinition:
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
