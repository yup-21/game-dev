extends Node2D
## Isolated technical pilot for Shen Changfeng.
## It deliberately does not replace the production Sprite2D animation path.
## The current side-facing frame is split non-destructively into AtlasTexture
## regions and attached to native Godot Skeleton2D/Bone2D nodes.

const CombatScale = preload("res://scripts/combat_scale.gd")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")

const COLUMNS := 6
const ROWS := 4
const SIDE_IDLE_FRAME := 1
const ALIGNED_SHEET := "res://assets/imported/candidates/2026-11-01/shen_changfeng/sprite_shen_changfeng_atlas_aligned_v03.png"
const FALLBACK_SHEET := "res://assets/imported/candidates/2026-11-01/shen_changfeng/sprite_shen_changfeng_atlas_normalized_v02.png"

var _texture: Texture2D
var _texture_path := ""
var _frame_size := Vector2.ZERO
var _source_origin := Vector2.ZERO
var _source_bounds := Rect2i()
var _rig_scale := 1.0
var _rig: Node2D
var _skeleton: Skeleton2D
var _player: AnimationPlayer
var _status_label: Label
var _bones: Dictionary = {}
var _piece_names: Array[String] = []

func _ready() -> void:
    _load_source()
    if _texture == null:
        push_error("SHEN_BONE2D: source texture missing")
        return
    _build_stage()
    _build_rig()
    _build_animations()
    _build_ui()
    _play("idle")

func _load_source() -> void:
    _texture_path = ALIGNED_SHEET if ResourceLoader.exists(ALIGNED_SHEET) else FALLBACK_SHEET
    _texture = load(_texture_path) as Texture2D
    if _texture == null:
        return
    _frame_size = Vector2(
        float(_texture.get_width()) / float(COLUMNS),
        float(_texture.get_height()) / float(ROWS)
    )
    _source_bounds = VisualScale._opaque_bounds(_texture, COLUMNS, ROWS, SIDE_IDLE_FRAME)
    var foot_y := float(_source_bounds.end.y)
    if _source_bounds.size.y <= 0:
        foot_y = _frame_size.y - 30.0
    _source_origin = Vector2(_frame_size.x * 0.5, foot_y)
    _rig_scale = CombatScale.actor_height_pixels() / maxf(1.0, float(_source_bounds.size.y))

func _build_stage() -> void:
    var background := ColorRect.new()
    background.name = "Background"
    background.position = Vector2.ZERO
    background.size = Vector2(1600, 1000)
    background.color = Color(0.055, 0.07, 0.075, 1.0)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    move_child(background, 0)

    var floor := Line2D.new()
    floor.name = "FootBaseline"
    floor.width = 2.0
    floor.default_color = Color(0.55, 0.62, 0.62, 0.55)
    floor.add_point(Vector2(260, 730))
    floor.add_point(Vector2(1340, 730))
    add_child(floor)

    var reference := Sprite2D.new()
    reference.name = "OriginalSideReference"
    reference.texture = _texture
    reference.hframes = COLUMNS
    reference.vframes = ROWS
    reference.frame = SIDE_IDLE_FRAME
    reference.centered = true
    reference.scale = Vector2.ONE * _rig_scale
    reference.offset = Vector2(
        0.0,
        _frame_size.y * 0.5 - _source_origin.y
    )
    reference.position = Vector2(500, 730)
    reference.modulate = Color(1, 1, 1, 0.72)
    add_child(reference)

    var left_label := Label.new()
    left_label.text = "原始侧身帧（参考）"
    left_label.position = Vector2(410, 770)
    left_label.add_theme_font_size_override("font_size", 22)
    add_child(left_label)

    var right_label := Label.new()
    right_label.text = "Godot Skeleton2D / Bone2D 拆件"
    right_label.position = Vector2(825, 770)
    right_label.add_theme_font_size_override("font_size", 22)
    add_child(right_label)

func _build_rig() -> void:
    _rig = Node2D.new()
    _rig.name = "Rig"
    _rig.position = Vector2(980, 730)
    _rig.scale = Vector2.ONE * _rig_scale
    add_child(_rig)

    _skeleton = Skeleton2D.new()
    _skeleton.name = "Skeleton2D"
    _rig.add_child(_skeleton)

    var hips := _add_bone("Hips", _skeleton, Vector2(128, 150), Vector2.ZERO)
    var spine := _add_bone("Spine", hips, Vector2(132, 112), Vector2(128, 150))
    var head := _add_bone("Head", spine, Vector2(136, 99), Vector2(132, 112))
    var arm_back := _add_bone("ArmBack", spine, Vector2(108, 116), Vector2(132, 112))
    var arm_front := _add_bone("ArmFront", spine, Vector2(151, 117), Vector2(132, 112))
    var leg_back := _add_bone("LegBack", hips, Vector2(115, 164), Vector2(128, 150))
    var leg_front := _add_bone("LegFront", hips, Vector2(140, 164), Vector2(128, 150))
    var skirt := _add_bone("Skirt", hips, Vector2(128, 151), Vector2(128, 150))
    var sword := _add_bone("Sword", arm_front, Vector2(161, 139), Vector2(151, 117))

    _add_piece("HeadPiece", head, SIDE_IDLE_FRAME, Rect2(105, 49, 70, 67), Vector2(136, 99), 8)
    _add_piece("TorsoPiece", spine, SIDE_IDLE_FRAME, Rect2(89, 96, 88, 78), Vector2(132, 112), 4)
    _add_piece("ArmBackPiece", arm_back, SIDE_IDLE_FRAME, Rect2(70, 101, 61, 67), Vector2(108, 116), 2)
    _add_piece("ArmFrontPiece", arm_front, SIDE_IDLE_FRAME, Rect2(130, 101, 60, 69), Vector2(151, 117), 7)
    _add_piece("LegBackPiece", leg_back, SIDE_IDLE_FRAME, Rect2(83, 154, 56, 74), Vector2(115, 164), 1)
    _add_piece("LegFrontPiece", leg_front, SIDE_IDLE_FRAME, Rect2(116, 153, 61, 75), Vector2(140, 164), 3)
    _add_piece("SkirtPiece", skirt, SIDE_IDLE_FRAME, Rect2(68, 130, 111, 98), Vector2(128, 151), 5)

    # The resting side frame keeps the sword close to the body, so this pilot
    # borrows only the thin visible sword strip from an existing attack frame.
    # It remains original project art; no new painted asset is introduced.
    _add_piece("SwordPiece", sword, 7, Rect2(139, 116, 117, 24), Vector2(148, 129), 9)
    sword.rotation = 1.55

func _add_bone(name: String, parent: Node, source_pivot: Vector2, parent_source_pivot: Vector2) -> Bone2D:
    var bone := Bone2D.new()
    bone.name = name
    if parent is Skeleton2D:
        bone.position = source_pivot - _source_origin
    else:
        bone.position = source_pivot - parent_source_pivot
    parent.add_child(bone)
    _bones[name] = bone
    return bone

func _add_piece(name: String, bone: Bone2D, frame_index: int, local_region: Rect2,
        source_pivot: Vector2, z: int) -> void:
    var atlas := AtlasTexture.new()
    atlas.atlas = _texture
    var frame_x := float(frame_index % COLUMNS) * _frame_size.x
    var frame_y := float(frame_index / COLUMNS) * _frame_size.y
    atlas.region = Rect2(
        Vector2(frame_x, frame_y) + local_region.position,
        local_region.size
    )
    var sprite := Sprite2D.new()
    sprite.name = name
    sprite.texture = atlas
    sprite.centered = true
    sprite.position = local_region.get_center() - source_pivot
    sprite.z_index = z
    bone.add_child(sprite)
    _piece_names.append(name)

func _build_animations() -> void:
    _player = AnimationPlayer.new()
    _player.name = "AnimationPlayer"
    _player.root_node = NodePath("..")
    add_child(_player)

    var library := AnimationLibrary.new()
    library.add_animation("idle", _idle_animation())
    library.add_animation("walk", _walk_animation())
    library.add_animation("attack_sword", _attack_animation())
    library.add_animation("guard", _guard_animation())
    _player.add_animation_library("", library)

func _idle_animation() -> Animation:
    var anim := _new_animation(1.2, true)
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Spine:rotation", [[0.0, -0.015], [0.6, 0.025], [1.2, -0.015]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Spine/Head:rotation", [[0.0, 0.012], [0.6, -0.018], [1.2, 0.012]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Skirt:rotation", [[0.0, 0.025], [0.6, -0.035], [1.2, 0.025]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Spine/ArmFront:rotation", [[0.0, 0.01], [0.6, -0.025], [1.2, 0.01]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Spine/ArmFront/Sword:rotation", [[0.0, 1.55], [0.6, 1.50], [1.2, 1.55]])
    return anim

func _walk_animation() -> Animation:
    var anim := _new_animation(0.8, true)
    _add_value_track(anim, "Rig/Skeleton2D/Hips:rotation", [[0.0, -0.02], [0.2, 0.025], [0.4, -0.02], [0.6, 0.025], [0.8, -0.02]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/LegBack:rotation", [[0.0, 0.26], [0.4, -0.24], [0.8, 0.26]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/LegFront:rotation", [[0.0, -0.24], [0.4, 0.26], [0.8, -0.24]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Spine/ArmBack:rotation", [[0.0, -0.16], [0.4, 0.17], [0.8, -0.16]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Spine/ArmFront:rotation", [[0.0, 0.17], [0.4, -0.15], [0.8, 0.17]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Spine:rotation", [[0.0, -0.035], [0.4, 0.04], [0.8, -0.035]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Skirt:rotation", [[0.0, -0.075], [0.4, 0.085], [0.8, -0.075]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Spine/ArmFront/Sword:rotation", [[0.0, 1.52], [0.4, 1.58], [0.8, 1.52]])
    return anim

func _attack_animation() -> Animation:
    var anim := _new_animation(0.58, false)
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Spine:rotation", [[0.0, 0.0], [0.16, -0.16], [0.36, 0.18], [0.58, 0.0]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Spine/ArmBack:rotation", [[0.0, 0.0], [0.16, 0.20], [0.36, -0.12], [0.58, 0.0]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Spine/ArmFront:rotation", [[0.0, 0.02], [0.16, -0.72], [0.36, 0.42], [0.58, 0.03]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Spine/ArmFront/Sword:rotation", [[0.0, 1.55], [0.16, -1.10], [0.36, -0.05], [0.58, 1.35]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Skirt:rotation", [[0.0, 0.0], [0.16, 0.08], [0.36, -0.12], [0.58, 0.0]])
    return anim

func _guard_animation() -> Animation:
    var anim := _new_animation(1.0, true)
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Spine:rotation", [[0.0, -0.04], [0.5, -0.065], [1.0, -0.04]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Spine/Head:rotation", [[0.0, 0.035], [0.5, 0.015], [1.0, 0.035]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Spine/ArmBack:rotation", [[0.0, 0.18], [0.5, 0.15], [1.0, 0.18]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Spine/ArmFront:rotation", [[0.0, -0.56], [0.5, -0.60], [1.0, -0.56]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Spine/ArmFront/Sword:rotation", [[0.0, -1.06], [0.5, -1.11], [1.0, -1.06]])
    _add_value_track(anim, "Rig/Skeleton2D/Hips/Skirt:rotation", [[0.0, 0.03], [0.5, -0.02], [1.0, 0.03]])
    return anim

func _new_animation(length: float, looped: bool) -> Animation:
    var anim := Animation.new()
    anim.length = length
    anim.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
    return anim

func _add_value_track(anim: Animation, path: String, keys: Array) -> void:
    var track := anim.add_track(Animation.TYPE_VALUE)
    anim.track_set_path(track, NodePath(path))
    anim.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
    for key in keys:
        anim.track_insert_key(track, float(key[0]), key[1])

func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "PreviewUI"
    add_child(canvas)

    var title := Label.new()
    title.text = "沈长风 · Godot 原生 2D 骨骼小规模验证"
    title.position = Vector2(470, 32)
    title.add_theme_font_size_override("font_size", 30)
    canvas.add_child(title)

    var controls := HBoxContainer.new()
    controls.position = Vector2(510, 88)
    controls.add_theme_constant_override("separation", 12)
    canvas.add_child(controls)
    var entries := [
        ["1 待机", "idle"],
        ["2 行走", "walk"],
        ["3 出剑", "attack_sword"],
        ["4 格挡", "guard"],
    ]
    for entry in entries:
        var button := Button.new()
        button.text = entry[0]
        button.custom_minimum_size = Vector2(125, 42)
        button.pressed.connect(_play.bind(entry[1]))
        controls.add_child(button)

    _status_label = Label.new()
    _status_label.position = Vector2(575, 145)
    _status_label.add_theme_font_size_override("font_size", 20)
    canvas.add_child(_status_label)

    var note := Label.new()
    note.text = "技术验证：当前源图不是骨骼专用分层素材，遮挡处只能做矩形近似拆件；脚点基准保持在同一世界 Y，不改正式角色系统。"
    note.position = Vector2(300, 915)
    note.add_theme_font_size_override("font_size", 18)
    canvas.add_child(note)

func _play(animation_name: String) -> void:
    if _player == null or not _player.has_animation(animation_name):
        return
    _player.play(animation_name)
    if _status_label != null:
        _status_label.text = "当前动作：%s    源：%s" % [animation_name, _texture_path.get_file()]

func _unhandled_key_input(event: InputEvent) -> void:
    if not event.pressed:
        return
    match event.keycode:
        KEY_1:
            _play("idle")
        KEY_2:
            _play("walk")
        KEY_3:
            _play("attack_sword")
        KEY_4:
            _play("guard")

func debug_piece_names() -> Array[String]:
    return _piece_names.duplicate()

func debug_source_frame() -> int:
    return SIDE_IDLE_FRAME

func debug_source_texture_path() -> String:
    return _texture_path

func debug_rendered_reference_height() -> float:
    return float(_source_bounds.size.y) * _rig_scale

func debug_animation_names() -> PackedStringArray:
    if _player == null:
        return PackedStringArray()
    return _player.get_animation_list()

func debug_anchor_tracks_are_safe() -> bool:
    if _player == null:
        return false
    for animation_name in ["idle", "walk", "attack_sword", "guard"]:
        var anim := _player.get_animation(animation_name)
        if anim == null:
            return false
        for track in range(anim.get_track_count()):
            var path := str(anim.track_get_path(track))
            if path == "Rig:position" or path == "Rig/Skeleton2D:position":
                return false
    return true
