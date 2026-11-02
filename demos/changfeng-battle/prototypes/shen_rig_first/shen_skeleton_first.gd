@tool
extends Node2D
## A reusable 22-bone humanoid Skeleton2D with optional, independently
## skinned decoration rigs. No hair, coat or sword bones in the body skeleton.

const CONTRACT_PATH := "res://prototypes/shen_rig_first/rig_contract.json"
const MotionKeyposesV2 = preload("res://prototypes/humanoid_rig/motion_keyposes_v2.gd")
const CandidateBinding = preload("res://prototypes/shen_rig_first/candidate_cutout_binding.gd")
const GROUND_POINT := Vector2(800, 730)

@export var enable_hair := true
@export var enable_coat := true
@export var candidate_art_enabled := false
var _candidate_status: Dictionary = {}
@export var show_skeleton := true
@export var show_attachment_guides := true

var _contract: Dictionary = {}
var _bones: Dictionary = {}
var _accessory_bones: Dictionary = {}
var _accessory_rigs: Dictionary = {}
var _sockets: Dictionary = {}
var _player: AnimationPlayer
var _skeleton: Skeleton2D
var _status: Label


func _ready() -> void:
    _skeleton = get_node("Skeleton2D") as Skeleton2D
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
    if not parsed is Dictionary:
        push_error("SHEN_RIG_FIRST: invalid rig contract")
        return
    _contract = parsed
    _collect_bones(_skeleton, _bones)
    for bone in _bones.values():
        bone.rest = bone.transform

    _sockets["SwordGrip"] = _bones["FrontHand"].get_node("WeaponSocket")
    _sockets["SwordBlade"] = _sockets["SwordGrip"].get_node("WeaponTip")
    for item in _contract.get("accessories", []):
        var name := str(item["name"])
        if name == "hair" and not enable_hair:
            continue
        if name == "coat" and not enable_coat:
            continue
        var parent_bone: Bone2D = _bones.get(str(item["parent_bone"]))
        var socket: Marker2D = parent_bone.get_node(str(item["socket"])) as Marker2D
        var packed: PackedScene = load(str(item["scene"])) as PackedScene
        var rig: Skeleton2D = packed.instantiate() as Skeleton2D
        socket.add_child(rig)
        _accessory_rigs[name] = rig
        _collect_bones(rig, _accessory_bones)
        for accessory_bone in _accessory_bones.values():
            accessory_bone.rest = accessory_bone.transform

    if candidate_art_enabled:
        _candidate_status = CandidateBinding.bind_parts(
            self, _bones, _accessory_bones, _sockets, _accessory_rigs)
        if int(_candidate_status.get("count",0)) != 20:
            push_error("SHEN_RIG_FIRST: candidate binding incomplete " + str(_candidate_status))
    if not Engine.is_editor_hint():
        _build_animation_player()
        _build_controls()
        play_motion("idle")
    set_process(true)
    queue_redraw()


func _collect_bones(parent: Node, output: Dictionary) -> void:
    for child in parent.get_children():
        if child is Bone2D:
            output[child.name] = child
            _collect_bones(child, output)


func _process(_delta: float) -> void:
    if show_skeleton or show_attachment_guides:
        queue_redraw()


func _joint(name: String) -> Vector2:
    var node: Node2D
    if _bones.has(name):
        node = _bones[name]
    elif _accessory_bones.has(name):
        node = _accessory_bones[name]
    elif _sockets.has(name):
        node = _sockets[name]
    else:
        return Vector2.ZERO
    return to_local(node.global_position)


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, Vector2(1600, 1000)), Color(0.055, 0.065, 0.075), true)
    draw_line(Vector2(390, GROUND_POINT.y), Vector2(1210, GROUND_POINT.y),
        Color(0.54, 0.72, 0.65, 0.8), 2.0)
    if _contract.is_empty() or _bones.is_empty():
        return

    if show_attachment_guides:
        for part in _contract["parts"]:
            var group := str(part.get("rig_group", "body"))
            if group != "body" and group != "weapon" and not _accessory_rigs.has(group):
                continue
            var start := _joint(str(part["segment_start"]))
            var finish := _joint(str(part["segment_end"]))
            var width := float(part["guide_width_px"])
            var tint := Color(0.20, 0.72, 0.8, 0.12) if group == "body" else Color(0.95, 0.61, 0.25, 0.13)
            draw_line(start, finish, tint, width, true)

    if show_skeleton:
        for entry in _contract["bones"]:
            var name := str(entry["name"])
            if entry["parent"] != null:
                draw_line(_joint(str(entry["parent"])), _joint(name),
                    Color(0.32, 0.82, 1.0, 0.94), 2.5, true)
            draw_circle(_joint(name), 3.0, Color(0.32, 0.82, 1.0))

        for item in _contract.get("accessories", []):
            if not _accessory_rigs.has(str(item["name"])):
                continue
            for entry in item["bones"]:
                var name := str(entry["name"])
                var parent_name := str(entry["parent"]) if entry["parent"] != null else str(item["parent_bone"])
                draw_line(_joint(parent_name), _joint(name),
                    Color(0.98, 0.63, 0.24, 0.88), 2.0, true)
                draw_circle(_joint(name), 2.8, Color(0.98, 0.72, 0.26))

        draw_line(_joint("FrontHand"), _joint("SwordGrip"),
            Color(0.75, 0.77, 0.8, 0.94), 1.5)
        draw_line(_joint("SwordGrip"), _joint("SwordBlade"),
            Color(0.75, 0.77, 0.8, 0.94), 2.0)


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
    var node: Node2D = _bones.get(name, _accessory_bones.get(name))
    if node == null:
        # Decorative animations are optional when their rig is not equipped.
        if name.begins_with("Hair") or name.begins_with("Coat"):
            return
        push_error("SHEN_RIG_FIRST: unknown core bone " + name)
        return
    _rotation_track(a, node, keys)


func _rotation_track(a: Animation, node: Node2D, keys: Array) -> void:
    var id := a.add_track(Animation.TYPE_VALUE)
    a.track_set_path(id, NodePath(str(get_path_to(node)) + ":rotation"))
    a.value_track_set_update_mode(id, Animation.UPDATE_CONTINUOUS)
    for key in keys:
        a.track_insert_key(id, float(key[0]), float(key[1]))


func _animation(length: float, looped: bool) -> Animation:
    var result := Animation.new()
    result.length = length
    result.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
    return result


func _idle() -> Animation:
    return MotionKeyposesV2.idle(self, _bones, _accessory_bones)


func _walk() -> Animation:
    return MotionKeyposesV2.walk(self, _bones, _accessory_bones)


func _attack() -> Animation:
    return MotionKeyposesV2.attack(self, _bones, _accessory_bones, _sockets["SwordGrip"])


func _reset_pose() -> void:
    if _player != null:
        _player.stop()
    # Full rest transforms, not rotation-only: walk and attack animate the
    # pelvis height to keep feet on the ground. That offset must never leak
    # into a different clip or into the exported bind pose.
    for bone in _bones.values():
        bone.transform = bone.rest
    for bone in _accessory_bones.values():
        bone.transform = bone.rest
    _sockets["SwordGrip"].rotation = 0.0


func play_motion(name: String) -> void:
    if _player == null or not _player.has_animation(name):
        return
    _reset_pose()
    _player.play(name)
    if _status != null:
        _status.text = "通用人体 + 可选装饰：" + name


func show_bind_pose() -> void:
    _reset_pose()
    queue_redraw()
    if _status != null:
        _status.text = "标准侧身：蓝色人体骨架，橙色独立装饰"


func _build_controls() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var title := Label.new()
    title.text = "22 骨骼通用人体 / 头发与衣摆独立挂载"
    title.position = Vector2(445, 42)
    title.add_theme_font_size_override("font_size", 27)
    layer.add_child(title)
    var controls := HBoxContainer.new()
    controls.position = Vector2(475, 98)
    layer.add_child(controls)
    for option in [["B 骨架", "bind"], ["1 待机", "idle"], ["2 行走", "walk"], ["3 出剑", "attack_sword"]]:
        var button := Button.new()
        button.text = option[0]
        button.custom_minimum_size = Vector2(145, 40)
        if option[1] == "bind":
            button.pressed.connect(show_bind_pose)
        else:
            button.pressed.connect(play_motion.bind(option[1]))
        controls.add_child(button)
    _status = Label.new()
    _status.position = Vector2(620, 152)
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


func debug_candidate_binding() -> Dictionary:
    return _candidate_status.duplicate(true)


func debug_validation() -> Dictionary:
    var report := {}
    var hierarchy_ok := true
    var anchors_ok := true
    for entry in _contract.get("bones", []):
        var name := str(entry["name"])
        if not _bones.has(name):
            hierarchy_ok = false
            anchors_ok = false
            continue
        var bone: Bone2D = _bones[name]
        var expected := Vector2(float(entry["anchor"][0]), float(entry["anchor"][1]))
        var actual: Vector2 = _skeleton.to_local(bone.global_position)
        report[name] = [actual.x, actual.y]
        if actual.distance_to(expected) > 0.01:
            anchors_ok = false
        if entry["parent"] != null and bone.get_parent() != _bones.get(str(entry["parent"])):
            hierarchy_ok = false

    var decoration_ok := true
    var accessory_deltas: Array = []
    var expected_decoration_count := 0
    for accessory in _contract.get("accessories", []):
        var group := str(accessory["name"])
        if not _accessory_rigs.has(group):
            continue
        var rig: Skeleton2D = _accessory_rigs[group]
        expected_decoration_count += accessory["bones"].size()
        if rig.get_parent() != _bones[str(accessory["parent_bone"])].get_node(str(accessory["socket"])):
            decoration_ok = false
        for entry in accessory["bones"]:
            var name := str(entry["name"])
            if not _accessory_bones.has(name):
                decoration_ok = false
                continue
            var bone: Bone2D = _accessory_bones[name]
            var target := Vector2(float(entry["anchor"][0]), float(entry["anchor"][1]))
            var actual: Vector2 = _skeleton.to_local(bone.global_position)
            if actual.distance_to(target) > 0.01:
                accessory_deltas.append({"name": name, "expected": target, "actual": actual})
                decoration_ok = false
            if entry["parent"] != null and bone.get_parent() != _accessory_bones.get(str(entry["parent"])):
                decoration_ok = false

    var sockets_ok := true
    for name in _contract["sockets"]:
        var entry: Dictionary = _contract["sockets"][name]
        var target := Vector2(float(entry["anchor"][0]), float(entry["anchor"][1]))
        if _skeleton.to_local(_sockets[name].global_position).distance_to(target) > 0.01:
            sockets_ok = false

    return {
        "bone_count": _bones.size(),
        "accessory_bone_count": _accessory_bones.size(),
        "accessory_slots": _accessory_rigs.keys(),
        "part_count": _contract.get("parts", []).size(),
        "hierarchy_ok": hierarchy_ok,
        "anchors_match": anchors_ok,
        "accessories_aligned": decoration_ok and _accessory_bones.size() == expected_decoration_count,
        "accessory_deltas": accessory_deltas,
        "sockets_aligned": sockets_ok,
        "core_is_separate": _skeleton.get_bone_count() == _bones.size(),
        "root_ground": _skeleton.position == GROUND_POINT,
        "motion_count": _player.get_animation_list().size() if _player != null else 0,
        "anchors": report,
    }
