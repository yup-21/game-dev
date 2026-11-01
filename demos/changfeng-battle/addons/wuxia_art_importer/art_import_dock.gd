@tool
extends ScrollContainer
## Godot editor dock: visual preflight, preview, explicit confirmation, then .tres binding.

const Service = preload("res://addons/wuxia_art_importer/art_import_service.gd")
const Preview = preload("res://addons/wuxia_art_importer/art_preview.gd")
const Export = preload("res://addons/wuxia_art_importer/art_export_service.gd")
const Transaction = preload("res://addons/wuxia_art_importer/art_transaction_service.gd")
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
var clip_profile: LineEdit
var atlas_rows: Array[Control] = []
var action_select: OptionButton
var preview: Control
var info: Label
var apply_button: Button
var confirm: ConfirmationDialog
var picker: FileDialog
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
    clip_profile = LineEdit.new()
    clip_profile.placeholder_text = "res://data/art_previews/<character>_pilot_clip_profile.tres (可选)"
    clip_profile.text_changed.connect(func(_value: String): _refresh_preview())
    atlas_rows.append(_labeled("原生动作帧 Profile 模板（可选）", clip_profile))
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
        "clip_profile_path": clip_profile.text.strip_edges(),
        "versioned_replace": versioned.button_pressed,
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
        preview.call("show_atlas", details["texture"], int(columns.value), int(rows.value),
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
        preview.call("show_scene", layer_images, ResourceLoader.load(_target()) if not _target().is_empty() else null)
    else:
        preview.call("show_image", details["texture"])


func _set_action() -> void:
    var selected := action_select.get_item_text(action_select.selected) if action_select.selected >= 0 else "idle"
    var profile: WuxiaActorAnimationProfile = null
    if clip_profile != null and not clip_profile.text.strip_edges().is_empty():
        profile = ResourceLoader.load(clip_profile.text.strip_edges()) as WuxiaActorAnimationProfile
    if profile == null and not _target().is_empty():
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
        preview.call("show_frame", frames[0])


func _next_frame() -> void:
    if _mode() != "atlas" or frames.is_empty() or preview == null:
        return
    current_frame = (current_frame + 1) % frames.size()
    preview.call("show_frame", frames[current_frame])



func _current_entry() -> Dictionary:
    return {"mode": _mode(), "source": _selected_source(), "target": _target(),
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
    var plan_data: Dictionary = Service.plan(str(entry["mode"]), str(entry["source"]),
                                               str(entry["target"]), entry["fields"])
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
        var attempt: Dictionary = Service.plan(str(entry["mode"]), str(entry["source"]),
                                                str(entry["target"]), entry["fields"])
        if not str(attempt.get("error", "")).is_empty():
            return {"error": _describe_entry(entry) + "：" + str(attempt["error"])}
        plans.append(attempt)
    var problem: String = Transaction.validate(plans)
    return {"error": problem, "plans": plans}


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
        descriptions.append("%s → %s\n原绑定：%s\n新绑定：%s\n图片：%s" % [
            str(plan_data["mode"]), str(plan_data["target"]),
            str(plan_data.get("current_binding", "（空）")),
            str(plan_data.get("next_binding", "")), ", ".join(destinations)
        ])
    confirm.dialog_text = "批次 %s 项：\n\n%s\n\n%s" % [
        str(plans.size()), "\n\n".join(descriptions),
        "开始前会为所有 .tres 建立事务备份；失败恢复 .tres，新图保留。\n" +
        "状态保持 candidate，版权及动画验收仍需人工确认。"
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
    _finished("批次导入完成（%s 项）：原生 .tres 已更新；日志 %s" % [str(plans.size()), journal])


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
        info.text = "原始 .tres 已恢复；新导入图片未删除。重新打开 Inspector 可清除缓存。"
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
    var folder := "res://data/native/characters" if mode == "character" else "res://data/maps"
    var all_files := Array(DirAccess.get_files_at(folder))
    all_files.sort()
    for file in all_files:
        var path: String = folder.path_join(str(file))
        if not path.ends_with(".tres"):
            continue
        var obj: Resource = ResourceLoader.load(path)
        if mode == "character" and not obj is WuxiaCharacterDefinition:
            continue
        if mode == "scene" and not obj is WuxiaMapDefinition and not obj is WuxiaGridMapDefinition:
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
    info.text = message
