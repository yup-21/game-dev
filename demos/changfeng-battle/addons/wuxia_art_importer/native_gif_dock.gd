@tool
extends ScrollContainer
## Companion dock: explicit action GIFs -> native SpriteFrames.tres.

const Service = preload("res://addons/wuxia_art_importer/native_gif_import.gd")
const Transaction = preload("res://addons/wuxia_art_importer/art_transaction_service.gd")
const Art = preload("res://addons/wuxia_art_importer/art_import_service.gd")

var target: LineEdit
var folder: LineEdit
var mappings: TextEdit
var tall: CheckBox
var status: Label
var action_select: OptionButton
var animation: AnimatedSprite2D
var confirmation: ConfirmationDialog
var undo_button: Button
var undo_dialog: ConfirmationDialog
var pending: Dictionary = {}
var inspected_inputs: String = ""
var last_journal: String = ""


func _ready() -> void:
    name = "Native GIF"
    custom_minimum_size = Vector2(330, 400)
    var column := VBoxContainer.new()
    add_child(column)
    var title := Label.new()
    title.text = "角色原生动画 · GIF → SpriteFrames"
    column.add_child(title)
    var note := Label.new()
    note.text = "GIF 每动作一张；旧 Atlas 仍由 Art Production 导入。预检后确认才写入正式 .tres。"
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(note)
    target = LineEdit.new()
    target.placeholder_text = "res://data/native/characters/shen_changfeng.tres"
    column.add_child(_field("角色 Resource", target))
    folder = LineEdit.new()
    folder.placeholder_text = "art-production/candidates/characters/<id>/actions"
    column.add_child(_field("GIF 文件夹（绝对路径）", folder))
    var scan := Button.new()
    scan.text = "扫描本角色动作 GIF（可编辑映射）"
    scan.pressed.connect(_scan_folder)
    column.add_child(scan)
    mappings = TextEdit.new()
    mappings.custom_minimum_size = Vector2(0, 125)
    mappings.placeholder_text = "idle=/绝对路径/idle.gif\nwalk=/绝对路径/walk.gif"
    column.add_child(_field("显式 action=GIF 路径（每行一组）", mappings))
    var register := Button.new()
    register.text = "登记候选 GIF 的 .tres（不替换正式素材）"
    register.pressed.connect(_register_candidates)
    column.add_child(register)
    tall = CheckBox.new()
    tall.text = "高个统一帧画布 384×288（默认 328×256）"
    column.add_child(tall)
    var check := Button.new()
    check.text = "预检 GIF 并预览原生动画"
    check.pressed.connect(_inspect)
    column.add_child(check)
    action_select = OptionButton.new()
    action_select.item_selected.connect(_select_animation)
    column.add_child(_field("选择预览动作", action_select))
    var viewport_container := SubViewportContainer.new()
    viewport_container.custom_minimum_size = Vector2(0, 260)
    viewport_container.stretch = true
    column.add_child(viewport_container)
    var viewport := SubViewport.new()
    viewport.size = Vector2i(328, 288)
    viewport.transparent_bg = true
    viewport_container.add_child(viewport)
    animation = AnimatedSprite2D.new()
    animation.position = Vector2(164, 144)
    viewport.add_child(animation)
    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(status)
    var import_button := Button.new()
    import_button.text = "确认导入已预览的 GIF（生成正式 SpriteFrames）"
    import_button.pressed.connect(_review)
    column.add_child(import_button)
    confirmation = ConfirmationDialog.new()
    confirmation.title = "确认导入角色原生动画"
    confirmation.confirmed.connect(_apply)
    add_child(confirmation)
    undo_button = Button.new()
    undo_button.text = "撤销本次 GIF 导入"
    undo_button.disabled = true
    undo_button.pressed.connect(func(): undo_dialog.popup_centered())
    column.add_child(undo_button)
    undo_dialog = ConfirmationDialog.new()
    undo_dialog.dialog_text = "恢复角色 .tres、动作 Profile 与 SpriteFrames 的导入前版本？不会删除新图集。"
    undo_dialog.confirmed.connect(_undo)
    add_child(undo_dialog)


func _field(label: String, control: Control) -> VBoxContainer:
    var wrapper := VBoxContainer.new()
    var heading := Label.new()
    heading.text = label
    wrapper.add_child(heading)
    wrapper.add_child(control)
    return wrapper


func _scan_folder() -> void:
    var directory := DirAccess.open(folder.text.strip_edges())
    if directory == null:
        status.text = "无法打开指定 GIF 文件夹"
        return
    var files: Array[String] = []
    directory.list_dir_begin()
    var item := directory.get_next()
    while not item.is_empty():
        if not directory.current_is_dir() and item.to_lower().ends_with(".gif"):
            files.append(item)
        item = directory.get_next()
    directory.list_dir_end()
    files.sort()
    var lines: Array[String] = []
    for filename in files:
        lines.append(filename.get_basename().to_lower() + "=" + \
            folder.text.strip_edges().path_join(filename))
    mappings.text = "\n".join(lines)
    status.text = "发现 %d 张 GIF，请核对每行的动作名称。" % files.size()


func _inspect() -> void:
    pending.clear()
    inspected_inputs = ""
    var candidate := Service.plan(target.text.strip_edges(), mappings.text, tall.button_pressed)
    status.text = str(candidate.get("error", ""))
    if not status.text.is_empty():
        return
    var built := Service.frames_for(candidate, true)
    if not str(built.get("error", "")).is_empty():
        status.text = str(built["error"])
        return
    pending = candidate
    inspected_inputs = _signature()
    animation.sprite_frames = built["frames"]
    action_select.clear()
    var actions: Array = candidate["actions"].keys()
    actions.sort()
    for action in actions:
        action_select.add_item(str(action))
    _select_animation(0)
    var details: Array[String] = []
    for action in actions:
        details.append("%s: %d 帧" % [action, int(candidate["actions"][action]["frames"])])
    status.text = "%s\n将生成 .tres：%s" % [", ".join(details), candidate["native_frames_path"]]


func _review() -> void:
    if pending.is_empty():
        status.text = "请先完成预检并查看动画预览。"
        return
    if inspected_inputs != _signature():
        pending.clear()
        status.text = "目标角色、GIF 映射或尺寸已变化，请重新预检。"
        return
    var details: Array[String] = []
    for action in pending["actions"]:
        details.append("%s: %d 帧" % [action, int(pending["actions"][action]["frames"])])
    confirmation.dialog_text = "确认更新 %s 的原生动画绑定？\n%s\n旧图集保留，可撤销。" % \
        [pending["target"], ", ".join(details)]
    confirmation.popup_centered_ratio(0.7)


func _signature() -> String:
    return target.text.strip_edges() + "\n" + mappings.text + "\n" + str(tall.button_pressed)


func _register_candidates() -> void:
    var result := Service.register_candidates(target.text.strip_edges(), mappings.text)
    status.text = str(result.get("error", "")) if not str(result.get("error", "")).is_empty() \
        else "已登记 %d 个候选 Resource（原图不变）。" % int(result.get("created", 0))


func _select_animation(index: int) -> void:
    if animation.sprite_frames == null or index < 0 or index >= action_select.item_count:
        return
    animation.play(action_select.get_item_text(index))


func _apply() -> void:
    if pending.is_empty():
        return
    if inspected_inputs != _signature():
        status.text = "预检后导入配置发生变化，请重新预检。"
        pending.clear()
        return
    var result := Service.apply(pending)
    status.text = str(result.get("error", ""))
    if status.text.is_empty():
        last_journal = str(result["journal"])
        undo_button.disabled = false
        status.text = "已保存 Godot SpriteFrames：" + str(result["frames_path"]) + \
            "\n可在 Inspector 的 SpriteFrames 编辑器逐帧调整。"
    pending.clear()


func _undo() -> void:
    if last_journal.is_empty():
        return
    var failure: String = Transaction.rollback(last_journal)
    status.text = "已恢复导入前 Resource。" if failure.is_empty() else failure
    if failure.is_empty():
        last_journal = ""
        undo_button.disabled = true
