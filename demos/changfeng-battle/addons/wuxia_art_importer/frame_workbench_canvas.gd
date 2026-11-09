@tool
extends Control
## Two views of one frame: source selection and normalized-output dragging.
signal crop_selected(region: Rect2i)
signal polygon_selected(points: PackedVector2Array)
signal foot_selected(point: Vector2)
signal offset_dragged(delta: Vector2)
signal scale_stepped(factor: float)
signal brush_drawn(points: PackedVector2Array, restore: bool)

var picture: Texture2D
var source_view := true
var tool := "crop"
var brush_radius := 8
var crop := Rect2i()
var polygon := PackedVector2Array()
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false
var middle_panning := false
var drag_start := Vector2.ZERO
var drag_end := Vector2.ZERO
var trace := PackedVector2Array()


func _ready() -> void:
    custom_minimum_size = Vector2(0, 240)
    mouse_filter = Control.MOUSE_FILTER_STOP
    focus_mode = Control.FOCUS_ALL


func set_picture(texture: Texture2D, is_source: bool, region: Rect2i = Rect2i(),
        outline: PackedVector2Array = PackedVector2Array()) -> void:
    picture = texture
    source_view = is_source
    crop = region
    polygon = outline
    queue_redraw()


func _image_box() -> Rect2:
    if picture == null:
        return Rect2()
    var available := size - Vector2(12, 12)
    var native := Vector2(picture.get_size())
    var factor := minf(available.x / native.x, available.y / native.y) * zoom
    var extent := native * factor
    return Rect2((size - extent) * 0.5 + pan, extent)


func _pixel(screen_point: Vector2) -> Vector2:
    var box := _image_box()
    if box.size.x <= 0.0 or box.size.y <= 0.0:
        return Vector2.ZERO
    return (screen_point - box.position) * Vector2(picture.get_size()) / box.size


func _screen(pixel: Vector2) -> Vector2:
    var box := _image_box()
    return box.position + pixel * box.size / Vector2(picture.get_size())


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.15, 0.17))
    if picture == null:
        draw_string(ThemeDB.fallback_font, Vector2(12, 34), "选择素材后在这里框选动作帧")
        return
    var box := _image_box()
    # Alpha checkerboard, clipped to the source image viewport.
    for y in range(0, 8):
        for x in range(0, 8):
            var tile := Rect2(box.position + Vector2(x, y) * box.size / 8.0, box.size / 8.0)
            draw_rect(tile, Color(0.29, 0.31, 0.34) if (x + y) % 2 == 0 else Color(0.23, 0.25, 0.28))
    draw_texture_rect(picture, box, false)
    draw_rect(box, Color(0.7, 0.75, 0.8, 0.45), false, 1)
    if not source_view:
        draw_line(_screen(Vector2(picture.get_width() * 0.5, picture.get_height() - 16)) - Vector2(9, 0),
            _screen(Vector2(picture.get_width() * 0.5, picture.get_height() - 16)) + Vector2(9, 0), Color.ORANGE, 2)
        return
    if crop.has_area():
        draw_rect(Rect2(_screen(Vector2(crop.position)),
            _screen(Vector2(crop.end)) - _screen(Vector2(crop.position))), Color.ORANGE, false, 2)
    if polygon.size() >= 2:
        for i in range(polygon.size()):
            draw_line(_screen(polygon[i]), _screen(polygon[(i + 1) % polygon.size()]),
                Color(0.25, 0.95, 0.7), 2)
    if dragging and tool == "crop":
        var a := drag_start.min(drag_end)
        var b := drag_start.max(drag_end)
        draw_rect(Rect2(a, b - a), Color(0.1, 0.8, 1.0), false, 2)
    if trace.size() >= 2:
        for i in range(trace.size() - 1):
            draw_line(_screen(trace[i]), _screen(trace[i + 1]),
                Color(1.0, 0.4, 0.3) if tool == "erase" else Color.CYAN, 2)


func _gui_input(event: InputEvent) -> void:
    if picture == null:
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
        middle_panning = event.pressed
        accept_event()
        return
    if event is InputEventMouseMotion and middle_panning:
        pan += event.relative
        queue_redraw()
        accept_event()
        return
    if event is InputEventMouseButton and event.pressed and event.button_index in [
            MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
        if source_view:
            zoom = clampf(zoom * (1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8), 1.0, 8.0)
            queue_redraw()
        else:
            scale_stepped.emit(1.05 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.05)
        accept_event()
        return
    if event is InputEventKey and not source_view and event.pressed:
        var delta := Vector2.ZERO
        match event.keycode:
            KEY_LEFT: delta = Vector2.LEFT
            KEY_RIGHT: delta = Vector2.RIGHT
            KEY_UP: delta = Vector2.UP
            KEY_DOWN: delta = Vector2.DOWN
        if delta != Vector2.ZERO:
            offset_dragged.emit(delta)
            accept_event()
        return
    if not event is InputEventMouseButton and not event is InputEventMouseMotion:
        return
    if source_view and tool == "polygon" and event is InputEventMouseButton \
            and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
        if trace.size() >= 3:
            polygon_selected.emit(trace.duplicate())
        trace.clear()
        queue_redraw()
        accept_event()
        return
    if event is InputEventMouseMotion and dragging:
        if not source_view:
            var transform := Vector2(picture.get_size()) / _image_box().size
            offset_dragged.emit(event.relative * transform)
        elif tool == "crop":
            drag_end = event.position
            queue_redraw()
        elif tool in ["erase", "restore"]:
            trace.append(_pixel(event.position))
            queue_redraw()
        accept_event()
        return
    if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
        return
    if event.pressed:
        grab_focus()
        if not _image_box().has_point(event.position):
            return
        if source_view and tool == "foot":
            foot_selected.emit(_pixel(event.position))
        elif source_view and tool == "polygon":
            trace.append(_pixel(event.position))
            if event.double_click and trace.size() >= 3:
                polygon_selected.emit(trace.duplicate())
                trace.clear()
            queue_redraw()
        else:
            dragging = true
            drag_start = event.position
            drag_end = drag_start
            if source_view and tool in ["erase", "restore"]:
                trace.clear()
                trace.append(_pixel(event.position))
        accept_event()
        return
    if not dragging:
        return
    dragging = false
    if source_view and tool == "crop":
        var start := _pixel(drag_start).min(_pixel(event.position))
        var stop := _pixel(drag_start).max(_pixel(event.position))
        var rectangle := Rect2i(Vector2i(start.floor()), Vector2i(stop.ceil()) - Vector2i(start.floor()))
        rectangle = rectangle.intersection(Rect2i(Vector2i.ZERO, picture.get_size()))
        if rectangle.has_area():
            crop_selected.emit(rectangle)
    elif source_view and tool in ["erase", "restore"]:
        trace.append(_pixel(event.position))
        brush_drawn.emit(trace.duplicate(), tool == "restore")
        trace.clear()
    queue_redraw()
    accept_event()
