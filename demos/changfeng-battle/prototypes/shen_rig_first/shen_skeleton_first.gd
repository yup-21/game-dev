@tool
extends Node2D
## Skeleton-first Shen Changfeng prototype: no imported character sprites.
## The Godot Bone2D hierarchy is authored in the scene; the JSON contract
## specifies anchors and exact attachment targets for the next art pass.

const CombatScale = preload("res://scripts/combat_scale.gd")
const CONTRACT_PATH := "res://prototypes/shen_rig_first/rig_contract.json"
const MOTIONS := ["idle", "walk", "attack_sword"]
const GROUND_POINT := Vector2(800, 730)

@export var show_skeleton := true
@export var show_attachment_guides := true

var _contract: Dictionary = {}
var _bones: Dictionary = {}
var _player: AnimationPlayer
var _skeleton: Skeleton2D
var _status: Label


func _ready() -> void:
    _skeleton = get_node("Skeleton2D") as Skeleton2D
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
    if not parsed is Dictionary:
        push_error("SHEN_RIG_FIRST: rig_contract.json is invalid")
        return
    _contract = parsed
    _collect_bones(_skeleton)
    for bone in _bones.values():
        # Required by Skeleton2D deformation and consistent rest-pose playback.
        bone.rest = bone.transform
    if not Engine.is_editor_hint():
        _build_animation_player()
        _build_controls()
        play_motion("idle")
    set_process(true)
    queue_redraw()


func _collect_bones(parent: Node) -> void:
    for child in parent.get_children():
        if child is Bone2D:
            _bones[child.name] = child
            _collect_bones(child)


func _process(_delta: float) -> void:
    if show_skeleton or show_attachment_guides:
        queue_redraw()


func _joint(name: String) -> Vector2:
    var bone: Bone2D = _bones.get(name)
    if bone == null:
        return Vector2.ZERO
    return to_local(bone.global_position)


func _draw() -> void:
    # Coordinate system is stable: the ground line is the true 0,0 foot anchor.
    draw_rect(Rect2(Vector2.ZERO, Vector2(1600, 1000)), Color(0.055, 0.065, 0.075), true)
    draw_line(Vector2(390, GROUND_POINT.y), Vector2(1210, GROUND_POINT.y),
        Color(0.54, 0.72, 0.65, 0.8), 2.0)

    if _contract.is_empty() or _bones.is_empty():
        return
    if show_attachment_guides:
        for entry in _contract["parts"]:
            var start := _joint(str(entry["segment_start"]))
            var finish := _joint(str(entry["segment_end"]))
            var width: float = float(entry["guide_width_px"])
            var color := Color(0.18, 0.75, 0.78, 0.10)
            if str(entry["name"]).begins_with("coat") or str(entry["name"]).begins_with("hair"):
                color = Color(0.8, 0.57, 0.23, 0.12)
            # These are guide strokes, not sprites or finished mesh weights.
            draw_line(start, finish, color, width, true)
            draw_circle(_joint(str(entry["attach_to_bone"])), 2.2, Color(0.83, 0.68, 0.30, 0.7))
    if show_skeleton:
        for entry in _contract["bones"]:
            var name := str(entry["name"])
            if not _bones.has(name):
                continue
            var pos := _joint(name)
            if entry["parent"] != null:
                var parent_pos := _joint(str(entry["parent"]))
                draw_line(parent_pos, pos, Color(0.32, 0.82, 1.0, 0.94), 2.5, true)
            draw_circle(pos, 3.2, Color(1.0, 0.78, 0.28))


func _build_animation_player() -> void:
    _player = AnimationPlayer.new()
    _player.name = "AnimationPlayer"
    _player.root_node = NodePath("..")
    add_child(_player)
    var library := AnimationLibrary.new()
    library.add_animation("idle", _idle())
    library.add_animation("walk", _walk())
    library.add_animation("attack_sword", _attack())
    _player.add_animation_library("", library)


func _track(a: Animation, name: String, keys: Array) -> void:
    var node: Bone2D = _bones.get(name)
    if node == null:
        push_error("SHEN_RIG_FIRST: unknown animation bone " + name)
        return
    var id := a.add_track(Animation.TYPE_VALUE)
    var path := str(get_path_to(node)) + ":rotation"
    a.track_set_path(id, NodePath(path))
    a.value_track_set_update_mode(id, Animation.UPDATE_CONTINUOUS)
    for item in keys:
        a.track_insert_key(id, float(item[0]), float(item[1]))


func _animation(length: float, looped: bool) -> Animation:
    var result := Animation.new()
    result.length = length
    result.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
    return result


func _idle() -> Animation:
    var a := _animation(1.2, true)
    _track(a, "Chest", [[0.0, -0.014], [0.6, 0.014], [1.2, -0.014]])
    _track(a, "Head", [[0.0, 0.01], [0.6, -0.012], [1.2, 0.01]])
    _track(a, "HairTip", [[0.0, 0.04], [0.6, -0.04], [1.2, 0.04]])
    _track(a, "CoatFrontTip", [[0.0, 0.02], [0.6, -0.025], [1.2, 0.02]])
    return a


func _walk() -> Animation:
    var a := _animation(0.8, true)
    _track(a, "FrontHip", [[0.0, -0.20], [0.4, 0.20], [0.8, -0.20]])
    _track(a, "RearHip", [[0.0, 0.20], [0.4, -0.20], [0.8, 0.20]])
    _track(a, "FrontKnee", [[0.0, 0.08], [0.4, -0.19], [0.8, 0.08]])
    _track(a, "RearKnee", [[0.0, -0.19], [0.4, 0.08], [0.8, -0.19]])
    _track(a, "FrontShoulder", [[0.0, 0.14], [0.4, -0.14], [0.8, 0.14]])
    _track(a, "RearShoulder", [[0.0, -0.14], [0.4, 0.14], [0.8, -0.14]])
    _track(a, "Chest", [[0.0, 0.025], [0.4, -0.025], [0.8, 0.025]])
    _track(a, "CoatFrontTip", [[0.0, 0.08], [0.4, -0.08], [0.8, 0.08]])
    _track(a, "CoatBackTip", [[0.0, -0.08], [0.4, 0.08], [0.8, -0.08]])
    return a


func _attack() -> Animation:
    var a := _animation(0.70, false)
    # Test the complete wrist-driven sword chain with bare geometry first.
    _track(a, "Waist", [[0.0, 0.0], [0.18, -0.07], [0.38, 0.08], [0.70, 0.0]])
    _track(a, "Chest", [[0.0, -0.02], [0.18, -0.15], [0.38, 0.16], [0.70, 0.0]])
    _track(a, "FrontShoulder", [[0.0, -0.03], [0.18, -0.35], [0.38, 0.28], [0.70, 0.0]])
    _track(a, "FrontElbow", [[0.0, 0.04], [0.18, 0.28], [0.38, -0.22], [0.70, 0.0]])
    _track(a, "FrontWrist", [[0.0, 0.0], [0.18, -0.10], [0.38, 0.28], [0.70, 0.0]])
    _track(a, "SwordGrip", [[0.0, 0.0], [0.18, -0.18], [0.38, 0.38], [0.70, 0.0]])
    _track(a, "RearShoulder", [[0.0, 0.0], [0.18, -0.10], [0.38, 0.13], [0.70, 0.0]])
    _track(a, "FrontHip", [[0.0, 0.0], [0.18, -0.06], [0.38, 0.09], [0.70, 0.0]])
    _track(a, "RearHip", [[0.0, 0.0], [0.18, 0.07], [0.38, -0.07], [0.70, 0.0]])
    _track(a, "CoatFrontTip", [[0.0, 0.0], [0.18, 0.08], [0.38, -0.10], [0.70, 0.0]])
    return a


func play_motion(name: String) -> void:
    if _player == null or not _player.has_animation(name):
        return
    _player.stop()
    for bone in _bones.values():
        bone.rotation = 0.0
    _player.play(name)
    if _status != null:
        _status.text = "骨架预览：" + name


func show_bind_pose() -> void:
    if _player != null:
        _player.stop()
    for bone in _bones.values():
        bone.rotation = 0.0
    queue_redraw()
    if _status != null:
        _status.text = "标准侧身绑定姿势（无美术贴图）"


func _build_controls() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var title := Label.new()
    title.text = "沈长风 · 标准侧身骨架（骨架先行 / 无正式美术）"
    title.position = Vector2(395, 42)
    title.add_theme_font_size_override("font_size", 27)
    layer.add_child(title)
    var controls := HBoxContainer.new()
    controls.position = Vector2(475, 98)
    layer.add_child(controls)
    for option in [["B 绑定姿势", "bind"], ["1 待机", "idle"], ["2 行走", "walk"], ["3 出剑", "attack_sword"]]:
        var button := Button.new()
        button.text = option[0]
        button.custom_minimum_size = Vector2(145, 40)
        if option[1] == "bind":
            button.pressed.connect(show_bind_pose)
        else:
            button.pressed.connect(play_motion.bind(option[1]))
        controls.add_child(button)
    _status = Label.new()
    _status.position = Vector2(680, 152)
    _status.add_theme_font_size_override("font_size", 18)
    layer.add_child(_status)


func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    var key := event as InputEventKey
    if not key.pressed or key.echo:
        return
    match key.keycode:
        KEY_B: show_bind_pose()
        KEY_1: play_motion("idle")
        KEY_2: play_motion("walk")
        KEY_3: play_motion("attack_sword")


func debug_validation() -> Dictionary:
    var bone_report := {}
    var hierarchy_ok := true
    var all_aligned := true
    for entry in _contract.get("bones", []):
        var name := str(entry["name"])
        if not _bones.has(name):
            hierarchy_ok = false
            all_aligned = false
            continue
        var bone: Bone2D = _bones[name]
        var expected: Vector2 = Vector2(float(entry["anchor"][0]), float(entry["anchor"][1]))
        var actual: Vector2 = _skeleton.to_local(bone.global_position)
        bone_report[name] = [actual.x, actual.y]
        if actual.distance_to(expected) > 0.01:
            all_aligned = false
        if entry["parent"] != null and bone.get_parent() != _bones.get(str(entry["parent"])):
            hierarchy_ok = false
    return {
        "bone_count": _bones.size(),
        "part_count": _contract.get("parts", []).size(),
        "hierarchy_ok": hierarchy_ok,
        "anchors_match": all_aligned,
        "root_ground": _skeleton.position == GROUND_POINT,
        "motion_count": _player.get_animation_list().size() if _player != null else 0,
        "anchors": bone_report,
    }
