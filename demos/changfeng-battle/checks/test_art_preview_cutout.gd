extends SceneTree
## Synthetic editor-pointer input checks for crop, polygon and freehand lasso.
const Preview = preload("res://addons/wuxia_art_importer/art_preview.gd")

var errors: Array[String] = []


func check(condition: bool, message: String) -> void:
    if not condition:
        errors.append(message)
        push_error("ART_PREVIEW_CUTOUT: " + message)


func _initialize() -> void:
    call_deferred("_run")


func _mouse(control, position: Vector2, button: MouseButton,
        down: bool, double_click: bool = false) -> void:
    var event := InputEventMouseButton.new()
    event.position = position
    event.button_index = button
    event.pressed = down
    event.double_click = double_click
    control._gui_input(event)


func _pixel(control, value: Vector2) -> Vector2:
    var rect: Rect2 = control._grid_box()
    return rect.position + value * rect.size / control.picture.get_size()


func _run() -> void:
    var preview := Preview.new()
    preview.custom_minimum_size = Vector2(400, 400)
    preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    preview.size = Vector2(400, 400)
    root.add_child(preview)
    var source := Image.create(200, 200, false, Image.FORMAT_RGBA8)
    source.fill(Color.TRANSPARENT)
    var texture := ImageTexture.create_from_image(source)
    var grid := {"columns": 5, "rows": 5, "cell_width": 40, "cell_height": 40,
        "origin_x": 0, "origin_y": 0, "gap_x": 0, "gap_y": 0,
        "offsets": {}, "rects": {}, "masks": {}}
    var cropped: Array = []
    var traced: Array = []
    preview.crop_drawn.connect(func(index: int, rect: Rect2i):
        cropped.append({"cell": index, "rect": rect}))
    preview.mask_drawn.connect(func(index: int, outline: PackedVector2Array):
        traced.append({"cell": index, "outline": outline.duplicate()}))

    preview.show_grid(texture, grid, "crop")
    _mouse(preview, _pixel(preview, Vector2(2, 2)), MOUSE_BUTTON_LEFT, true)
    _mouse(preview, _pixel(preview, Vector2(38, 38)), MOUSE_BUTTON_LEFT, false)
    check(cropped.size() == 1 and cropped[0]["cell"] == 0 and
        cropped[0]["rect"] == Rect2i(2, 2, 36, 36),
        "dragged rectangle yields exact absolute source coordinates")

    preview.show_grid(texture, grid, "polygon")
    for point in [Vector2(9, 9), Vector2(30, 9), Vector2(30, 30), Vector2(9, 30)]:
        _mouse(preview, _pixel(preview, point), MOUSE_BUTTON_LEFT, true)
    _mouse(preview, _pixel(preview, Vector2(9, 30)), MOUSE_BUTTON_RIGHT, true)
    check(traced.size() == 1 and traced[0]["cell"] == 0 and
        traced[0]["outline"].size() == 4,
        "polygon point editor emits closed four-vertex outline")

    preview.show_grid(texture, grid, "lasso")
    preview.set_grid_zoom(3.0, 0)
    _mouse(preview, _pixel(preview, Vector2(9, 9)), MOUSE_BUTTON_LEFT, true)
    for point in [Vector2(30, 9), Vector2(30, 30), Vector2(9, 30)]:
        var event := InputEventMouseMotion.new()
        event.position = _pixel(preview, point)
        preview._gui_input(event)
    _mouse(preview, _pixel(preview, Vector2(9, 9)), MOUSE_BUTTON_LEFT, false)
    check(traced.size() == 2 and traced[1]["cell"] == 0 and
        traced[1]["outline"].size() >= 4,
        "zoomed freehand lasso records precise source-pixel outline")
    preview.queue_free()
    print("ART_PREVIEW_CUTOUT_PASS failures=", errors.size())
    quit(1 if not errors.is_empty() else 0)
