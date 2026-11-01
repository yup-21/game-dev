@tool
extends ScrollContainer
## Godot editor dock: visual preflight, preview, explicit confirmation, then .tres binding.

const Service = preload("res://addons/wuxia_art_importer/art_import_service.gd")
const Preview = preload("res://addons/wuxia_art_importer/art_preview.gd")
const LABELS := ["角色立绘", "角色动作 Atlas", "分层场景", "UI Atlas", "战斗 VFX"]
const MODES := ["portrait", "atlas", "scene", "ui_atlas", "vfx"]

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
var extra_rows: Dictionary = {}
var extras: Dictionary = {}
var columns: SpinBox
var rows: SpinBox
var feet_x: SpinBox
var feet_y: SpinBox
var facing: CheckBox
var atlas_rows: Array[Control] = []
var action_select: OptionButton
var preview: Control
var info: Label
var apply_button: Button
var confirm: ConfirmationDialog
var picker: FileDialog
var picker_target: LineEdit
var timer: Timer
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
    note.text = "仅编辑器使用；导入后生成原生 .tres，默认 candidate。"
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
    target_row = _labeled("角色卡 / 地图 Resource", targets)
    targets.item_selected.connect(func(_index: int): _refresh_preview())
    asset_id = LineEdit.new()
    asset_id.placeholder_text = "例如 ui.sword_cards"
    id_row = _labeled("WuxiaAssetDefinition ID", asset_id)
    event_kind = LineEdit.new()
    event_kind.placeholder_text = "例如 SWORD_SLASH"
    event_row = _labeled("VFX 事件（可选）", event_kind)
    for layer in ["ground", "foreground", "weather"]:
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

    columns = _number("Atlas 列数", 6, 1, 64)
    rows = _number("Atlas 行数", 4, 1, 64)
    feet_x = _number("脚点偏移 X", 0, -2048, 2048)
    feet_y = _number("脚点偏移 Y", -102, -2048, 2048)
    facing = CheckBox.new()
    facing.text = "原画朝左（不镜像）"
    facing.toggled.connect(func(_value: bool): _refresh_preview())
    body.add_child(facing)
    atlas_rows.append(facing)
    action_select = OptionButton.new()
    for action in WuxiaActorAnimationProfile.REQUIRED_ACTIONS:
        action_select.add_item(action)
    atlas_rows.append(_labeled("动画预览", action_select))
    action_select.item_selected.connect(func(_index: int): _set_action())

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

    confirm = ConfirmationDialog.new()
    confirm.title = "确认 Godot 资源变更"
    confirm.confirmed.connect(_apply)
    add_child(confirm)
    picker = FileDialog.new()
    picker.access = FileDialog.ACCESS_FILESYSTEM
    picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    picker.add_filter("*.png,*.webp,*.jpg,*.jpeg,*.svg", "图像文件")
    picker.file_selected.connect(_on_picked)
    add_child(picker)
    timer = Timer.new()
    timer.wait_time = 0.12
    timer.timeout.connect(_next_frame)
    add_child(timer)
    timer.start()
    _mode_changed()
    _refresh_sources()


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
    target_row.visible = mode in ["portrait", "atlas", "scene"]
    id_row.visible = mode in ["ui_atlas", "vfx"]
    event_row.visible = mode == "vfx"
    for layer in extra_rows:
        extra_rows[layer].visible = mode == "scene"
    for control in atlas_rows:
        control.visible = mode == "atlas"
    _load_targets()
    _refresh_preview()


func _load_targets() -> void:
    targets.clear()
    var mode := _mode()
    var folder := ""
    if mode in ["portrait", "atlas"]:
        folder = "res://data/native/characters"
    elif mode == "scene":
        folder = "res://data/maps"
    if folder.is_empty():
        return
    var dir := DirAccess.open(folder)
    if dir == null:
        return
    var entries := Array(DirAccess.get_files_at(folder))
    entries.sort()
    for filename in entries:
        if not str(filename).ends_with(".tres"):
            continue
        var path := folder.path_join(str(filename))
        var resource := ResourceLoader.load(path)
        if mode == "scene" and not (resource is WuxiaMapDefinition or resource is WuxiaGridMapDefinition):
            continue
        if mode in ["portrait", "atlas"] and not resource is WuxiaCharacterDefinition:
            continue
        var label := str(filename).get_basename()
        if resource is WuxiaContentDefinition:
            label = resource.content_id
        var index := targets.item_count
        targets.add_item(label)
        targets.set_item_metadata(index, path)
    if targets.item_count > 0:
        targets.select(0)


func _browse(line: LineEdit) -> void:
    picker_target = line
    picker.current_dir = Service.production_root()
    picker.popup_centered_ratio(0.7)


func _on_picked(path: String) -> void:
    if picker_target != null:
        picker_target.text = path
        _refresh_preview()


func _fields() -> Dictionary:
    return {
        "asset_id": asset_id.text.strip_edges(),
        "event_kind": event_kind.text.strip_edges(),
        "columns": int(columns.value),
        "rows": int(rows.value),
        "feet_offset": Vector2(feet_x.value, feet_y.value),
        "faces_left": facing.button_pressed,
        "ground": extras["ground"].text.strip_edges(),
        "foreground": extras["foreground"].text.strip_edges(),
        "weather": extras["weather"].text.strip_edges(),
    }


func _refresh_preview() -> void:
    if preview == null:
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
    info.text = "%s × %s | Alpha: %s | SHA-256: %s\n待审批素材不会自动标记 approved" % [
        details["width"], details["height"],
        "是" if details["alpha"] else "否", str(details["sha256"]).substr(0, 12)]
    if mode == "atlas":
        preview.show_atlas(details["texture"], int(columns.value), int(rows.value),
                           Vector2(feet_x.value, feet_y.value))
        _set_action()
    elif mode == "scene":
        var layer_images := {"primary": details["texture"]}
        for layer in extras:
            var layer_path: String = extras[layer].text.strip_edges()
            if not layer_path.is_empty():
                var item: Dictionary = Service.inspect(layer_path)
                if str(item.get("error", "")).is_empty():
                    layer_images[layer] = item["texture"]
        preview.show_scene(layer_images, ResourceLoader.load(_target()) if not _target().is_empty() else null)
    else:
        preview.show_image(details["texture"])


func _set_action() -> void:
    var selected := action_select.get_item_text(action_select.selected) if action_select.selected >= 0 else "idle"
    var profile: WuxiaActorAnimationProfile = null
    if not _target().is_empty():
        var character := ResourceLoader.load(_target()) as WuxiaCharacterDefinition
        if character != null:
            profile = character.animation_profile
    if profile == null:
        profile = ResourceLoader.load("res://data/templates/actor_animation_profile.tres") as WuxiaActorAnimationProfile
    frames = PackedInt32Array([0])
    var clip: WuxiaActorAnimationClip = profile.clip_for(selected) if profile != null else null
    if clip != null and not clip.frames.is_empty():
        frames = clip.frames
        timer.wait_time = 1.0 / clip.loop_fps if clip.loop else 0.15
    current_frame = 0
    if preview != null:
        preview.show_frame(frames[0])


func _next_frame() -> void:
    if _mode() != "atlas" or frames.is_empty() or preview == null:
        return
    current_frame = (current_frame + 1) % frames.size()
    preview.show_frame(frames[current_frame])


func _review() -> void:
    var attempt: Dictionary = Service.plan(_mode(), _selected_source(), _target(), _fields())
    if not str(attempt.get("error", "")).is_empty():
        info.text = "导入检查失败：" + str(attempt["error"])
        return
    var paths := PackedStringArray()
    for file in attempt["files"].values():
        paths.append(str(file["destination"]))
    confirm.dialog_text = "将复制到：\n" + "\n".join(paths) + \
        "\n\n并更新：" + str(attempt["target"]) + \
        ("\nProfile：" + str(attempt["profile_path"]) if attempt.has("profile_path") else "") + \
        "\n已有 .tres 将在 art-production/reviews/import-backups 备份。" + \
        "\n新素材状态为 candidate，不表示已完成美术或授权审核。"
    confirm.popup_centered_ratio(0.75)


func _apply() -> void:
    if busy:
        return
    busy = true
    apply_button.disabled = true
    var planned: Dictionary = Service.plan(_mode(), _selected_source(), _target(), _fields())
    if not str(planned.get("error", "")).is_empty():
        _finished(str(planned["error"]))
        return
    var failure: String = Service.copy_images(planned["files"])
    if not failure.is_empty():
        _finished(failure)
        return
    info.text = "等待 Godot 原生 Importer 处理图像..."
    var filesystem := EditorInterface.get_resource_filesystem()
    if not filesystem.is_scanning() and not filesystem.is_importing():
        filesystem.scan()
    var ready := false
    for retry in range(100):
        if not is_inside_tree():
            return
        ready = not filesystem.is_scanning() and not filesystem.is_importing()
        if ready:
            for file in planned["files"].values():
                if not ResourceLoader.exists(str(file["destination"]), "Texture2D"):
                    ready = false
                    break
        if ready:
            break
        await get_tree().create_timer(0.1).timeout
    if not ready:
        _finished("Godot Importer 超时；保留已复制图片，请重新扫描后再试。")
        return
    failure = Service.save_bindings(planned)
    if failure.is_empty():
        filesystem.scan()
        _finished("导入完成：已更新原生 Resource。请在 Inspector 验收动作与图层。")
    else:
        _finished(failure + "\n已复制的源图片保持不变；原有 Resource 有离线备份。")


func _finished(message: String) -> void:
    busy = false
    apply_button.disabled = false
    info.text = message
