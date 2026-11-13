@tool
extends VBoxContainer
## Candidate-only Godot authoring tool: pose_templates JSON in, native .tscn out.
const Service = preload("res://addons/wuxia_art_importer/rig2d_pose_service.gd")
const Canvas = preload("res://addons/wuxia_art_importer/rig2d_pose_canvas.gd")

var input: LineEdit
var output: LineEdit
var actions: OptionButton
var binding_mode: CheckBox
var part_choice: OptionButton
var part_edits: Dictionary = {}
var syncing_parts := false
var timeline: HSlider
var frame_label: Label
var canvas: Control
var status: Label
var playing: Timer
var source_picker: FileDialog
var confirm: ConfirmationDialog
var rig: Dictionary = {}
var current_index := 0
var dirty := false
var last_scene := ""
var exporting := false


func _ready() -> void:
    name = "2D 骨骼"
    custom_minimum_size = Vector2(325, 420)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    var content := VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(content)
    _note(content, "2D 骨骼与拆件 · 原生编辑候选", true)
    _note(content, "选择 pose_templates 中的 project_leftarm_v6_candidate.json。拖动画面黄色的左肘/左腕控制点，逐帧预览真实贴图与 IK。")
    input = LineEdit.new()
    input.placeholder_text = "本地 pose_templates 工程 project_*.json"
    input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var input_row := HBoxContainer.new()
    input_row.add_child(input)
    _button(input_row, "浏览", func(): source_picker.popup_centered_ratio(0.7))
    content.add_child(input_row)
    _button(content, "读取部件和 12 组姿态", _load)
    actions = OptionButton.new()
    actions.item_selected.connect(func(_idx: int):
        playing.stop()
        _select_frame(0))
    content.add_child(actions)
    binding_mode = CheckBox.new()
    binding_mode.text = "编辑部件绑定（查看源图并拖动轴点）"
    binding_mode.toggled.connect(func(_enabled: bool):
        playing.stop()
        _refresh_binding())
    content.add_child(binding_mode)
    part_choice = OptionButton.new()
    part_choice.item_selected.connect(func(_idx: int): _refresh_binding())
    content.add_child(part_choice)
    canvas = Canvas.new()
    canvas.joint_dragged.connect(_edit_joint)
    canvas.binding_dragged.connect(_drag_binding)
    content.add_child(canvas)
    var part_grid := GridContainer.new()
    part_grid.columns = 2
    for field in ["pivot_x", "pivot_y", "axis_x", "axis_y", "length_px", "depth"]:
        var label := Label.new()
        label.text = field
        part_grid.add_child(label)
        var edit := SpinBox.new()
        edit.min_value = -4096 if field != "length_px" else 1
        edit.max_value = 4096
        edit.step = 0.5 if field != "depth" else 1
        edit.value_changed.connect(func(_value: float): _field_changed())
        edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        part_grid.add_child(edit)
        part_edits[field] = edit
    content.add_child(part_grid)
    var frames_row := HBoxContainer.new()
    timeline = HSlider.new()
    timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    timeline.step = 1.0
    timeline.value_changed.connect(func(value: float): _select_frame(int(value)))
    frames_row.add_child(timeline)
    frame_label = Label.new()
    frames_row.add_child(frame_label)
    content.add_child(frames_row)
    var controls := HBoxContainer.new()
    _button(controls, "◀", func(): _select_frame(current_index - 1))
    _button(controls, "播放", _play)
    _button(controls, "暂停", func(): playing.stop())
    _button(controls, "▶", func(): _select_frame(current_index + 1))
    content.add_child(controls)
    _note(content, "拖动左手腕：改变本帧 IK 目标；拖动左肘：保持两段骨长并更新腕位置。未编辑的动作保留原样。")
    _note(content, "导出为新原生 .tscn；可在 Godot 2D 编辑器选 Bone2D、在 AnimationPlayer 时间轴继续微调。不会绑定当前游戏角色。")
    output = LineEdit.new()
    output.text = "res://assets/imported/characters/gu_qingshuang/rig2d/rig_pose_candidate.tscn"
    content.add_child(output)
    _button(content, "生成原生 Skeleton2D 候选场景（需确认）", _review_export)
    _button(content, "打开刚生成的原生场景", _open_scene)
    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(status)
    source_picker = FileDialog.new()
    source_picker.access = FileDialog.ACCESS_FILESYSTEM
    source_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    source_picker.add_filter("*.json", "pose_templates 项目")
    source_picker.file_selected.connect(func(path: String): input.text = path)
    add_child(source_picker)
    confirm = ConfirmationDialog.new()
    confirm.title = "仅生成独立候选 .tscn"
    confirm.confirmed.connect(_export)
    add_child(confirm)
    playing = Timer.new()
    playing.one_shot = true
    playing.timeout.connect(_advance)
    add_child(playing)
    _refresh_controls()


func _note(parent: Control, value: String, heading: bool = false) -> void:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if heading:
        label.add_theme_font_size_override("font_size", 17)
    parent.add_child(label)


func _button(parent: Control, value: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = value
    button.pressed.connect(callback)
    parent.add_child(button)


func _action() -> String:
    return actions.get_item_text(actions.selected) if actions.selected >= 0 else ""


func _refresh_controls() -> void:
    var action := _action()
    var count := 0
    if not rig.is_empty() and not action.is_empty():
        count = rig["motions"][action]["frames"].size()
    timeline.max_value = maxi(count - 1, 0)
    timeline.editable = count > 0
    frame_label.text = (str(current_index + 1) + " / " + str(count)) if count else "0 / 0"


func _load() -> void:
    playing.stop()
    last_scene = ""
    var path := input.text.strip_edges()
    rig = Service.read_project(path)
    if not str(rig.get("error", "")) .is_empty():
        status.text = str(rig["error"])
        rig.clear()
        return
    actions.clear()
    for action in rig["project"]["actions"]:
        actions.add_item(str(action))
    actions.select(0)
    part_choice.clear()
    for part in rig["parts"]:
        part_choice.add_item(str(part))
    var left_index := -1
    for i in range(part_choice.item_count):
        if part_choice.get_item_text(i) == "left_forearm":
            left_index = i
    part_choice.select(maxi(left_index, 0))
    _refresh_binding()
    dirty = false
    _select_frame(0)
    status.text = "已加载 %d 个部件、%d 组动作。尚未修改游戏运行时 Resource。" % [
        rig["parts"].size(), actions.item_count]


func _select_frame(index: int) -> void:
    var action := _action()
    if rig.is_empty() or action.is_empty():
        return
    var frame_count: int = rig["motions"][action]["frames"].size()
    current_index = clampi(index, 0, frame_count - 1)
    timeline.set_value_no_signal(current_index)
    _refresh_controls()
    canvas.set_pose(rig, action, current_index)


func _selected_part() -> String:
    return part_choice.get_item_text(part_choice.selected) if part_choice.selected >= 0 else ""


func _refresh_binding() -> void:
    if rig.is_empty() or _selected_part().is_empty():
        return
    syncing_parts = true
    var part: Dictionary = rig["parts"][_selected_part()]
    var values := {"pivot_x": float(part["pivot"][0]), "pivot_y": float(part["pivot"][1]),
        "axis_x": float(part["axis"][0]), "axis_y": float(part["axis"][1]),
        "length_px": float(part["length_px"]), "depth": float(part["depth"])}
    for field in values:
        (part_edits[field] as SpinBox).set_value_no_signal(values[field])
    syncing_parts = false
    canvas.set_binding_part(_selected_part() if binding_mode.button_pressed else "")


func _field_changed() -> void:
    if syncing_parts or rig.is_empty() or _selected_part().is_empty():
        return
    var part: Dictionary = rig["parts"][_selected_part()]
    var pivot := Vector2(part_edits["pivot_x"].value, part_edits["pivot_y"].value)
    var axis := Vector2(part_edits["axis_x"].value, part_edits["axis_y"].value)
    if pivot.distance_to(axis) < 1.0:
        status.text = "旋转原点和骨段末端不能重合"
        return
    part["pivot"] = [pivot.x, pivot.y]
    part["axis"] = [axis.x, axis.y]
    part["length_px"] = part_edits["length_px"].value
    part["depth"] = int(part_edits["depth"].value)
    dirty = true
    canvas.queue_redraw()
    status.text = _selected_part() + " 绑定已调整（候选，尚未保存）"


func _drag_binding(field: String, source_pixel: Vector2) -> void:
    if rig.is_empty():
        return
    var part: Dictionary = rig["parts"][_selected_part()]
    var texture: Texture2D = rig["textures"][str(part["texture"])]
    source_pixel = source_pixel.clamp(Vector2.ZERO, texture.get_size())
    if source_pixel.distance_to(Service.vec(part["axis" if field == "pivot" else "pivot"])) < 1.0:
        return
    part[field] = [snappedf(source_pixel.x, 0.5), snappedf(source_pixel.y, 0.5)]
    dirty = true
    _refresh_binding()
    status.text = _selected_part() + " 的 " + field + " 已拖动（尚未保存）"


func _edit_joint(name: String, point: Vector2) -> void:
    if rig.is_empty():
        return
    Service.update_left_joint(rig, _action(), current_index, name, point)
    dirty = true
    canvas.queue_redraw()
    status.text = "%s 第 %d 帧：%s 已改变（仅内存候选，尚未保存）" % [
        _action(), current_index + 1, name]


func _play() -> void:
    if rig.is_empty():
        return
    playing.stop()
    _schedule()


func _schedule() -> void:
    var frame: Dictionary = rig["motions"][_action()]["frames"][current_index]
    playing.start(maxf(0.02, float(frame["duration_ms"]) / 1000.0))


func _advance() -> void:
    var motion: Dictionary = rig["motions"][_action()]
    if current_index == motion["frames"].size() - 1 and not bool(motion.get("loop", false)):
        return
    _select_frame((current_index + 1) % motion["frames"].size())
    _schedule()


func _review_export() -> void:
    if exporting:
        return
    if rig.is_empty():
        status.text = "请先读取骨骼工程"
        return
    var target := output.text.strip_edges()
    if not target.begins_with("res://") or not target.ends_with(".tscn"):
        status.text = "请填写新的 res://... .tscn 目标路径"
        return
    if FileAccess.file_exists(target):
        status.text = "目标已存在。请另取文件名；不会覆盖 Godot 中已有的人工编辑。"
        return
    confirm.dialog_text = "源：%s\n候选场景：%s\n动作：%d 组\n保留现有角色 SpriteFrames 和 Manifest，不自动替换。" % [
        input.text, target, actions.item_count]
    confirm.popup_centered_ratio(0.65)


func _export() -> void:
    if exporting:
        return
    exporting = true
    playing.stop()
    var saved: Dictionary = Service.save_native_candidate(rig, output.text.strip_edges())
    if bool(saved.get("pending_import", false)):
        # A first-time import copies the real source PNGs into res://. Godot must
        # index these files before ResourceLoader can reference them in a scene.
        status.text = "正在导入首次复制的拆件 PNG，请稍候…"
        EditorInterface.get_resource_filesystem().scan()
        for attempt in range(30):
            await get_tree().create_timer(0.25).timeout
            saved = Service.save_native_candidate(rig, output.text.strip_edges())
            if not bool(saved.get("pending_import", false)):
                break
    exporting = false
    if not str(saved.get("error", "")).is_empty():
        status.text = str(saved["error"])
        return
    last_scene = str(saved["scene"])
    dirty = false
    EditorInterface.get_resource_filesystem().scan()
    status.text = "已生成候选场景：%s（%d 组动作 / %d 张 PNG）。可打开并继续编辑，未绑定正式角色。" % [
        last_scene, int(saved["actions"]), int(saved["textures"])]


func _open_scene() -> void:
    if last_scene.is_empty():
        status.text = "当前没有本次生成的候选场景"
        return
    EditorInterface.open_scene_from_path(last_scene)
