@tool
extends VBoxContainer
## One guided path for GIFs, mixed sprite sheets and individual source frames.
const Service = preload("res://addons/wuxia_art_importer/frame_workbench_service.gd")
const Canvas = preload("res://addons/wuxia_art_importer/frame_workbench_canvas.gd")
const Transaction = preload("res://addons/wuxia_art_importer/art_transaction_service.gd")

var actor_choice: OptionButton
var action_choice: OptionButton
var source_path: LineEdit
var source_canvas: Control
var output_canvas: Control
var frame_list: ItemList
var status: Label
var tall: CheckBox
var grid_columns: SpinBox
var grid_rows: SpinBox
var edits: Dictionary = {}
var clean_enabled: CheckBox
var edit_tool: OptionButton
var fps: SpinBox
var looping: CheckBox
var file_picker: FileDialog
var confirmation: ConfirmationDialog
var play_timer: Timer
var frames: Array[Dictionary] = []
var current_image: Image
var current_source := ""
var current_index := -1
var add_on_crop := false
var pending: Dictionary = {}
var journal := ""
var busy := false
var syncing := false


func _ready() -> void:
    name = "角色动画 V3"
    custom_minimum_size = Vector2(330, 430)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    var content := VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(content)
    _heading(content, "角色动画逐帧工作台")
    _note(content, "选择角色、动作和原图 → 框选/修图 → 检查成品 → 导入。原图和候选保留。")
    actor_choice = OptionButton.new()
    _labeled(content, "角色", actor_choice)
    _load_actors()
    actor_choice.item_selected.connect(func(_index: int): _reset_for_target())
    action_choice = OptionButton.new()
    for action in Service.ACTIONS:
        action_choice.add_item(action)
    _labeled(content, "目标动作（每次可只导入这一组）", action_choice)
    action_choice.item_selected.connect(func(_index: int):
        _reset_for_target()
        looping.button_pressed = _action() in ["idle", "walk", "run"])
    source_path = LineEdit.new()
    source_path.placeholder_text = "选择任意尺寸 GIF / PNG / WebP / JPG"
    var file_row := HBoxContainer.new()
    source_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    file_row.add_child(source_path)
    var browse := Button.new()
    browse.text = "选择"
    browse.pressed.connect(func(): file_picker.popup_centered_ratio(0.75))
    file_row.add_child(browse)
    _labeled(content, "源图", file_row)
    _button(content, "载入并自动登记候选（GIF 自动拆帧）", _load_source)
    _heading(content, "1. 切割动作帧")
    var grid_row := HBoxContainer.new()
    grid_columns = _spin(grid_row, "列", 1, 1, 64)
    grid_rows = _spin(grid_row, "行", 1, 1, 64)
    content.add_child(grid_row)
    _button(content, "按当前网格切割并追加帧", _add_grid_frames)
    _button(content, "框选新帧（随后在原图上拖框）", func():
        add_on_crop = true
        source_canvas.tool = "crop"
        edit_tool.select(0)
        status.text = "请在原图中框选一个完整的动作姿势。")
    edit_tool = OptionButton.new()
    for label in ["矩形框选", "多边形保留轮廓（右键闭合）", "选择脚点", "擦除画笔", "恢复画笔"]:
        edit_tool.add_item(label)
    edit_tool.item_selected.connect(func(index: int):
        source_canvas.tool = ["crop", "polygon", "foot", "erase", "restore"][index])
    _labeled(content, "原图工具（滚轮放大、中键平移）", edit_tool)
    source_canvas = Canvas.new()
    content.add_child(source_canvas)
    source_canvas.crop_selected.connect(_crop_selected)
    source_canvas.polygon_selected.connect(_polygon_selected)
    source_canvas.foot_selected.connect(_foot_selected)
    source_canvas.brush_drawn.connect(_brush_drawn)
    var brush_size := _spin(content, "画笔半径（源像素）", 8, 1, 64)
    brush_size.value_changed.connect(func(value: float): source_canvas.brush_radius = int(value))
    _heading(content, "2. 逐帧修图与自由组合")
    frame_list = ItemList.new()
    frame_list.custom_minimum_size.y = 115
    frame_list.max_columns = 4
    frame_list.item_selected.connect(_select_frame)
    content.add_child(frame_list)
    var order_row := HBoxContainer.new()
    for entry in [["上移", -1], ["下移", 1]]:
        var direction := int(entry[1])
        _button(order_row, str(entry[0]), func(): _move_frame(direction))
    _button(order_row, "删除帧", _remove_frame)
    content.add_child(order_row)
    clean_enabled = CheckBox.new()
    clean_enabled.text = "启用自动背景/Alpha 杂点清理"
    clean_enabled.button_pressed = true
    clean_enabled.toggled.connect(func(_enabled: bool): _edit_changed())
    content.add_child(clean_enabled)
    edits["scale"] = _spin(content, "当前帧等比倍率", 1.0, 0.01, 8.0, 0.01)
    edits["offset_x"] = _spin(content, "当前帧水平偏移", 0, -4096, 4096)
    edits["offset_y"] = _spin(content, "当前帧垂直偏移", 0, -4096, 4096)
    edits["duration_ms"] = _spin(content, "当前帧时长（毫秒）", 100, 1, 10000)
    edits["alpha_cutoff"] = _spin(content, "半透明噪点阈值", 0.07, 0, 0.95, 0.01)
    edits["bg_tolerance"] = _spin(content, "背景色清除容差", 0.12, 0, 0.5, 0.01)
    edits["min_island_area"] = _spin(content, "独立杂点最小面积（0 不过滤）", 8, 0, 200)
    for field in edits.values():
        (field as SpinBox).value_changed.connect(func(_value: float): _edit_changed())
    var tools_row := HBoxContainer.new()
    _button(tools_row, "自动统一缩放", _fit_all)
    _button(tools_row, "清除本帧蒙版", _clear_mask)
    content.add_child(tools_row)
    tall = CheckBox.new()
    tall.text = "高个档 384×288（默认 328×256）"
    tall.toggled.connect(func(_enabled: bool):
        _invalidate()
        _refresh_output())
    content.add_child(tall)
    _note(content, "在下面画布直接拖动人物；鼠标滚轮缩放；方向键移动 1px。橙色十字为统一地面原点。")
    output_canvas = Canvas.new()
    content.add_child(output_canvas)
    output_canvas.offset_dragged.connect(_drag_output)
    output_canvas.scale_stepped.connect(_scale_output)
    _heading(content, "3. 动画预览和导入")
    fps = _spin(content, "动作 FPS", 12, 1, 60, 0.5)
    fps.value_changed.connect(func(_value: float): _invalidate())
    looping = CheckBox.new()
    looping.text = "循环播放"
    looping.button_pressed = true
    looping.toggled.connect(func(_enabled: bool): _invalidate())
    content.add_child(looping)
    var play_row := HBoxContainer.new()
    _button(play_row, "播放", _play)
    _button(play_row, "暂停", func(): play_timer.stop())
    _button(play_row, "上一帧", func(): _step(-1))
    _button(play_row, "下一帧", func(): _step(1))
    content.add_child(play_row)
    _button(content, "检查标准化成品", _review)
    _button(content, "导入并绑定当前动作（保留其他动作）", _confirm_apply)
    _button(content, "撤销本次绑定", _undo)
    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(status)
    file_picker = FileDialog.new()
    file_picker.access = FileDialog.ACCESS_FILESYSTEM
    file_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    file_picker.add_filter("*.gif,*.png,*.webp,*.jpg,*.jpeg", "动作 GIF / 精灵图")
    file_picker.file_selected.connect(func(path: String): source_path.text = path)
    add_child(file_picker)
    confirmation = ConfirmationDialog.new()
    confirmation.title = "确认更新正式角色动作"
    confirmation.confirmed.connect(_apply)
    add_child(confirmation)
    play_timer = Timer.new()
    play_timer.one_shot = true
    play_timer.timeout.connect(func():
        if frames.is_empty():
            return
        if current_index == frames.size() - 1 and not looping.button_pressed:
            return
        _step(1)
        _schedule_next())
    add_child(play_timer)


func _heading(parent: Control, value: String) -> void:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", 17)
    parent.add_child(label)


func _note(parent: Control, value: String) -> void:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(label)


func _labeled(parent: Control, caption: String, child: Control) -> void:
    _note(parent, caption)
    parent.add_child(child)


func _button(parent: Control, caption: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = caption
    button.pressed.connect(callback)
    parent.add_child(button)


func _spin(parent: Control, caption: String, value: float, minimum: float,
        maximum: float, step: float = 1.0) -> SpinBox:
    var edit := SpinBox.new()
    edit.min_value = minimum
    edit.max_value = maximum
    edit.step = step
    edit.value = value
    _labeled(parent, caption, edit)
    return edit


func _load_actors() -> void:
    actor_choice.clear()
    var root := "res://data/native/characters"
    var dir := DirAccess.open(root)
    if dir == null:
        return
    for filename in dir.get_files():
        if not filename.ends_with(".tres"):
            continue
        var path := root.path_join(filename)
        var actor := ResourceLoader.load(path) as WuxiaCharacterDefinition
        if actor != null and not actor.content_id.is_empty():
            actor_choice.add_item(actor.content_id)
            actor_choice.set_item_metadata(actor_choice.item_count - 1, path)


func _target() -> String:
    return str(actor_choice.get_item_metadata(actor_choice.selected)) if actor_choice.selected >= 0 else ""


func _actor_id() -> String:
    return actor_choice.get_item_text(actor_choice.selected) if actor_choice.selected >= 0 else ""


func _action() -> String:
    return action_choice.get_item_text(action_choice.selected) if action_choice.selected >= 0 else "idle"


func _cell() -> Vector2i:
    return Vector2i(384, 288) if tall.button_pressed else Vector2i(328, 256)


func _invalidate() -> void:
    pending.clear()


func _reset_for_target() -> void:
    # Editing frames for actor A must never leak into actor B, or another action.
    # An old preflight and its approval also cannot survive a target switch.
    play_timer.stop()
    frames.clear()
    current_index = -1
    current_image = null
    current_source = ""
    add_on_crop = false
    frame_list.clear()
    source_canvas.set_picture(null, true)
    output_canvas.set_picture(null, false)
    _invalidate()
    status.text = "已切换目标。请载入此角色/动作的 GIF 或精灵图。"


func _load_source() -> void:
    if _actor_id().is_empty():
        status.text = "请先选择角色"
        return
    var source := source_path.text.strip_edges()
    var loaded := Service.load_source(source)
    if not str(loaded.get("error", "")).is_empty():
        status.text = str(loaded["error"])
        return
    var dimensions: Variant = loaded["size"]
    var size_value := Vector2i(int(dimensions[0]), int(dimensions[1])) if dimensions is Array else Vector2i(dimensions)
    var staged := Service.stage_candidate(source, _actor_id(), _action(), size_value)
    if not str(staged.get("error", "")).is_empty():
        status.text = str(staged["error"])
        return
    current_source = str(staged["path"])
    current_image = loaded["frames"][0]["image"]
    source_canvas.set_picture(ImageTexture.create_from_image(current_image), true)
    if source.get_extension().to_lower() == "gif":
        for item in loaded["frames"]:
            _append(item["image"], Rect2i(Vector2i.ZERO, (item["image"] as Image).get_size()),
                int(item["duration_ms"]), current_source)
        _fit_all()
        status.text = "已拆解 %d 帧 GIF；可逐帧调整后导入。" % loaded["frames"].size()
    else:
        var size := current_image.get_size()
        grid_columns.value = 5 if size.x > 800 and size.y > 600 else 1
        grid_rows.value = 5 if size.x > 800 and size.y > 600 else 1
        status.text = "已归档原图。请直接框选帧，或按网格切割，之后可继续添加其他来源。"
    _invalidate()


func _new_frame(image: Image, region: Rect2i, ms: int, source: String) -> Dictionary:
    return {"image": image, "rect": region, "duration_ms": ms, "source": source,
        "offset": Vector2.ZERO, "scale": 1.0, "cleanup": true,
        "alpha_cutoff": 0.07, "bg_tolerance": 0.12, "min_island_area": 8,
        "polygon": PackedVector2Array(), "strokes": []}


func _append(image: Image, region: Rect2i, ms: int, source: String) -> void:
    if frames.size() >= 256:
        status.text = "单动作最多 256 帧"
        return
    frames.append(_new_frame(image, region, ms, source))
    _refresh_list()
    _select_frame(frames.size() - 1)


func _add_grid_frames() -> void:
    if current_image == null:
        status.text = "请先载入精灵图"
        return
    var columns := int(grid_columns.value)
    var rows := int(grid_rows.value)
    if columns * rows + frames.size() > 256:
        status.text = "当前动作超过 256 帧"
        return
    var size := current_image.get_size()
    for y in range(rows):
        for x in range(columns):
            var start := Vector2i(roundi(float(x) * size.x / columns),
                roundi(float(y) * size.y / rows))
            var end := Vector2i(roundi(float(x + 1) * size.x / columns),
                roundi(float(y + 1) * size.y / rows))
            _append(current_image, Rect2i(start, end - start), 100, current_source)
    _fit_all()
    status.text = "已添加 %d 个格位；可删除空帧并逐帧调整裁切框。" % (columns * rows)


func _crop_selected(region: Rect2i) -> void:
    if current_image == null:
        return
    if add_on_crop or current_index < 0:
        _append(current_image, region, 100, current_source)
        add_on_crop = false
    else:
        var current := frames[current_index]
        current["rect"] = region
        current["polygon"] = PackedVector2Array()
        current["strokes"] = []
        _save_current(current)


func _polygon_selected(points: PackedVector2Array) -> void:
    if current_index < 0:
        return
    var current := frames[current_index]
    for point in points:
        if not Rect2(current["rect"]).has_point(point):
            status.text = "轮廓点超出了当前裁切区域；请先扩大裁切框"
            return
    current["polygon"] = points
    _save_current(current)


func _foot_selected(point: Vector2) -> void:
    if current_index < 0:
        return
    var current := frames[current_index]
    if not Rect2(current["rect"]).has_point(point):
        status.text = "脚点必须位于当前帧裁切框内"
        return
    current["anchor"] = point
    _save_current(current)


func _brush_drawn(points: PackedVector2Array, restore: bool) -> void:
    if current_index < 0 or points.is_empty():
        return
    var current := frames[current_index]
    var strokes: Array = current.get("strokes", [])
    strokes.append({"points": points, "radius": source_canvas.brush_radius,
        "restore": restore})
    current["strokes"] = strokes
    _save_current(current)


func _refresh_list() -> void:
    frame_list.clear()
    for i in range(frames.size()):
        frame_list.add_item("%d" % (i + 1))
        var frame := frames[i]
        var source: Image = frame["image"]
        var rect: Rect2i = frame["rect"]
        if rect.has_area() and Rect2i(Vector2i.ZERO, source.get_size()).encloses(rect):
            var thumbnail := source.get_region(rect)
            thumbnail.resize(40, 40, Image.INTERPOLATE_LANCZOS)
            frame_list.set_item_icon(i, ImageTexture.create_from_image(thumbnail))


func _select_frame(index: int) -> void:
    if index < 0 or index >= frames.size():
        return
    current_index = index
    frame_list.select(index)
    var frame := frames[index]
    current_image = frame["image"]
    current_source = str(frame["source"])
    source_canvas.set_picture(ImageTexture.create_from_image(current_image), true,
        frame["rect"], frame.get("polygon", PackedVector2Array()))
    syncing = true
    edits["scale"].value = float(frame.get("scale", 1.0))
    var offset: Vector2 = frame.get("offset", Vector2.ZERO)
    edits["offset_x"].value = offset.x
    edits["offset_y"].value = offset.y
    edits["duration_ms"].value = int(frame.get("duration_ms", 100))
    edits["alpha_cutoff"].value = float(frame.get("alpha_cutoff", 0.07))
    edits["bg_tolerance"].value = float(frame.get("bg_tolerance", 0.12))
    edits["min_island_area"].value = int(frame.get("min_island_area", 8))
    clean_enabled.button_pressed = bool(frame.get("cleanup", true))
    syncing = false
    _refresh_output()


func _edit_changed() -> void:
    if syncing or current_index < 0:
        return
    var frame := frames[current_index]
    frame["scale"] = edits["scale"].value
    frame["offset"] = Vector2(edits["offset_x"].value, edits["offset_y"].value)
    frame["duration_ms"] = int(edits["duration_ms"].value)
    frame["alpha_cutoff"] = edits["alpha_cutoff"].value
    frame["bg_tolerance"] = edits["bg_tolerance"].value
    frame["min_island_area"] = int(edits["min_island_area"].value)
    frame["cleanup"] = clean_enabled.button_pressed
    _save_current(frame)


func _save_current(frame: Dictionary) -> void:
    if current_index < 0:
        return
    frames[current_index] = frame
    _invalidate()
    _refresh_output()


func _refresh_output() -> void:
    if output_canvas == null or current_index < 0 or current_index >= frames.size():
        return
    var frame := frames[current_index]
    var preview := Service.render_frame(frame, _cell(), false)
    if str(preview.get("error", "")).is_empty():
        output_canvas.set_picture(ImageTexture.create_from_image(preview["image"]), false)
        var strict := Service.render_frame(frame, _cell())
        if not str(strict.get("error", "")).is_empty():
            status.text = "第 %d 帧需调整：%s" % [current_index + 1, strict["error"]]
    else:
        status.text = str(preview["error"])


func _drag_output(delta: Vector2) -> void:
    if current_index < 0:
        return
    var current := frames[current_index]
    current["offset"] = Vector2(current.get("offset", Vector2.ZERO)) + delta
    _save_current(current)
    _select_frame(current_index)


func _scale_output(factor: float) -> void:
    if current_index < 0:
        return
    var current := frames[current_index]
    current["scale"] = clampf(float(current["scale"]) * factor, 0.01, 8.0)
    _save_current(current)
    _select_frame(current_index)


func _fit_all() -> void:
    if frames.is_empty():
        return
    # One proportional factor for this action; never normalize each attack pose's
    # changing silhouette independently (which would make character size jitter).
    var maximum := Vector2i.ONE
    for frame in frames:
        var result := Service.crop_frame(frame)
        if str(result.get("error", "")).is_empty():
            var image: Image = result["image"]
            maximum = maximum.max(image.get_used_rect().size)
    var cell := _cell()
    var scale := minf(float(cell.x - 32) / maximum.x,
        float(cell.y - 32) / maximum.y)
    for i in range(frames.size()):
        frames[i]["scale"] = minf(scale, 8.0)
        frames[i]["offset"] = Vector2.ZERO
    _invalidate()
    if current_index >= 0:
        _select_frame(current_index)


func _clear_mask() -> void:
    if current_index < 0:
        return
    frames[current_index]["polygon"] = PackedVector2Array()
    frames[current_index]["strokes"] = []
    _select_frame(current_index)
    _invalidate()


func _move_frame(direction: int) -> void:
    var destination := current_index + direction
    if current_index < 0 or destination < 0 or destination >= frames.size():
        return
    var item := frames[current_index]
    frames[current_index] = frames[destination]
    frames[destination] = item
    _refresh_list()
    _select_frame(destination)
    _invalidate()


func _remove_frame() -> void:
    if current_index < 0:
        return
    frames.remove_at(current_index)
    current_index = mini(current_index, frames.size() - 1)
    _refresh_list()
    if current_index >= 0:
        _select_frame(current_index)
    else:
        output_canvas.set_picture(null, false)
    _invalidate()


func _step(direction: int) -> void:
    if frames.is_empty():
        return
    _select_frame(posmod(current_index + direction, frames.size()))


func _schedule_next() -> void:
    if current_index < 0:
        return
    play_timer.start(maxf(0.001, float(frames[current_index].get("duration_ms", 100)) / 1000.0))


func _play() -> void:
    if frames.is_empty():
        return
    if current_index < 0:
        _select_frame(0)
    _schedule_next()


func _review() -> void:
    if busy:
        return
    var built := Service.build(frames, _cell(), _action(), fps.value, looping.button_pressed)
    if not str(built.get("error", "")).is_empty():
        status.text = "成品未通过：" + str(built["error"])
        pending.clear()
        return
    pending = Service.prepare(_target(), built)
    if not str(pending.get("error", "")).is_empty():
        status.text = "绑定预检失败：" + str(pending["error"])
        pending.clear()
        return
    var lines: Array[String] = []
    for notice in pending.get("notices", []):
        lines.append("• " + str(notice))
    status.text = "%s · %d 帧 · %s\n本次将自动创建/更新：\n%s\n确认后导入，动画画面可随后检查。" % [
        _action(), frames.size(), str(_cell()), "\n".join(lines)]


func _confirm_apply() -> void:
    if pending.is_empty():
        status.text = "请先检查标准化成品"
        return
    var changes: Array[String] = []
    for notice in pending.get("notices", []):
        changes.append("• " + str(notice))
    confirmation.dialog_text = "确认导入 %s 的 %s 动作？\n%s\n仅更新所选角色，保留其他动作；可撤销。" % [
        _actor_id(), _action(), "\n".join(changes)]
    confirmation.popup_centered_ratio(0.7)


func _apply() -> void:
    if pending.is_empty() or busy:
        return
    busy = true
    var result := Service.apply(pending)
    busy = false
    if not str(result.get("error", "")).is_empty():
        status.text = "导入失败：" + str(result["error"])
        return
    journal = str(result["journal"])
    status.text = "导入完成，依赖已自动创建/更新。\nSpriteFrames：" + \
        str(result["frames_path"]) + "\n请在 Godot 中查看动画效果。"
    _invalidate()


func _undo() -> void:
    if journal.is_empty():
        status.text = "当前没有可撤销的导入事务"
        return
    var problem: String = Transaction.rollback(journal)
    status.text = "已恢复之前的 Resource" if problem.is_empty() else problem
    if problem.is_empty():
        journal = ""
