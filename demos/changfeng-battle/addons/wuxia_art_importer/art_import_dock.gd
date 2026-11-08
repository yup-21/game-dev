@tool
extends ScrollContainer
## Godot editor dock: visual preflight, preview, explicit confirmation, then .tres binding.

const Service = preload("res://addons/wuxia_art_importer/art_import_service.gd")
const Preview = preload("res://addons/wuxia_art_importer/art_preview.gd")
const Export = preload("res://addons/wuxia_art_importer/art_export_service.gd")
const Transaction = preload("res://addons/wuxia_art_importer/art_transaction_service.gd")
const Assembly = preload("res://addons/wuxia_art_importer/sprite_assembly.gd")
const LABELS := ["角色立绘", "角色动作 Atlas", "分层场景", "UI Atlas", "战斗 VFX", "整个角色目录"]
const MODES := ["portrait", "atlas", "scene", "ui_atlas", "vfx", "character_folder"]

var body: VBoxContainer
var source_list: ItemList
var search: LineEdit
var kind: OptionButton
var targets: OptionButton
var target_row: Control
var id_row: Control
var asset_id: LineEdit
var event_row: Control
var event_kind: LineEdit
var native_scene: LineEdit
var native_scene_row: Control
var extra_rows: Dictionary = {}
var extras: Dictionary = {}
var columns: SpinBox
var rows: SpinBox
var feet_x: SpinBox
var feet_y: SpinBox
var facing: CheckBox
var clip_profile: LineEdit
var legacy_reuse: CheckBox
var atlas_rows: Array[Control] = []
var vfx_controls: Array[Control] = []
var vfx_columns: SpinBox
var vfx_row_count: SpinBox
var vfx_frame_indices: LineEdit
var action_select: OptionButton
var compose_enabled: CheckBox
var compose_panel: VBoxContainer
var compose_source_list: ItemList
var compose_grid: CheckBox
var compose_preview: Control
var compose_status: Label
var compose_playing: bool = false
var compose_tall: CheckBox
var compose_native: CheckBox
var compose_selection_mode: OptionButton
var compose_zoom: SpinBox
var compose_numbers: Dictionary = {}
var compose_mapping: LineEdit
var compose_loop: CheckBox
var compose_fps: SpinBox
var compose_durations: LineEdit
var compose_sources: Array[Dictionary] = []
var compose_previews: Dictionary = {}
var compose_actions: Dictionary = {}
var compose_metadata: Dictionary = {}
var compose_editing: bool = false
var preview: Control
var info: Label
var apply_button: Button
var confirm: ConfirmationDialog
var picker: FileDialog
var folder_picker: FileDialog
var character_folder: LineEdit
var folder_row: Control
var picker_target: LineEdit
var timer: Timer
var versioned: CheckBox
var queue_list: ItemList
var queue_review_button: Button
var undo_import_button: Button
var export_kind: OptionButton
var export_target: OptionButton
var export_target_row: Control
var export_free_path: LineEdit
var export_free_row: Control
var export_replace: CheckBox
var export_info: Label
var export_confirm: ConfirmationDialog
var undo_import_confirm: ConfirmationDialog
var undo_export_confirm: ConfirmationDialog
var undo_export_button: Button
var queue: Array[Dictionary] = []
var pending_entries: Array[Dictionary] = []
var pending_signature: String = ""
var pending_export: Dictionary = {}
var last_import_log: String = ""
var last_export_log: String = ""
var frames := PackedInt32Array([0])
var current_frame: int = 0
var busy: bool = false


func _ready() -> void:
    name = "Art Production"
    custom_minimum_size = Vector2(325, 400)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body = VBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_child(body)
    _heading("Art Production Importer")
    var note := Label.new()
    note.text = "仅编辑器使用；素材绑定到 .tres。可选择同步已有 .tscn 的贴图，不覆盖手工布局。"
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(note)

    var refresh := Button.new()
    refresh.text = "重新扫描 art-production"
    refresh.pressed.connect(_refresh_sources)
    body.add_child(refresh)
    search = LineEdit.new()
    search.placeholder_text = "按文件名筛选..."
    search.text_changed.connect(func(_text: String): _refresh_sources())
    body.add_child(search)
    source_list = ItemList.new()
    source_list.custom_minimum_size = Vector2(0, 150)
    source_list.item_selected.connect(func(_index: int): _refresh_preview())
    body.add_child(source_list)

    _heading("导入目标")
    kind = OptionButton.new()
    for label in LABELS:
        kind.add_item(label)
    kind.item_selected.connect(func(_index: int): _mode_changed())
    body.add_child(kind)
    targets = OptionButton.new()
    target_row = _labeled("角色 / 地图 / 章节 Resource", targets)
    targets.item_selected.connect(func(_index: int): _refresh_preview())
    character_folder = LineEdit.new()
    character_folder.placeholder_text = "art-production/.../characters/<id> 或 res://assets/imported/characters/<id>"
    character_folder.text_changed.connect(_folder_changed)
    var folder_controls := HBoxContainer.new()
    character_folder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    folder_controls.add_child(character_folder)
    var choose_folder := Button.new()
    choose_folder.text = "选择目录"
    choose_folder.pressed.connect(func(): folder_picker.popup_centered_ratio(0.7))
    folder_controls.add_child(choose_folder)
    folder_row = _labeled("按角色目录整体导入（已整理目录可直接绑定）", folder_controls)
    asset_id = LineEdit.new()
    asset_id.placeholder_text = "例如 ui.sword_cards"
    id_row = _labeled("WuxiaAssetDefinition ID", asset_id)
    event_kind = LineEdit.new()
    event_kind.placeholder_text = "例如 SWORD_SLASH"
    event_row = _labeled("VFX 事件（可选）", event_kind)
    for layer in ["ground", "foreground", "weather", "story_preview"]:
        var edit := LineEdit.new()
        edit.placeholder_text = "选择 art-production 文件"
        var row := HBoxContainer.new()
        var browse := Button.new()
        browse.text = "..."
        browse.pressed.connect(_browse.bind(edit))
        row.add_child(edit)
        edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(browse)
        extra_rows[layer] = _labeled("场景 " + layer, row)
        extras[layer] = edit
        edit.text_changed.connect(func(_value: String): _refresh_preview())

    native_scene = LineEdit.new()
    native_scene.placeholder_text = "可选：res://scenes/.../地图.tscn（仅更新 Sprite2D.texture）"
    native_scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    native_scene.text_changed.connect(func(_value: String): _refresh_preview())
    var scene_controls := HBoxContainer.new()
    scene_controls.add_child(native_scene)
    var use_edited := Button.new()
    use_edited.text = "当前场景"
    use_edited.tooltip_text = "读取 Godot 编辑器当前打开的 .tscn 路径，不自动选择或覆写其他场景。"
    use_edited.pressed.connect(func():
        var edited := EditorInterface.get_edited_scene_root()
        if edited != null:
            native_scene.text = edited.scene_file_path
            _refresh_preview())
    scene_controls.add_child(use_edited)
    native_scene_row = _labeled("原生地图 .tscn（显式选择）", scene_controls)

    columns = _number("Atlas 列数", 6, 1, 64)
    rows = _number("Atlas 行数", 4, 1, 64)
    feet_x = _number("脚点偏移 X", 0, -2048, 2048)
    feet_y = _number("脚点偏移 Y", -102, -2048, 2048)
    facing = CheckBox.new()
    facing.text = "原画朝左（不镜像）"
    facing.toggled.connect(func(_value: bool): _refresh_preview())
    body.add_child(facing)
    atlas_rows.append(facing)
    clip_profile = LineEdit.new()
    clip_profile.placeholder_text = "res://data/.../animation_profile.tres（动作帧配置可选）"
    clip_profile.text_changed.connect(func(_value: String): _refresh_preview())
    atlas_rows.append(_labeled("原生动作帧 Profile 模板（可选）", clip_profile))
    legacy_reuse = CheckBox.new()
    legacy_reuse.text = "兼容旧图：明确沿用角色已有帧配置（不用于新图）"
    legacy_reuse.toggled.connect(func(_value: bool): _refresh_preview())
    body.add_child(legacy_reuse)
    atlas_rows.append(legacy_reuse)
    var apply_candidate := Button.new()
    apply_candidate.text = "读取当前候选 .tres 参数"
    apply_candidate.pressed.connect(_apply_candidate_resource)
    body.add_child(apply_candidate)
    action_select = OptionButton.new()
    for action in WuxiaActorAnimationProfile.MODERN_REQUIRED_ACTIONS:
        action_select.add_item(action)
    atlas_rows.append(_labeled("动画预览", action_select))
    action_select.item_selected.connect(func(_index: int): _set_action())
    _build_composer()
    vfx_columns = _vfx_number("VFX 列数", 1)
    vfx_row_count = _vfx_number("VFX 行数", 1)
    vfx_frame_indices = LineEdit.new()
    vfx_frame_indices.placeholder_text = "绝对帧索引，例如 0,1,2,3"
    vfx_controls.append(_labeled("VFX 播放帧", vfx_frame_indices))
    vfx_frame_indices.text_changed.connect(func(_value: String): _refresh_preview())

    _heading("导入前预览")
    preview = Preview.new()
    preview.custom_minimum_size = Vector2(0, 225)
    preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_child(preview)
    info = Label.new()
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(info)
    apply_button = Button.new()
    apply_button.text = "检查并导入（需确认）"
    apply_button.pressed.connect(_review)
    body.add_child(apply_button)
    versioned = CheckBox.new()
    versioned.text = "版本化替换：不同内容图片另存 SHA 路径，保留旧版"
    body.add_child(versioned)
    versioned.toggled.connect(func(_enabled: bool): _refresh_preview())
    _heading("批量导入（显式目标队列）")
    var queue_add := Button.new()
    queue_add.text = "将当前预检条目加入批次"
    queue_add.pressed.connect(_enqueue)
    body.add_child(queue_add)
    queue_list = ItemList.new()
    queue_list.custom_minimum_size = Vector2(0, 95)
    body.add_child(queue_list)
    var queue_remove := Button.new()
    queue_remove.text = "移除选中条目"
    queue_remove.pressed.connect(_remove_queued)
    body.add_child(queue_remove)
    var queue_clear := Button.new()
    queue_clear.text = "清空批次"
    queue_clear.pressed.connect(_clear_queue)
    body.add_child(queue_clear)
    queue_review_button = Button.new()
    queue_review_button.text = "检查并批量导入（需确认）"
    queue_review_button.pressed.connect(_review_batch)
    body.add_child(queue_review_button)
    undo_import_button = Button.new()
    undo_import_button.text = "撤销上次导入（恢复原始 .tres）"
    undo_import_button.disabled = true
    undo_import_button.pressed.connect(func(): undo_import_confirm.popup_centered_ratio(0.6))
    body.add_child(undo_import_button)

    _heading("从当前 Godot 导出原始素材到 art-production")
    export_kind = OptionButton.new()
    for label in ["全部实际使用图片", "单个角色依赖", "单个地图依赖", "指定 .tres 依赖"]:
        export_kind.add_item(label)
    export_kind.item_selected.connect(func(_index: int): _export_kind_changed())
    body.add_child(export_kind)
    export_target = OptionButton.new()
    export_target_row = _labeled("导出对象", export_target)
    export_free_path = LineEdit.new()
    export_free_path.placeholder_text = "res://data/native/characters/shen_changfeng.tres"
    export_free_row = _labeled("指定已有 .tres 路径", export_free_path)
    export_replace = CheckBox.new()
    export_replace.text = "允许覆盖生产区已有不同内容的副本（会备份）"
    body.add_child(export_replace)
    var export_review := Button.new()
    export_review.text = "预检导出差异（需确认）"
    export_review.pressed.connect(_review_export)
    body.add_child(export_review)
    export_info = Label.new()
    export_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(export_info)
    undo_export_button = Button.new()
    undo_export_button.text = "撤销上次导出（可恢复备份）"
    undo_export_button.disabled = true
    undo_export_button.pressed.connect(func(): undo_export_confirm.popup_centered_ratio(0.6))
    body.add_child(undo_export_button)

    confirm = ConfirmationDialog.new()
    confirm.title = "确认 Godot 资源变更"
    confirm.confirmed.connect(_apply)
    add_child(confirm)
    export_confirm = ConfirmationDialog.new()
    export_confirm.title = "确认导出到美术生产区"
    export_confirm.confirmed.connect(_apply_export)
    add_child(export_confirm)
    undo_import_confirm = ConfirmationDialog.new()
    undo_import_confirm.title = "确认恢复 .tres"
    undo_import_confirm.dialog_text = "仅恢复本次事务的 .tres；新增图片保留。若 Resource 已被后续编辑，撤销会拒绝覆盖。"
    undo_import_confirm.confirmed.connect(_undo_import)
    add_child(undo_import_confirm)
    undo_export_confirm = ConfirmationDialog.new()
    undo_export_confirm.title = "确认撤销导出"
    undo_export_confirm.dialog_text = "恢复旧生产副本，新增副本移动至事务的 recovered-new 目录，不直接删除。"
    undo_export_confirm.confirmed.connect(_undo_export)
    add_child(undo_export_confirm)
    picker = FileDialog.new()
    picker.access = FileDialog.ACCESS_FILESYSTEM
    picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    picker.add_filter("*.png,*.webp,*.jpg,*.jpeg,*.svg", "图像文件")
    picker.file_selected.connect(_on_picked)
    add_child(picker)
    folder_picker = FileDialog.new()
    folder_picker.access = FileDialog.ACCESS_FILESYSTEM
    folder_picker.file_mode = FileDialog.FILE_MODE_OPEN_DIR
    folder_picker.dir_selected.connect(func(path: String):
        character_folder.text = path
        _folder_changed(path))
    add_child(folder_picker)
    timer = Timer.new()
    timer.wait_time = 0.12
    timer.timeout.connect(_next_frame)
    add_child(timer)
    timer.start()
    _mode_changed()
    _refresh_sources()
    _export_kind_changed()


func _heading(text: String) -> void:
    var label := Label.new()
    label.text = text
    body.add_child(label)


func _labeled(label: String, control: Control) -> Control:
    var container := VBoxContainer.new()
    var caption := Label.new()
    caption.text = label
    container.add_child(caption)
    container.add_child(control)
    body.add_child(container)
    return container


func _number(label: String, initial: float, minimum: float, maximum: float) -> SpinBox:
    var spin := SpinBox.new()
    spin.min_value = minimum
    spin.max_value = maximum
    spin.step = 1
    spin.value = initial
    atlas_rows.append(_labeled(label, spin))
    spin.value_changed.connect(func(_value: float): _refresh_preview())
    return spin


func _vfx_number(label: String, initial: float) -> SpinBox:
    var spin := SpinBox.new()
    spin.min_value = 1
    spin.max_value = 64
    spin.step = 1
    spin.value = initial
    vfx_controls.append(_labeled(label, spin))
    spin.value_changed.connect(func(_value: float): _refresh_preview())
    return spin


func _compose_number(key: String, label: String, initial: int, minimum: int = -4096,
        maximum: int = 4096) -> void:
    var spin := SpinBox.new()
    spin.min_value = minimum
    spin.max_value = maximum
    spin.step = 1
    spin.value = initial
    compose_numbers[key] = spin
    var row := HBoxContainer.new()
    var caption := Label.new()
    caption.text = label
    caption.custom_minimum_size.x = 100
    row.add_child(caption)
    spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(spin)
    compose_panel.add_child(row)
    spin.value_changed.connect(func(_value: float): _geometry_changed(key))


func _build_composer() -> void:
    compose_enabled = CheckBox.new()
    compose_enabled.text = "自由装配：多源图切格 + 十二动作映射（推荐新素材）"
    body.add_child(compose_enabled)
    compose_enabled.toggled.connect(func(_value: bool): _mode_changed())
    compose_panel = VBoxContainer.new()
    body.add_child(compose_panel)
    var help := Label.new()
    help.text = "从上方列表选择图片后添加。图编号从 0 起；格编号按行优先从 0 起。可点网格添加帧，或手输 0:0-7,1:2,0:9。"
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    compose_panel.add_child(help)
    compose_tall = CheckBox.new()
    compose_tall.text = "高个档：输出 384×288 单格（默认普通档 328×256）"
    compose_panel.add_child(compose_tall)
    compose_native = CheckBox.new()
    compose_native.text = "生成原生 SpriteFrames.tres（推荐；旧 Clip 仅兼容）"
    compose_native.button_pressed = true
    compose_panel.add_child(compose_native)
    var add_source := Button.new()
    add_source.text = "添加选中的源图集"
    add_source.pressed.connect(_add_composition_source)
    compose_panel.add_child(add_source)
    compose_source_list = ItemList.new()
    compose_source_list.custom_minimum_size.y = 92
    compose_source_list.item_selected.connect(func(_index: int): _load_composition_geometry())
    compose_panel.add_child(compose_source_list)
    var preview_caption := Label.new()
    preview_caption.text = "切格与动作预览（可点击格位追加当前动作帧）"
    compose_panel.add_child(preview_caption)
    compose_preview = Preview.new()
    compose_preview.custom_minimum_size = Vector2(0, 340)
    compose_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    compose_preview.cell_clicked.connect(_on_grid_cell_clicked)
    compose_preview.crop_drawn.connect(_on_crop_drawn)
    compose_preview.mask_drawn.connect(_on_mask_drawn)
    compose_panel.add_child(compose_preview)
    compose_status = Label.new()
    compose_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    compose_panel.add_child(compose_status)
    var playback_buttons := GridContainer.new()
    playback_buttons.columns = 3
    for caption in ["查看网格", "播放动作", "暂停", "上一帧", "下一帧"]:
        var button := Button.new()
        button.text = caption
        button.pressed.connect(_composition_control.bind(caption))
        playback_buttons.add_child(button)
    compose_panel.add_child(playback_buttons)
    var remove_source := Button.new()
    remove_source.text = "移除选中源图（之后的源图编号会重排）"
    remove_source.pressed.connect(_remove_composition_source)
    compose_panel.add_child(remove_source)
    for item in [
        ["columns", "源图列数", 5, 1, 64], ["rows", "源图行数", 5, 1, 64],
        ["cell_width", "单格宽度", 328, 1, 4096],
        ["cell_height", "单格高度", 256, 1, 4096],
        ["origin_x", "网格起点 X", 0, -4096, 4096],
        ["origin_y", "网格起点 Y", 0, -4096, 4096],
        ["gap_x", "横向格距", 0, -4096, 4096],
        ["gap_y", "纵向格距", 0, -4096, 4096],
        ["selected_cell", "微调的格号", 0, 0, 4095],
        ["local_x", "当前格偏移 X", 0, -4096, 4096],
        ["local_y", "当前格偏移 Y", 0, -4096, 4096],
        ["crop_x", "当前帧裁切 X", 0, 0, 16384],
        ["crop_y", "当前帧裁切 Y", 0, 0, 16384],
        ["crop_w", "当前帧裁切宽度", 328, 1, 16384],
        ["crop_h", "当前帧裁切高度", 256, 1, 16384],
        ["canvas_x", "输出画布偏移 X", 0, -4096, 4096],
        ["canvas_y", "输出画布偏移 Y", 0, -4096, 4096]]:
        _compose_number(str(item[0]), str(item[1]), int(item[2]), int(item[3]), int(item[4]))
    compose_selection_mode = OptionButton.new()
    for label in ["点击格子加入动作", "拖拽矩形裁切", "自由手绘套索抠图", "多边形点击描边（右键闭合）"]:
        compose_selection_mode.add_item(label)
    compose_selection_mode.item_selected.connect(func(_value: int): _refresh_preview())
    compose_panel.add_child(_compose_labeled("源图交互工具", compose_selection_mode))
    compose_zoom = SpinBox.new()
    compose_zoom.min_value = 1.0
    compose_zoom.max_value = 8.0
    compose_zoom.step = 0.5
    compose_zoom.value = 1.0
    compose_zoom.value_changed.connect(func(_value: float): _refresh_preview())
    compose_panel.add_child(_compose_labeled("局部放大倍率（1 为整图，按住鼠标中键平移）", compose_zoom))
    var reset_crop := Button.new()
    reset_crop.text = "重置当前帧裁切矩形、蒙版和输出偏移"
    reset_crop.pressed.connect(_reset_crop)
    compose_panel.add_child(reset_crop)
    compose_grid = CheckBox.new()
    compose_grid.text = "显示整图切格（取消后显示当前动作帧）"
    compose_grid.button_pressed = true
    compose_grid.toggled.connect(func(_value: bool): _refresh_preview())
    compose_panel.add_child(compose_grid)
    var append := Button.new()
    append.text = "将当前格加入选中动作帧序"
    append.pressed.connect(_append_selected_cell)
    compose_panel.add_child(append)
    compose_mapping = LineEdit.new()
    compose_mapping.placeholder_text = "例如 0:0-7,1:0,1:4（可跨源图、乱序）"
    compose_mapping.text_changed.connect(_mapping_changed)
    compose_panel.add_child(_compose_labeled("当前动作的有序帧映射", compose_mapping))
    compose_loop = CheckBox.new()
    compose_loop.text = "循环播放"
    compose_loop.toggled.connect(func(_value: bool): _metadata_changed())
    compose_panel.add_child(compose_loop)
    compose_fps = SpinBox.new()
    compose_fps.min_value = 1.0
    compose_fps.max_value = 60.0
    compose_fps.step = 0.5
    compose_fps.value_changed.connect(func(_value: float): _metadata_changed())
    compose_panel.add_child(_compose_labeled("当前动作 FPS", compose_fps))
    compose_durations = LineEdit.new()
    compose_durations.placeholder_text = "逐帧秒数，例如 0.08,0.12,0.10（留空则使用 FPS）"
    compose_durations.text_changed.connect(func(_value: String): _metadata_changed())
    compose_panel.add_child(_compose_labeled("逐帧时长（可选）", compose_durations))
    _load_action_fields()


func _compose_labeled(label: String, control: Control) -> Control:
    var column := VBoxContainer.new()
    var caption := Label.new()
    caption.text = label
    column.add_child(caption)
    column.add_child(control)
    return column


func _composition_index() -> int:
    var selected := compose_source_list.get_selected_items()
    return selected[0] if not selected.is_empty() else -1


func _add_composition_source() -> void:
    var path := _selected_source()
    if path.is_empty() or compose_sources.size() >= 32:
        info.text = "请选择源图（最多 32 张）"
        return
    for item in compose_sources:
        if item["path"] == path:
            info.text = "此源图已经添加"
            return
    var details := Service.inspect(path)
    if not str(details.get("error", "")).is_empty():
        info.text = str(details["error"])
        return
    compose_previews[path] = {"time": FileAccess.get_modified_time(path), "data": details}
    var candidate := Service.candidate_for_source(path)
    var cols := candidate.columns if candidate != null and candidate.columns > 0 else 5
    var count_rows := candidate.rows if candidate != null and candidate.rows > 0 else 5
    var existing_size: Vector2i = candidate.grid_cell_size if candidate != null else Vector2i.ZERO
    var original_size := Vector2i(int(details["width"]) / cols, int(details["height"]) / count_rows)
    var cell_size: Vector2i = existing_size if existing_size != Vector2i.ZERO else original_size
    var origin: Vector2i = candidate.grid_origin if candidate != null else Vector2i.ZERO
    var gap: Vector2i = candidate.grid_gap if candidate != null else Vector2i.ZERO
    var offsets: Dictionary = candidate.grid_cell_offsets.duplicate(true) if candidate != null else {}
    var rects: Dictionary = candidate.grid_cell_rects.duplicate(true) if candidate != null else {}
    var canvas_offsets: Dictionary = candidate.grid_canvas_offsets.duplicate(true) if candidate != null else {}
    var masks: Dictionary = candidate.grid_cutout_polygons.duplicate(true) if candidate != null else {}
    compose_sources.append({"path": path, "columns": cols, "rows": count_rows,
        "cell_width": cell_size.x, "cell_height": cell_size.y,
        "origin_x": origin.x, "origin_y": origin.y,
        "gap_x": gap.x, "gap_y": gap.y, "offsets": offsets,
        "rects": rects, "canvas_offsets": canvas_offsets, "masks": masks})
    _refresh_composition_list()
    compose_source_list.select(compose_sources.size() - 1)
    _load_composition_geometry()


func _refresh_composition_list() -> void:
    compose_source_list.clear()
    for i in range(compose_sources.size()):
        compose_source_list.add_item("%d · %s" % [i, str(compose_sources[i]["path"])
            .trim_prefix(Service.production_root() + "/")])


func _remove_composition_source() -> void:
    var index := _composition_index()
    if index < 0:
        return
    compose_sources.remove_at(index)
    # Existing mappings are deliberately left visible; invalid indices fail
    # preflight until the artist explicitly reassigns them.
    _refresh_composition_list()
    if not compose_sources.is_empty():
        compose_source_list.select(mini(index, compose_sources.size() - 1))
    _load_composition_geometry()


func _load_composition_geometry() -> void:
    compose_editing = true
    var index := _composition_index()
    if index >= 0:
        var source: Dictionary = compose_sources[index]
        for key in ["columns", "rows", "cell_width", "cell_height", "origin_x", "origin_y", "gap_x", "gap_y"]:
            compose_numbers[key].value = int(source[key])
        compose_numbers["selected_cell"].value = 0
        compose_numbers["local_x"].value = 0
        compose_numbers["local_y"].value = 0
        source["editing_cell"] = 0
        compose_sources[index] = source
        _load_frame_crop_fields(source, 0)
    compose_editing = false
    _refresh_preview()


func _load_frame_crop_fields(source: Dictionary, cell_index: int) -> void:
    var rect := Assembly.cell_rect(source, cell_index)
    var placement: Vector2i = source.get("canvas_offsets", {}).get(cell_index, Vector2i.ZERO)
    compose_numbers["crop_x"].value = rect.position.x
    compose_numbers["crop_y"].value = rect.position.y
    compose_numbers["crop_w"].value = maxi(rect.size.x, 1)
    compose_numbers["crop_h"].value = maxi(rect.size.y, 1)
    compose_numbers["canvas_x"].value = placement.x
    compose_numbers["canvas_y"].value = placement.y


func _geometry_changed(changed_field: String) -> void:
    if compose_editing:
        return
    var index := _composition_index()
    if index < 0:
        return
    var source: Dictionary = compose_sources[index]
    for key in ["columns", "rows", "cell_width", "cell_height", "origin_x", "origin_y", "gap_x", "gap_y"]:
        source[key] = int(compose_numbers[key].value)
    var cell_index := int(compose_numbers["selected_cell"].value)
    var offsets: Dictionary = source.get("offsets", {})
    # Selecting another cell loads its saved local offset instead of carrying
    # the previous cell's adjustment into the new cell.
    if cell_index != int(source.get("editing_cell", 0)):
        source["editing_cell"] = cell_index
        var offset: Vector2i = offsets.get(cell_index, Vector2i.ZERO)
        compose_editing = true
        compose_numbers["local_x"].value = offset.x
        compose_numbers["local_y"].value = offset.y
        _load_frame_crop_fields(source, cell_index)
        compose_editing = false
    else:
        var offset := Vector2i(int(compose_numbers["local_x"].value),
            int(compose_numbers["local_y"].value))
        if offset == Vector2i.ZERO:
            offsets.erase(cell_index)
        else:
            offsets[cell_index] = offset
        source["offsets"] = offsets
    if changed_field in ["crop_x", "crop_y", "crop_w", "crop_h"]:
        var rect := Rect2i(int(compose_numbers["crop_x"].value),
            int(compose_numbers["crop_y"].value),
            int(compose_numbers["crop_w"].value), int(compose_numbers["crop_h"].value))
        var rects: Dictionary = source.get("rects", {})
        if rect == Assembly.grid_rect(source, cell_index):
            rects.erase(cell_index)
        else:
            rects[cell_index] = rect
        source["rects"] = rects
    if changed_field in ["canvas_x", "canvas_y"]:
        var placement := Vector2i(int(compose_numbers["canvas_x"].value),
            int(compose_numbers["canvas_y"].value))
        var placements: Dictionary = source.get("canvas_offsets", {})
        if placement == Vector2i.ZERO:
            placements.erase(cell_index)
        else:
            placements[cell_index] = placement
        source["canvas_offsets"] = placements
    if changed_field in ["columns", "rows", "cell_width", "cell_height",
            "origin_x", "origin_y", "gap_x", "gap_y", "local_x", "local_y"]:
        compose_editing = true
        _load_frame_crop_fields(source, cell_index)
        compose_editing = false
    compose_sources[index] = source
    _refresh_preview()


func _on_crop_drawn(cell_index: int, rect: Rect2i) -> void:
    var source_index := _composition_index()
    if source_index < 0:
        return
    var source: Dictionary = compose_sources[source_index]
    var rects: Dictionary = source.get("rects", {})
    rects[cell_index] = rect
    source["rects"] = rects
    source["editing_cell"] = cell_index
    compose_sources[source_index] = source
    compose_editing = true
    compose_numbers["selected_cell"].value = cell_index
    _load_frame_crop_fields(source, cell_index)
    compose_editing = false
    _refresh_composition_preview()


func _on_mask_drawn(cell_index: int, polygon: PackedVector2Array) -> void:
    var index := _composition_index()
    if index < 0:
        return
    var source: Dictionary = compose_sources[index]
    var rect := Assembly.cell_rect(source, cell_index)
    for point in polygon:
        if point.x < rect.position.x or point.y < rect.position.y or \
                point.x > rect.end.x or point.y > rect.end.y:
            _composition_message("描边轮廓超出本帧矩形；请先扩大裁切框或重新描边。")
            return
    var masks: Dictionary = source.get("masks", {})
    masks[cell_index] = polygon.duplicate()
    source["masks"] = masks
    compose_sources[index] = source
    compose_editing = true
    compose_numbers["selected_cell"].value = cell_index
    source["editing_cell"] = cell_index
    _load_frame_crop_fields(source, cell_index)
    compose_editing = false
    _refresh_composition_preview()


func _reset_crop() -> void:
    var index := _composition_index()
    if index < 0:
        return
    var source: Dictionary = compose_sources[index]
    var cell_index := int(compose_numbers["selected_cell"].value)
    var rects: Dictionary = source.get("rects", {})
    rects.erase(cell_index)
    source["rects"] = rects
    var placements: Dictionary = source.get("canvas_offsets", {})
    placements.erase(cell_index)
    source["canvas_offsets"] = placements
    var masks: Dictionary = source.get("masks", {})
    masks.erase(cell_index)
    source["masks"] = masks
    compose_sources[index] = source
    compose_editing = true
    _load_frame_crop_fields(source, cell_index)
    compose_editing = false
    _refresh_composition_preview()


func _action_name() -> String:
    return action_select.get_item_text(action_select.selected) if action_select.selected >= 0 else "idle"


func _load_action_fields() -> void:
    compose_editing = true
    var action := _action_name()
    var config: Dictionary = compose_metadata.get(action, {})
    compose_mapping.text = str(compose_actions.get(action, ""))
    compose_loop.button_pressed = bool(config.get("loop", action in ["idle", "walk", "run"]))
    compose_fps.value = float(config.get("fps", 12.0))
    compose_durations.text = str(config.get("durations", ""))
    compose_editing = false


func _mapping_changed(value: String) -> void:
    if compose_editing:
        return
    compose_actions[_action_name()] = value
    _refresh_preview()


func _composition_control(action: String) -> void:
    match action:
        "查看网格":
            compose_playing = false
            compose_grid.button_pressed = true
        "播放动作":
            current_frame = 0
            compose_grid.button_pressed = false
            compose_playing = true
            timer.start()
        "暂停":
            compose_playing = false
        "上一帧":
            compose_playing = false
            _step_composition(-1)
        "下一帧":
            compose_playing = false
            _step_composition(1)
    _refresh_preview()


func _step_composition(direction: int) -> void:
    var parsed := Assembly.parse_mapping(str(compose_actions.get(_action_name(), "")),
        compose_sources.size())
    if not str(parsed["error"]).is_empty():
        return
    var refs: Array = parsed["frames"]
    compose_grid.button_pressed = false
    current_frame = clampi(current_frame + direction, 0, refs.size() - 1)


func _metadata_changed() -> void:
    if compose_editing:
        return
    compose_metadata[_action_name()] = {"loop": compose_loop.button_pressed,
        "fps": compose_fps.value, "durations": compose_durations.text}
    _refresh_preview()


func _on_grid_cell_clicked(index: int) -> void:
    compose_numbers["selected_cell"].value = index
    if compose_selection_mode.selected == 0:
        _append_selected_cell()


func _append_selected_cell() -> void:
    var source_index := _composition_index()
    if source_index < 0:
        info.text = "请先选择一张已添加的源图"
        return
    var token := "%d:%d" % [source_index, int(compose_numbers["selected_cell"].value)]
    compose_mapping.text = (compose_mapping.text + "," if not compose_mapping.text.is_empty() else "") + token
    _mapping_changed(compose_mapping.text)


func _mode() -> String:
    return MODES[kind.selected] if kind.selected >= 0 else "portrait"


func _selected_source() -> String:
    var selected := source_list.get_selected_items()
    if selected.is_empty():
        return ""
    return str(source_list.get_item_metadata(selected[0]))


func _target() -> String:
    return str(targets.get_item_metadata(targets.selected)) if targets.selected >= 0 else ""


func _refresh_sources() -> void:
    if source_list == null:
        return
    var old := _selected_source()
    source_list.clear()
    var root: String = Service.production_root()
    for path in Service.collect_sources():
        var label: String = path.trim_prefix(root + "/")
        if not search.text.is_empty() and not label.to_lower().contains(search.text.to_lower()):
            continue
        var index := source_list.item_count
        source_list.add_item(label)
        source_list.set_item_metadata(index, path)
        if path == old:
            source_list.select(index)
    if source_list.get_selected_items().is_empty() and source_list.item_count > 0:
        source_list.select(0)
    _refresh_preview()


func _mode_changed() -> void:
    var mode := _mode()
    target_row.visible = mode in ["portrait", "atlas", "scene", "character_folder"]
    folder_row.visible = mode == "character_folder"
    source_list.visible = mode != "character_folder"
    search.visible = mode != "character_folder"
    id_row.visible = mode in ["ui_atlas", "vfx"]
    event_row.visible = mode == "vfx"
    for layer in extra_rows:
        extra_rows[layer].visible = mode == "scene"
    native_scene_row.visible = mode == "scene"
    for control in atlas_rows:
        control.visible = (mode == "atlas" and (not compose_enabled.button_pressed or
            control not in [columns.get_parent(), rows.get_parent()])) or \
            (mode == "character_folder" and control == clip_profile.get_parent())
    compose_enabled.visible = mode == "atlas"
    compose_panel.visible = mode == "atlas" and compose_enabled.button_pressed
    preview.visible = not (mode == "atlas" and compose_enabled.button_pressed)
    for control in vfx_controls:
        control.visible = mode == "vfx"
    _load_targets()
    _refresh_preview()


func _folder_changed(folder: String) -> void:
    if _mode() == "character_folder":
        var expected := "res://data/native/characters/" + folder.strip_edges().simplify_path().get_file() + ".tres"
        for i in targets.item_count:
            if str(targets.get_item_metadata(i)) == expected:
                targets.select(i)
                break
    _refresh_preview()


func _load_targets() -> void:
    targets.clear()
    var mode := _mode()
    var folders: Array[String] = []
    if mode in ["portrait", "atlas", "character_folder"]:
        folders.append("res://data/native/characters")
    elif mode == "scene":
        folders.assign(["res://data/maps", "res://data/native/chapters"])
    for folder in folders:
        var dir := DirAccess.open(folder)
        if dir == null:
            continue
        var entries := Array(DirAccess.get_files_at(folder))
        entries.sort()
        for filename in entries:
            if not str(filename).ends_with(".tres"):
                continue
            var path := folder.path_join(str(filename))
            var resource := ResourceLoader.load(path)
            if mode == "scene" and not (resource is WuxiaMapDefinition or
                    resource is WuxiaGridMapDefinition or
                    (resource is WuxiaChapterDefinition and resource.get("scene") is WuxiaChapterSceneDefinition)):
                continue
            if mode in ["portrait", "atlas", "character_folder"] and not resource is WuxiaCharacterDefinition:
                continue
            var label := str(filename).get_basename()
            if resource is WuxiaContentDefinition:
                label = resource.content_id
            var index := targets.item_count
            targets.add_item(label)
            targets.set_item_metadata(index, path)
    if targets.item_count > 0:
        targets.select(0)
        if mode == "character_folder" and character_folder != null:
            _folder_changed(character_folder.text)


func _browse(line: LineEdit) -> void:
    picker_target = line
    picker.current_dir = Service.production_root()
    picker.popup_centered_ratio(0.7)


func _on_picked(path: String) -> void:
    if picker_target != null:
        picker_target.text = path
        _refresh_preview()


func _fields() -> Dictionary:
    var frame_numbers := PackedInt32Array()
    for token in vfx_frame_indices.text.split(",", false):
        var value: String = token.strip_edges()
        frame_numbers.append(int(value) if value.is_valid_int() else -1)
    return {
        "asset_id": asset_id.text.strip_edges(),
        "event_kind": event_kind.text.strip_edges(),
        "columns": int(vfx_columns.value) if _mode() == "vfx" else int(columns.value),
        "rows": int(vfx_row_count.value) if _mode() == "vfx" else int(rows.value),
        "frame_indices": frame_numbers,
        "feet_offset": Vector2(feet_x.value, feet_y.value),
        "faces_left": facing.button_pressed,
        "clip_profile_path": clip_profile.text.strip_edges(),
        "reuse_existing_clips": legacy_reuse.button_pressed,
        "composition_enabled": _mode() == "atlas" and compose_enabled.button_pressed,
        "composition_sources": compose_sources.duplicate(true),
        "composition_actions": compose_actions.duplicate(true),
        "composition_metadata": compose_metadata.duplicate(true),
        "composition_tall": compose_tall.button_pressed,
        "composition_native": compose_native.button_pressed,
        "versioned_replace": versioned.button_pressed,
        "ground": extras["ground"].text.strip_edges(),
        "foreground": extras["foreground"].text.strip_edges(),
        "weather": extras["weather"].text.strip_edges(),
        "story_preview": extras["story_preview"].text.strip_edges(),
        "native_scene_path": native_scene.text.strip_edges() if _mode() == "scene" else "",
    }


func _apply_candidate_resource() -> void:
    var candidate: WuxiaArtCandidateDefinition = Service.candidate_for_source(_selected_source())
    if candidate == null:
        info.text = "当前图片没有对应候选 .tres；使用正式 in-use 图片时无需候选 Resource。"
        return
    var problem: String = candidate.validate_source()
    if not problem.is_empty():
        info.text = problem
        return
    if candidate.columns > 0 and candidate.rows > 0:
        if _mode() == "atlas":
            columns.value = candidate.columns
            rows.value = candidate.rows
        elif _mode() == "vfx":
            vfx_columns.value = candidate.columns
            vfx_row_count.value = candidate.rows
    if _mode() == "atlas" and candidate.feet_offset_set:
        feet_x.value = candidate.feet_offset.x
        feet_y.value = candidate.feet_offset.y
    if _mode() == "vfx" and not candidate.frame_indices.is_empty():
        var parts := PackedStringArray()
        for index in candidate.frame_indices:
            parts.append(str(index))
        vfx_frame_indices.text = ",".join(parts)
    _refresh_preview()


func _refresh_preview() -> void:
    if preview == null:
        return
    if _mode() == "atlas" and compose_enabled.button_pressed:
        _refresh_composition_preview()
        return
    if _mode() == "character_folder":
        var folder_plan := Service.plan_character_folder(character_folder.text.strip_edges(), _target(), _fields())
        if not str(folder_plan.get("error", "")).is_empty():
            info.text = str(folder_plan["error"])
            return
        var names := PackedStringArray()
        for role in folder_plan["files"]:
            names.append(str(role) + " → " + str(folder_plan["files"][role]["destination"]))
        names.sort()
        info.text = "角色文件自动归类（%d 项）：\n%s\n正式绑定需确认；不会自动选 _vNN 版本。" % [names.size(), "\n".join(names)]
        return
    var path := _selected_source()
    if path.is_empty():
        info.text = "art-production 中没有可预览素材。请先完成 P0 归档。"
        return
    var details: Dictionary = Service.inspect(path)
    if not str(details.get("error", "")).is_empty():
        info.text = str(details["error"])
        return
    var mode := _mode()
    info.text = "%s × %s | Alpha: %s | SHA-256: %s\n文件导入与绑定不代表美术视觉或权属审核通过" % [
        details["width"], details["height"],
        "是" if details["alpha"] else "否", str(details["sha256"]).substr(0, 12)]
    var candidate: WuxiaArtCandidateDefinition = Service.candidate_for_source(path)
    preview.call("set_candidate_display_scale", candidate.display_scale() if candidate != null and mode == "atlas" else 0.0)
    if candidate != null:
        var scale_factor: float = candidate.display_scale()
        info.text += "\n候选 .tres：%s×%s 格；参考高度：%s px；预览比例：%s" % [
            candidate.columns, candidate.rows, candidate.reference_visible_height_px,
            ("%.3f" % scale_factor) if scale_factor > 0.0 else "未测量"]
    if mode == "atlas":
        preview.call("show_atlas", details["texture"], int(columns.value), int(rows.value),
                           Vector2(feet_x.value, feet_y.value))
        _set_action()
    elif mode == "vfx":
        preview.call("show_atlas", details["texture"], int(vfx_columns.value), int(vfx_row_count.value), Vector2.ZERO)
    elif mode == "scene":
        var layer_images := {"primary": details["texture"]}
        for layer in extras:
            var layer_path: String = extras[layer].text.strip_edges()
            if not layer_path.is_empty():
                var item: Dictionary = Service.inspect(layer_path)
                if str(item.get("error", "")).is_empty():
                    layer_images[layer] = item["texture"]
        preview.call("show_scene", layer_images, ResourceLoader.load(_target()) if not _target().is_empty() else null)
    else:
        preview.call("show_image", details["texture"])


func _refresh_composition_preview() -> void:
    if compose_sources.is_empty():
        _composition_message("自由装配：先选择一张图片，点击「添加选中的源图集」。")
        compose_preview.call("show_image", null)
        return
    var index := _composition_index()
    if index < 0:
        index = 0
    var source: Dictionary = compose_sources[index]
    var details := _compose_inspect(str(source["path"]))
    if not str(details.get("error", "")).is_empty():
        _composition_message(str(details["error"]))
        return
    var parsed := Assembly.parse_mapping(str(compose_actions.get(_action_name(), "")),
        compose_sources.size())
    var message := "源图 %d/%d · %sx%s · 已映射动作 %d/12；可放大描边并逐帧核对。" % [
        index, compose_sources.size(), details["width"], details["height"], compose_actions.size()]
    if not str(parsed["error"]).is_empty():
        message += "\n当前动作尚无播放帧：" + str(parsed["error"])
    else:
        var refs: Array = parsed["frames"]
        current_frame = clampi(current_frame, 0, refs.size() - 1)
        message += "\n%s · 第 %d/%d 帧 · %s" % [_action_name(),
            current_frame + 1, refs.size(),
            "播放中" if compose_playing and not compose_grid.button_pressed else "暂停/切格"]
    _composition_message(message)
    compose_preview.call("set_candidate_display_scale", 0.0)
    if compose_grid.button_pressed or not str(parsed["error"]).is_empty():
        compose_preview.call("set_grid_zoom", compose_zoom.value,
            int(compose_numbers["selected_cell"].value))
        compose_preview.call("show_grid", details["texture"], source,
            ["select", "crop", "lasso", "polygon"][compose_selection_mode.selected])
        return
    var refs: Array = parsed["frames"]
    _show_composition_frame(refs[current_frame])


func _composition_message(value: String) -> void:
    info.text = value
    compose_status.text = value


func _show_composition_frame(ref: Dictionary) -> void:
    var source: Dictionary = compose_sources[int(ref["source"])]
    var details := _compose_inspect(str(source["path"]))
    if not str(details.get("error", "")).is_empty():
        _composition_message(str(details["error"]))
        return
    var rect := Assembly.cell_rect(source, int(ref["cell"]))
    if not rect.has_area() or rect.position.x < 0 or rect.position.y < 0 or \
            rect.end.x > int(details["width"]) or rect.end.y > int(details["height"]):
        _composition_message("当前动作帧超出源图，请校准网格")
        return
    var points: PackedVector2Array = source.get("masks", {}).get(int(ref["cell"]), PackedVector2Array())
    if points.is_empty():
        compose_preview.call("show_sliced_frame", details["texture"], rect,
            Vector2(feet_x.value, feet_y.value))
    else:
        var cropped: Image = (details["texture"] as Texture2D).get_image().get_region(rect)
        var result := Assembly.mask_frame(cropped, rect, points)
        if not str(result.get("error", "")).is_empty():
            _composition_message("当前帧蒙版错误：" + str(result["error"]))
            return
        compose_preview.call("show_sliced_frame", ImageTexture.create_from_image(result["image"]),
            Rect2i(Vector2i.ZERO, rect.size), Vector2(feet_x.value, feet_y.value))


func _compose_inspect(path: String) -> Dictionary:
    var changed_at := FileAccess.get_modified_time(path)
    if compose_previews.has(path) and compose_previews[path]["time"] == changed_at:
        return compose_previews[path]["data"]
    var details := Service.inspect(path)
    if str(details.get("error", "")).is_empty():
        compose_previews[path] = {"time": changed_at, "data": details}
    return details


func _set_action() -> void:
    if compose_enabled.button_pressed and _mode() == "atlas":
        current_frame = 0
        _load_action_fields()
        _refresh_composition_preview()
        return
    var selected := _action_name()
    var profile := _preview_profile()
    frames = PackedInt32Array()
    var clip: WuxiaActorAnimationClip = profile.clip_for(selected) if profile != null else null
    if clip != null and not clip.frames.is_empty():
        frames = clip.frames
        timer.wait_time = 1.0 / clip.loop_fps
    current_frame = 0
    if preview != null and not frames.is_empty():
        preview.call("show_frame", frames[0])
    elif preview != null:
        preview.call("show_image", null)
        info.text += "\n未配置动作 " + selected + "，不能沿用第 0 帧预览。"


func _preview_profile() -> WuxiaActorAnimationProfile:
    var profile: WuxiaActorAnimationProfile = null
    if clip_profile != null and not clip_profile.text.strip_edges().is_empty() and \
            ResourceLoader.exists(clip_profile.text.strip_edges()):
        profile = ResourceLoader.load(clip_profile.text.strip_edges()) as WuxiaActorAnimationProfile
    if profile == null and legacy_reuse.button_pressed and not _target().is_empty():
        var character := ResourceLoader.load(_target()) as WuxiaCharacterDefinition
        if character != null:
            profile = character.animation_profile
    return profile


func _next_frame() -> void:
    if _mode() != "atlas" or preview == null:
        return
    if compose_enabled.button_pressed:
        if compose_grid.button_pressed or not compose_playing:
            return
        var parsed := Assembly.parse_mapping(str(compose_actions.get(_action_name(), "")),
            compose_sources.size())
        if not str(parsed["error"]).is_empty():
            return
        var refs: Array = parsed["frames"]
        var settings: Dictionary = compose_metadata.get(_action_name(), {})
        var loop := bool(settings.get("loop", _action_name() in ["idle", "walk", "run"]))
        if not loop and current_frame >= refs.size() - 1:
            compose_playing = false
            _refresh_composition_preview()
            return
        var duration_list: String = str(settings.get("durations", ""))
        var times := duration_list.split(",", false)
        if times.size() == refs.size() and times[current_frame].strip_edges().is_valid_float() and \
                float(times[current_frame]) > 0:
            timer.wait_time = float(times[current_frame])
        else:
            timer.wait_time = 1.0 / maxf(float(settings.get("fps", 12.0)), 1.0)
        current_frame = (current_frame + 1) % refs.size()
        _refresh_composition_preview()
        return
    if frames.is_empty():
        return
    if action_select.selected >= 0:
        var profile := _preview_profile()
        var clip: WuxiaActorAnimationClip = profile.clip_for(_action_name()) if profile != null else null
        if clip != null and not clip.loop and current_frame >= frames.size() - 1:
            return
    current_frame = (current_frame + 1) % frames.size()
    preview.call("show_frame", frames[current_frame])



func _current_entry() -> Dictionary:
    return {"mode": _mode(), "source": character_folder.text.strip_edges() if _mode() == "character_folder" else _selected_source(), "target": _target(),
            "fields": _fields().duplicate(true)}


func _describe_entry(entry: Dictionary) -> String:
    var mode: String = str(entry["mode"])
    var target: String = str(entry["target"])
    if mode in ["ui_atlas", "vfx"]:
        target = str(entry["fields"].get("asset_id", ""))
    return mode + ": " + str(entry["source"]).get_file() + " → " + target.get_file()


func _refresh_queue() -> void:
    queue_list.clear()
    for entry in queue:
        queue_list.add_item(_describe_entry(entry))
    queue_review_button.disabled = queue.is_empty()


func _enqueue() -> void:
    if busy:
        return
    var entry := _current_entry()
    var plan_data: Dictionary = _plan_entry(entry)
    if not str(plan_data.get("error", "")).is_empty():
        info.text = "加入失败：" + str(plan_data["error"])
        return
    if queue.size() >= 64:
        info.text = "单批最多 64 项"
        return
    queue.append(entry)
    _refresh_queue()
    info.text = "已加入批次：" + _describe_entry(entry)


func _remove_queued() -> void:
    var selected := queue_list.get_selected_items()
    if busy or selected.is_empty():
        return
    queue.remove_at(selected[0])
    _refresh_queue()


func _clear_queue() -> void:
    if busy:
        return
    queue.clear()
    _refresh_queue()


func _gather_plans(entries: Array[Dictionary]) -> Dictionary:
    var plans: Array[Dictionary] = []
    for entry in entries:
        var attempt: Dictionary = _plan_entry(entry)
        if not str(attempt.get("error", "")).is_empty():
            return {"error": _describe_entry(entry) + "：" + str(attempt["error"])}
        plans.append(attempt)
    var problem: String = Transaction.validate(plans)
    return {"error": problem, "plans": plans}


func _plan_entry(entry: Dictionary) -> Dictionary:
    if str(entry["mode"]) == "character_folder":
        return Service.plan_character_folder(str(entry["source"]), str(entry["target"]), entry["fields"])
    return Service.plan(str(entry["mode"]), str(entry["source"]),
        str(entry["target"]), entry["fields"])


func _signature(plans: Array[Dictionary]) -> String:
    var lines := PackedStringArray()
    for plan_data in plans:
        var target: String = str(plan_data["target"])
        var profile: String = str(plan_data.get("profile_path", ""))
        lines.append("%s|%s|%s|%s|%s|%s" % [
            str(plan_data["mode"]), target, FileAccess.get_sha256(target),
            profile, FileAccess.get_sha256(profile) if not profile.is_empty() else "",
            FileAccess.get_sha256("res://data/content_manifest.tres") if plan_data["mode"] in ["ui_atlas", "vfx"] else ""
        ])
        var template := str(plan_data.get("template_path", ""))
        if not template.is_empty():
            lines.append(template + "|" + FileAccess.get_sha256(template))
        for update in plan_data.get("candidate_updates", []):
            var candidate_path := str(update["resource_path"])
            lines.append(candidate_path + "|" + FileAccess.get_sha256(candidate_path))
        var keys: Array = plan_data["files"].keys()
        keys.sort()
        for key in keys:
            var item: Dictionary = plan_data["files"][key]
            lines.append("%s:%s:%s:%s:%s" % [
                str(key), str(item["path"]), str(item["sha256"]),
                str(item["destination"]), str(item.get("replaces", ""))
            ])
        lines.append(str(plan_data.get("current_binding", "")) + " → " +
                     str(plan_data.get("next_binding", "")))
        var native_path := str(plan_data.get("native_scene_path", ""))
        if not native_path.is_empty():
            lines.append(native_path + "|" + FileAccess.get_sha256(native_path))
        var frames_path := str(plan_data.get("native_frames_path", ""))
        if not frames_path.is_empty():
            lines.append(frames_path + "|" + FileAccess.get_sha256(frames_path))
    return "\n".join(lines)


func _review() -> void:
    var entries: Array[Dictionary] = [_current_entry()]
    _review_entries(entries)


func _review_batch() -> void:
    var entries: Array[Dictionary] = []
    for entry in queue:
        entries.append(entry.duplicate(true))
    _review_entries(entries)


func _review_entries(entries: Array[Dictionary]) -> void:
    if busy:
        return
    var result: Dictionary = _gather_plans(entries)
    if not str(result["error"]).is_empty():
        if _mode() == "atlas" and compose_enabled.button_pressed:
            _composition_message("导入检查失败：" + str(result["error"]))
        else:
            info.text = "导入检查失败：" + str(result["error"])
        return
    var plans: Array[Dictionary] = result["plans"]
    pending_entries = entries.duplicate(true)
    pending_signature = _signature(plans)
    var descriptions := PackedStringArray()
    for plan_data in plans:
        var destinations := PackedStringArray()
        for item in plan_data["files"].values():
            var detail := str(item["destination"])
            if not str(item.get("replaces", "")).is_empty():
                detail += " （保留旧图：" + str(item["replaces"]) + "）"
            destinations.append(detail)
        var updates: Array = plan_data.get("candidate_updates", [])
        var update_note := "\n将同步保存 %d 个候选 .tres 网格元数据（事务可回退）" % updates.size() \
            if not updates.is_empty() else ""
        var native_frames := str(plan_data.get("native_frames_path", ""))
        descriptions.append("%s → %s\n原绑定：%s\n新绑定：%s\n图片：%s\n动画 SpriteFrames：%s\n原生场景：%s%s" % [
            str(plan_data["mode"]), str(plan_data["target"]),
            str(plan_data.get("current_binding", "（空）")),
            str(plan_data.get("next_binding", "")), ", ".join(destinations),
            native_frames if not native_frames.is_empty() else "旧 Clip 兼容或不涉及动画",
            str(plan_data.get("native_scene_path", "不修改 .tscn")), update_note
        ])
    confirm.dialog_text = "批次 %s 项：\n\n%s\n\n%s" % [
        str(plans.size()), "\n\n".join(descriptions),
        "开始前会为所有 .tres/选定的 .tscn 建立事务备份；失败恢复原文件，新图保留。\n" +
        "导入成功即成为 Resource 当前使用版本；版权及动画视觉验收仍需单独确认。"
    ]
    confirm.popup_centered_ratio(0.8)


func _apply() -> void:
    if busy or pending_entries.is_empty():
        return
    busy = true
    apply_button.disabled = true
    queue_review_button.disabled = true
    var result: Dictionary = _gather_plans(pending_entries)
    if not str(result["error"]).is_empty():
        _finished(str(result["error"]))
        return
    var plans: Array[Dictionary] = result["plans"]
    if _signature(plans) != pending_signature:
        _finished("图片或 Resource 自预检后发生变化，请重新确认。")
        return
    var started: Dictionary = Transaction.begin(plans)
    if not str(started.get("error", "")).is_empty():
        _finished(str(started["error"]))
        return
    var journal: String = str(started["journal"])
    for plan_data in plans:
        var failure: String = Service.copy_images(plan_data["files"])
        if not failure.is_empty():
            _abort_import(journal, failure)
            return
    info.text = "等待 Godot 原生 Importer 处理 %s 项图片..." % str(plans.size())
    var filesystem := EditorInterface.get_resource_filesystem()
    if not filesystem.is_scanning() and not filesystem.is_importing():
        filesystem.scan()
    var ready := false
    for retry in range(150):
        if not is_inside_tree():
            _abort_import(journal, "Dock 已关闭")
            return
        ready = not filesystem.is_scanning() and not filesystem.is_importing()
        if ready:
            for plan_data in plans:
                for item in plan_data["files"].values():
                    if not ResourceLoader.exists(str(item["destination"]), "Texture2D"):
                        ready = false
                        break
                if not ready:
                    break
        if ready:
            break
        await get_tree().create_timer(0.1).timeout
    if not ready:
        _abort_import(journal, "Godot 图片 Importer 超时。请检查导入器输出。")
        return
    for plan_data in plans:
        var failure: String = Service.save_bindings(plan_data)
        if not failure.is_empty():
            _abort_import(journal, failure)
            return
    var committed: String = Transaction.commit(journal)
    if not committed.is_empty():
        _abort_import(journal, committed)
        return
    last_import_log = journal
    undo_import_button.disabled = false
    filesystem.scan()
    pending_entries.clear()
    _finished("批次导入完成（%s 项）：已更新所选 .tres/.tscn；日志 %s" % [str(plans.size()), journal])


func _abort_import(journal: String, reason: String) -> void:
    var recovery: String = Transaction.rollback(journal, true)
    var suffix := "；已恢复 Resource，图片仍保留。" if recovery.is_empty() else "；自动恢复失败：" + recovery
    _finished(reason + suffix)


func _undo_import() -> void:
    if busy or last_import_log.is_empty():
        return
    var result: String = Transaction.rollback(last_import_log)
    if result.is_empty():
        undo_import_button.disabled = true
        last_import_log = ""
        EditorInterface.get_resource_filesystem().scan()
        info.text = "原始 .tres/.tscn 已恢复；新导入图片未删除。重新打开场景可清除缓存。"
    else:
        info.text = "撤销失败：" + result


func _export_mode() -> String:
    return ["all", "character", "scene", "resource"][export_kind.selected]


func _export_kind_changed() -> void:
    var mode := _export_mode()
    export_target_row.visible = mode in ["character", "scene"]
    export_free_row.visible = mode == "resource"
    export_target.clear()
    if mode not in ["character", "scene"]:
        return
    var folders: Array[String] = ["res://data/native/characters"] if mode == "character" else [
        "res://data/maps", "res://data/native/chapters"]
    for folder in folders:
        var dir := DirAccess.open(folder)
        if dir == null:
            continue
        var all_files := Array(DirAccess.get_files_at(folder))
        all_files.sort()
        for file in all_files:
            var path: String = folder.path_join(str(file))
            if not path.ends_with(".tres"):
                continue
            var obj: Resource = ResourceLoader.load(path)
            if mode == "character" and not obj is WuxiaCharacterDefinition:
                continue
            if mode == "scene" and not (obj is WuxiaMapDefinition or obj is WuxiaGridMapDefinition or
                    (obj is WuxiaChapterDefinition and obj.get("scene") is WuxiaChapterSceneDefinition)):
                continue
            var index := export_target.item_count
            export_target.add_item(path.get_file().get_basename())
            export_target.set_item_metadata(index, path)
    if export_target.item_count > 0:
        export_target.select(0)


func _export_resource() -> String:
    var mode := _export_mode()
    if mode == "all":
        return ""
    if mode == "resource":
        return export_free_path.text.strip_edges()
    return str(export_target.get_item_metadata(export_target.selected)) if export_target.selected >= 0 else ""


func _review_export() -> void:
    if busy:
        return
    var planned: Dictionary = Export.plan(_export_mode(), _export_resource(), export_replace.button_pressed)
    if not str(planned.get("error", "")).is_empty():
        export_info.text = "预检失败：" + str(planned["error"])
        return
    var lines := PackedStringArray()
    for item in planned["entries"]:
        if lines.size() >= 16:
            lines.append("…其余条目详见导出日志")
            break
        lines.append("%s：%s → %s" % [
            str(item["action"]), str(item["source"]), str(item["destination"])
        ])
    export_info.text = "共 %s 项；新建 %s、相同 %s、差异替换 %s" % [
        str(planned["entries"].size()), str(planned["creates"]),
        str(planned["identical"]), str(planned["replaces"])
    ]
    if not bool(planned["can_apply"]):
        export_info.text += "。存在冲突，需主动勾选允许覆盖并重新检查。"
        return
    pending_export = planned
    export_confirm.dialog_text = export_info.text + "\n\n" + "\n".join(lines) + \
        "\n\n保留 Godot assets/ 不动；替换生产区已有副本前保存离线备份。"
    export_confirm.popup_centered_ratio(0.8)


func _apply_export() -> void:
    if busy or pending_export.is_empty():
        return
    busy = true
    var outcome: Dictionary = Export.export(pending_export)
    busy = false
    pending_export.clear()
    if not str(outcome.get("error", "")).is_empty():
        export_info.text = "导出失败：" + str(outcome["error"]) + \
            ("。日志：" + str(outcome["journal"]) if outcome.has("journal") else "")
        return
    last_export_log = str(outcome["journal"])
    undo_export_button.disabled = false
    export_info.text = "已导出 %s 项，含内容相同的副本。日志：%s" % [
        str(outcome["count"]), last_export_log
    ]
    _refresh_sources()


func _undo_export() -> void:
    if busy or last_export_log.is_empty():
        return
    var failure: String = Export.rollback(last_export_log)
    if failure.is_empty():
        undo_export_button.disabled = true
        last_export_log = ""
        export_info.text = "导出已撤销；旧副本已恢复，新副本移至事务 recovered-new。"
        _refresh_sources()
    else:
        export_info.text = "导出撤销失败：" + failure


func _finished(message: String) -> void:
    busy = false
    apply_button.disabled = false
    queue_review_button.disabled = queue.is_empty()
    if _mode() == "atlas" and compose_enabled.button_pressed:
        _composition_message(message)
    else:
        info.text = message
