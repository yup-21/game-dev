extends Node2D
## Shen Changfeng Bone2D v3 bind-first validation.
## Uses purpose-built cutout material, Polygon2D skinning for hair/robe,
## and action-specific swap attachments for large sword poses.

const CombatScale = preload("res://scripts/combat_scale.gd")
const ATLAS_PARTS := [
    "res://prototypes/shen_bone2d_v2/atlas.b64.00",
    "res://prototypes/shen_bone2d_v2/atlas.b64.01",
    "res://prototypes/shen_bone2d_v2/atlas.b64.02",
    "res://prototypes/shen_bone2d_v2/atlas.b64.03",
]
# All cutouts and pivots are registered in the atlas' native pixel units.
# (0, 0) is the grounded right-facing actor foot anchor, not a source-sheet
# coordinate. Scale is applied exactly once by RigV3 to reach 200px in-game.
const ART_SCALE := 1.0
const SOURCE_ORIGIN := Vector2.ZERO
const SOURCE_HEIGHT := 201.0
const REGIONS := {
    "robe_left": Rect2(4, 4, 43, 108),
    "robe_right": Rect2(51, 4, 44, 108),
    "robe_inner": Rect2(99, 4, 57, 99),
    "hair_back": Rect2(160, 4, 49, 98),
    "guard_arms": Rect2(213, 4, 62, 86),
    "arm_front": Rect2(279, 4, 27, 75),
    "arm_back": Rect2(310, 4, 38, 74),
    "robe_flare_mid": Rect2(352, 4, 52, 70),
    "torso_guard": Rect2(408, 4, 51, 64),
    "torso_attack": Rect2(4, 116, 59, 62),
    "torso": Rect2(67, 116, 40, 57),
    "hair_motion": Rect2(111, 116, 78, 53),
    "leg_extend": Rect2(193, 116, 83, 44),
    "leg_crouch": Rect2(280, 116, 38, 42),
    "attack_swing": Rect2(322, 116, 125, 38),
    "head": Rect2(451, 116, 29, 36),
    "pelvis": Rect2(4, 182, 38, 35),
    "thigh_front": Rect2(46, 182, 17, 34),
    "thigh_back": Rect2(67, 182, 16, 34),
    "shin_front": Rect2(87, 182, 13, 32),
    "shin_back": Rect2(104, 182, 13, 32),
    "belt": Rect2(121, 182, 38, 29),
    "foot_front": Rect2(163, 182, 15, 19),
    "foot_back": Rect2(182, 182, 10, 18),
}
# Single canonical side-view bind-pose registration, relative to the foot.
# Every component is top-left registered; no references to the concept PNG.
const PLACEMENTS := {
    "robe_left": Vector2(-43, -111),
    "robe_right": Vector2(5, -111),
    "robe_inner": Vector2(-26, -103),
    "hair_back": Vector2(-42, -201),
    "guard_arms": Vector2(-18, -205),
    "arm_front": Vector2(0, -151),
    "arm_back": Vector2(-40, -159),
    "robe_flare_mid": Vector2(-16, -106),
    "torso_guard": Vector2(-21, -164),
    "torso_attack": Vector2(-25, -163),
    "torso": Vector2(-20, -163),
    "hair_motion": Vector2(-50, -199),
    "leg_extend": Vector2(-57, -44),
    "leg_crouch": Vector2(11, -42),
    "attack_swing": Vector2(-2, -134),
    "head": Vector2(-5, -184),
    "pelvis": Vector2(-20, -104),
    "thigh_front": Vector2(11, -91),
    "thigh_back": Vector2(-15, -91),
    "shin_front": Vector2(12, -59),
    "shin_back": Vector2(-14, -59),
    "belt": Vector2(-19, -107),
    "foot_front": Vector2(14, -19),
    "foot_back": Vector2(-16, -19),
}

var _texture: ImageTexture
var _rig: Node2D
var _skeleton: Skeleton2D
var _player: AnimationPlayer
var _status_label: Label
var _bones: Dictionary = {}
var _neutral_arms: Array[CanvasItem] = []
var _attack_sword_piece: Sprite2D
var _hair_mesh: Polygon2D
var _mesh_nodes: Array[Polygon2D] = []
var _bind_overlay: Node2D
var _bind_lines: Dictionary = {}
var _bind_markers: Dictionary = {}


func _ready() -> void:
    _texture = _load_embedded_atlas()
    if _texture == null:
        push_error("SHEN_BONE2D_V3: failed to decode embedded cutout atlas")
        return
    _build_stage()
    _build_rig()
    _build_animations()
    _build_ui()
    _play("idle")


func _load_embedded_atlas() -> ImageTexture:
    var encoded := ""
    for path in ATLAS_PARTS:
        if not FileAccess.file_exists(path):
            push_error("SHEN_BONE2D_V3: missing atlas chunk " + path)
            return null
        encoded += FileAccess.get_file_as_string(path).strip_edges()
    var bytes := Marshalls.base64_to_raw(encoded)
    var image := Image.new()
    if image.load_webp_from_buffer(bytes) != OK:
        push_error("SHEN_BONE2D_V3: invalid WebP payload")
        return null
    if image.get_size() != Vector2i(512, 221):
        push_error("SHEN_BONE2D_V3: unexpected atlas size " + str(image.get_size()))
        return null
    # A stray detached hem fragment was present above the attack blade
    # in the generated sheet. Remove only that fragment, not the sword.
    image.fill_rect(Rect2i(365, 116, 70, 9), Color.TRANSPARENT)
    return ImageTexture.create_from_image(image)


func _build_stage() -> void:
    var background := ColorRect.new()
    background.name = "Background"
    background.size = Vector2(1600, 1000)
    background.color = Color(0.045, 0.058, 0.065, 1.0)
    # Z-index takes precedence over child insertion order. Without this,
    # all deliberately negative-depth pieces (back hair, back arm, rear robe)
    # disappear *behind the opaque background*.
    background.z_index = -100
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    move_child(background, 0)

    var floor := Line2D.new()
    floor.name = "FootBaseline"
    floor.width = 2.0
    floor.default_color = Color(0.58, 0.68, 0.66, 0.55)
    floor.z_index = 20
    floor.add_point(Vector2(420, 730))
    floor.add_point(Vector2(1180, 730))
    add_child(floor)

    var tag := Label.new()
    tag.text = "V3 / 绑定优先 · 三段基础动作"
    tag.position = Vector2(625, 775)
    tag.add_theme_font_size_override("font_size", 22)
    add_child(tag)


func _build_rig() -> void:
    _rig = Node2D.new()
    _rig.name = "RigV3"
    _rig.position = Vector2(800, 730)
    _rig.scale = Vector2.ONE * (CombatScale.actor_height_pixels() / SOURCE_HEIGHT)
    add_child(_rig)

    _skeleton = Skeleton2D.new()
    _skeleton.name = "Skeleton2D"
    _rig.add_child(_skeleton)

    var hips := _add_bone("Hips", _skeleton, Vector2(0, -104) * ART_SCALE, SOURCE_ORIGIN)
    var spine := _add_bone("Spine", hips, Vector2(0, -141) * ART_SCALE, Vector2(0, -104) * ART_SCALE)
    var head := _add_bone("Head", spine, Vector2(9, -162) * ART_SCALE, Vector2(0, -141) * ART_SCALE)
    var hair_root := _add_bone("HairRoot", head, Vector2(-16, -189) * ART_SCALE, Vector2(9, -162) * ART_SCALE)
    _add_bone("HairTip", hair_root, Vector2(-29, -118) * ART_SCALE, Vector2(-16, -189) * ART_SCALE)
    var arm_back := _add_bone("ArmBack", spine, Vector2(-23, -153) * ART_SCALE, Vector2(0, -141) * ART_SCALE)
    var arm_front := _add_bone("ArmFront", spine, Vector2(12, -149) * ART_SCALE, Vector2(0, -141) * ART_SCALE)
    var leg_back := _add_bone("LegBack", hips, Vector2(-7, -89) * ART_SCALE, Vector2(0, -104) * ART_SCALE)
    var shin_back := _add_bone("ShinBack", leg_back, Vector2(-7, -57) * ART_SCALE, Vector2(-7, -89) * ART_SCALE)
    _add_bone("FootBack", shin_back, Vector2(-7, -19) * ART_SCALE, Vector2(-7, -57) * ART_SCALE)
    var leg_front := _add_bone("LegFront", hips, Vector2(18, -89) * ART_SCALE, Vector2(0, -104) * ART_SCALE)
    var shin_front := _add_bone("ShinFront", leg_front, Vector2(18, -57) * ART_SCALE, Vector2(18, -89) * ART_SCALE)
    _add_bone("FootFront", shin_front, Vector2(18, -19) * ART_SCALE, Vector2(18, -57) * ART_SCALE)
    var skirt_root := _add_bone("SkirtRoot", hips, Vector2(0, -107) * ART_SCALE, Vector2(0, -104) * ART_SCALE)
    _add_bone("SkirtTipLeft", skirt_root, Vector2(-26, -10) * ART_SCALE, Vector2(0, -107) * ART_SCALE)
    _add_bone("SkirtTipCenter", skirt_root, Vector2(0, -7) * ART_SCALE, Vector2(0, -107) * ART_SCALE)
    _add_bone("SkirtTipRight", skirt_root, Vector2(29, -10) * ART_SCALE, Vector2(0, -107) * ART_SCALE)

    for bone in _bones.values():
        bone.rest = bone.transform

    # The baked torso includes a dark rear armhole. Render the rear sleeve
    # above the torso so the sleeve covers the hole instead of showing a gap.
    var back_arm_sprite := _add_rigid_piece("ArmBackPiece", arm_back, "arm_back", Vector2(-23, -153) * ART_SCALE, 3)
    var torso_sprite := _add_rigid_piece("TorsoPiece", spine, "torso", Vector2(0, -141) * ART_SCALE, 2)
    var pelvis_sprite := _add_rigid_piece("PelvisPiece", hips, "pelvis", Vector2(0, -104) * ART_SCALE, 1)
    var belt_sprite := _add_rigid_piece("BeltPiece", hips, "belt", Vector2(0, -104) * ART_SCALE, 5)
    var front_arm_sprite := _add_rigid_piece("ArmFrontPiece", arm_front, "arm_front", Vector2(12, -149) * ART_SCALE, 7)
    var head_sprite := _add_rigid_piece("HeadPiece", head, "head", Vector2(9, -162) * ART_SCALE, 8)
    # Head remains visible for attack/guard swaps; only the neutral torso/arms are replaced.
    _neutral_arms.assign([back_arm_sprite, front_arm_sprite])

    var tb := _add_rigid_piece("ThighBackPiece", leg_back, "thigh_back", Vector2(-7, -89) * ART_SCALE, -5)
    var sb := _add_rigid_piece("ShinBackPiece", shin_back, "shin_back", Vector2(-7, -57) * ART_SCALE, -5)
    var fb := _add_rigid_piece("FootBackPiece", _bones["FootBack"], "foot_back", Vector2(-7, -19) * ART_SCALE, -5)
    var tf := _add_rigid_piece("ThighFrontPiece", leg_front, "thigh_front", Vector2(18, -89) * ART_SCALE, 3)
    var sf := _add_rigid_piece("ShinFrontPiece", shin_front, "shin_front", Vector2(18, -57) * ART_SCALE, 3)
    var ff := _add_rigid_piece("FootFrontPiece", _bones["FootFront"], "foot_front", Vector2(18, -19) * ART_SCALE, 6)

    _hair_mesh = _add_weighted_piece(
        "HairMesh", "hair_back", PLACEMENTS["hair_back"], -8,
        "Hips/Spine/Head/HairRoot", "Hips/Spine/Head/HairRoot/HairTip")
    _add_weighted_piece(
        "RobeLeftMesh", "robe_left", PLACEMENTS["robe_left"], -1,
        "Hips/SkirtRoot", "Hips/SkirtRoot/SkirtTipLeft")
    _add_weighted_piece(
        "RobeInnerMesh", "robe_inner", PLACEMENTS["robe_inner"], 0,
        "Hips/SkirtRoot", "Hips/SkirtRoot/SkirtTipCenter")
    _add_weighted_piece(
        "RobeRightMesh", "robe_right", PLACEMENTS["robe_right"], 4,
        "Hips/SkirtRoot", "Hips/SkirtRoot/SkirtTipRight")

    # The sword arm remains a child of ArmFront; torso and legs never swap.
    _attack_sword_piece = _add_rigid_piece(
        "AttackSwordPiece", arm_front, "attack_swing",
        Vector2(12, -149) * ART_SCALE, 9)
    _attack_sword_piece.visible = false
    _create_bind_overlay()


func _create_bind_overlay() -> void:
    _bind_overlay = Node2D.new()
    _bind_overlay.name = "BindOverlay"
    _bind_overlay.z_index = 50
    _bind_overlay.visible = false
    _rig.add_child(_bind_overlay)
    for name in _bones.keys():
        var bone: Bone2D = _bones[name]
        if not bone.get_parent() is Bone2D:
            continue
        var line := Line2D.new()
        line.width = 1.75
        line.default_color = Color(0.28, 0.88, 1.0, 0.95)
        line.add_point(Vector2.ZERO)
        line.add_point(Vector2.ZERO)
        _bind_overlay.add_child(line)
        _bind_lines[name] = line
        var joint := Line2D.new()
        joint.width = 1.4
        joint.default_color = Color(1.0, 0.78, 0.28)
        joint.closed = true
        for index in range(8):
            var theta := TAU * float(index) / 8.0
            joint.add_point(Vector2(cos(theta), sin(theta)) * 3.5)
        _bind_overlay.add_child(joint)
        _bind_markers[name] = joint


func _process(_delta: float) -> void:
    if _bind_overlay == null or not _bind_overlay.visible:
        return
    for name in _bind_lines.keys():
        var bone: Bone2D = _bones[name]
        var parent: Bone2D = bone.get_parent() as Bone2D
        var line: Line2D = _bind_lines[name]
        line.set_point_position(0, _bind_overlay.to_local(parent.global_position))
        line.set_point_position(1, _bind_overlay.to_local(bone.global_position))
        var marker: Line2D = _bind_markers[name]
        marker.position = _bind_overlay.to_local(bone.global_position)


func debug_show_bind_pose(show: bool) -> void:
    _player.stop()
    for bone in _bones.values():
        bone.rotation = 0.0
    _set_visual_mode("idle")
    _bind_overlay.visible = show
    _process(0.0)


func _toggle_bind_overlay() -> void:
    debug_show_bind_pose(not _bind_overlay.visible)


func _add_bone(name: String, parent: Node, source_pivot: Vector2, parent_pivot: Vector2) -> Bone2D:
    var bone := Bone2D.new()
    bone.name = name
    bone.position = source_pivot - parent_pivot
    parent.add_child(bone)
    _bones[name] = bone
    return bone


func _atlas_texture(piece: String) -> AtlasTexture:
    var atlas := AtlasTexture.new()
    atlas.atlas = _texture
    atlas.region = REGIONS[piece]
    return atlas


func _add_rigid_piece(name: String, bone: Bone2D, piece: String, pivot: Vector2, z: int) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.name = name
    sprite.texture = _atlas_texture(piece)
    sprite.centered = true
    var rect: Rect2 = REGIONS[piece]
    sprite.position = PLACEMENTS[piece] + rect.size * 0.5 - pivot
    sprite.z_index = z
    bone.add_child(sprite)
    return sprite


func _add_free_piece(parent: Node2D, name: String, piece: String, top_left: Vector2, z: int) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.name = name
    sprite.texture = _atlas_texture(piece)
    var local_pivot := Vector2.ZERO
    if piece == "attack_swing":
        # Rotate around the grip, not around the corner of a 125px-wide slice.
        local_pivot = Vector2(32, 26)
    sprite.centered = local_pivot != Vector2.ZERO
    if sprite.centered:
        var region: Rect2 = REGIONS[piece]
        sprite.offset = region.size * 0.5 - local_pivot
        sprite.position = top_left + local_pivot - SOURCE_ORIGIN
    else:
        sprite.position = top_left - SOURCE_ORIGIN
    sprite.z_index = z
    parent.add_child(sprite)
    return sprite


func _add_weighted_piece(name: String, piece: String, top_left: Vector2, z: int,
        root_bone_path: String, tip_bone_path: String) -> Polygon2D:
    var mesh := Polygon2D.new()
    mesh.name = name
    mesh.texture = _texture
    mesh.skeleton = NodePath("../Skeleton2D")
    mesh.z_index = z
    var r: Rect2 = REGIONS[piece]
    var p := top_left - SOURCE_ORIGIN
    var w := r.size.x
    var h := r.size.y
    mesh.polygon = PackedVector2Array([
        p,
        p + Vector2(w, 0),
        p + Vector2(w, h * 0.5),
        p + Vector2(w, h),
        p + Vector2(0, h),
        p + Vector2(0, h * 0.5),
    ])
    mesh.uv = PackedVector2Array([
        r.position,
        r.position + Vector2(w, 0),
        r.position + Vector2(w, h * 0.5),
        r.position + Vector2(w, h),
        r.position + Vector2(0, h),
        r.position + Vector2(0, h * 0.5),
    ])
    mesh.add_bone(NodePath(root_bone_path), PackedFloat32Array([1.0, 1.0, 0.55, 0.0, 0.0, 0.55]))
    mesh.add_bone(NodePath(tip_bone_path), PackedFloat32Array([0.0, 0.0, 0.45, 1.0, 1.0, 0.45]))
    _rig.add_child(mesh)
    _mesh_nodes.append(mesh)
    return mesh


func _build_animations() -> void:
    _player = AnimationPlayer.new()
    _player.name = "AnimationPlayer"
    _player.root_node = NodePath("..")
    add_child(_player)
    var library := AnimationLibrary.new()
    library.add_animation("idle", _idle_animation())
    library.add_animation("walk", _walk_animation())
    library.add_animation("attack_sword", _attack_animation())
    _player.add_animation_library("", library)


func _idle_animation() -> Animation:
    var a := _new_animation(1.2, true)
    _track(a, "RigV3/Skeleton2D/Hips/Spine:rotation", [[0.0, -0.012], [0.6, 0.018], [1.2, -0.012]])
    _track(a, "RigV3/Skeleton2D/Hips/Spine/Head:rotation", [[0.0, 0.01], [0.6, -0.015], [1.2, 0.01]])
    _track(a, "RigV3/Skeleton2D/Hips/Spine/Head/HairRoot/HairTip:rotation", [[0.0, 0.04], [0.6, -0.05], [1.2, 0.04]])
    _track(a, "RigV3/Skeleton2D/Hips/SkirtRoot/SkirtTipLeft:rotation", [[0.0, -0.025], [0.6, 0.035], [1.2, -0.025]])
    _track(a, "RigV3/Skeleton2D/Hips/SkirtRoot/SkirtTipRight:rotation", [[0.0, 0.025], [0.6, -0.035], [1.2, 0.025]])
    return a


func _walk_animation() -> Animation:
    var a := _new_animation(0.8, true)
    _track(a, "RigV3/Skeleton2D/Hips/LegBack:rotation", [[0.0, 0.22], [0.4, -0.22], [0.8, 0.22]])
    _track(a, "RigV3/Skeleton2D/Hips/LegFront:rotation", [[0.0, -0.22], [0.4, 0.22], [0.8, -0.22]])
    _track(a, "RigV3/Skeleton2D/Hips/LegBack/ShinBack:rotation", [[0.0, -0.11], [0.4, 0.16], [0.8, -0.11]])
    _track(a, "RigV3/Skeleton2D/Hips/LegFront/ShinFront:rotation", [[0.0, 0.16], [0.4, -0.11], [0.8, 0.16]])
    _track(a, "RigV3/Skeleton2D/Hips/Spine/ArmBack:rotation", [[0.0, -0.15], [0.4, 0.15], [0.8, -0.15]])
    _track(a, "RigV3/Skeleton2D/Hips/Spine/ArmFront:rotation", [[0.0, 0.15], [0.4, -0.15], [0.8, 0.15]])
    _track(a, "RigV3/Skeleton2D/Hips/Spine:rotation", [[0.0, -0.025], [0.4, 0.035], [0.8, -0.025]])
    _track(a, "RigV3/Skeleton2D/Hips/Spine/Head/HairRoot/HairTip:rotation", [[0.0, 0.10], [0.4, -0.11], [0.8, 0.10]])
    _track(a, "RigV3/Skeleton2D/Hips/SkirtRoot/SkirtTipLeft:rotation", [[0.0, 0.09], [0.4, -0.10], [0.8, 0.09]])
    _track(a, "RigV3/Skeleton2D/Hips/SkirtRoot/SkirtTipRight:rotation", [[0.0, -0.08], [0.4, 0.10], [0.8, -0.08]])
    return a


func _attack_animation() -> Animation:
    var a := _new_animation(0.70, false)
    _track(a, "RigV3/Skeleton2D/Hips/Spine:rotation", [[0.0, -0.02], [0.18, -0.12], [0.37, 0.10], [0.70, 0.0]])
    _track(a, "RigV3/Skeleton2D/Hips/Spine/ArmFront:rotation", [[0.0, -0.08], [0.18, -0.40], [0.37, 0.40], [0.70, 0.0]])
    _track(a, "RigV3/Skeleton2D/Hips/Spine/ArmBack:rotation", [[0.0, 0.05], [0.18, -0.12], [0.37, 0.18], [0.70, 0.0]])
    _track(a, "RigV3/Skeleton2D/Hips/LegBack:rotation", [[0.0, 0.0], [0.18, 0.10], [0.37, -0.08], [0.70, 0.0]])
    _track(a, "RigV3/Skeleton2D/Hips/LegFront:rotation", [[0.0, 0.0], [0.18, -0.10], [0.37, 0.08], [0.70, 0.0]])
    _track(a, "RigV3/Skeleton2D/Hips/SkirtRoot/SkirtTipLeft:rotation", [[0.0, 0.0], [0.18, 0.05], [0.37, -0.09], [0.70, 0.0]])
    _track(a, "RigV3/Skeleton2D/Hips/SkirtRoot/SkirtTipRight:rotation", [[0.0, 0.0], [0.18, -0.04], [0.37, 0.09], [0.70, 0.0]])
    return a


func _new_animation(length: float, looped: bool) -> Animation:
    var a := Animation.new()
    a.length = length
    a.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
    return a


func _track(animation: Animation, path: String, keys: Array) -> void:
    var i := animation.add_track(Animation.TYPE_VALUE)
    animation.track_set_path(i, NodePath(path))
    animation.value_track_set_update_mode(i, Animation.UPDATE_CONTINUOUS)
    for key in keys:
        animation.track_insert_key(i, float(key[0]), key[1])


func _set_visual_mode(action: String) -> void:
    var attacking := action == "attack_sword"
    for arm in _neutral_arms:
        arm.visible = not attacking
    _attack_sword_piece.visible = attacking


func _play(action: String) -> void:
    if _player == null or not _player.has_animation(action):
        return
    _player.stop()
    for bone in _bones.values():
        bone.rotation = 0.0
    _bind_overlay.visible = false
    _set_visual_mode(action)
    _player.play(action)
    if _status_label != null:
        _status_label.text = "当前动作：%s | V3 bind-first" % action


func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)
    var title := Label.new()
    title.text = "沈长风 · Bone2D V3 绑定与三动作验证"
    title.position = Vector2(465, 35)
    title.add_theme_font_size_override("font_size", 30)
    canvas.add_child(title)
    var controls := HBoxContainer.new()
    controls.position = Vector2(500, 90)
    controls.add_theme_constant_override("separation", 12)
    canvas.add_child(controls)
    for entry in [["1 待机", "idle"], ["2 行走", "walk"], ["3 出剑", "attack_sword"]]:
        var button := Button.new()
        button.text = entry[0]
        button.custom_minimum_size = Vector2(125, 42)
        button.pressed.connect(_play.bind(entry[1]))
        controls.add_child(button)
    var bind_button := Button.new()
    bind_button.text = "B 骨架"
    bind_button.custom_minimum_size = Vector2(125, 42)
    bind_button.pressed.connect(_toggle_bind_overlay)
    controls.add_child(bind_button)
    _status_label = Label.new()
    _status_label.position = Vector2(590, 147)
    _status_label.add_theme_font_size_override("font_size", 20)
    canvas.add_child(_status_label)
    var note := Label.new()
    note.text = "统一脚点 / 同一 Skeleton2D / 出剑只替换持剑附件 / B 查看静态骨架"
    note.position = Vector2(410, 915)
    note.add_theme_font_size_override("font_size", 18)
    canvas.add_child(note)


func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    var key := event as InputEventKey
    if not key.pressed or key.echo:
        return
    match key.keycode:
        KEY_1: _play("idle")
        KEY_2: _play("walk")
        KEY_3: _play("attack_sword")
        KEY_4: _play("guard")


func debug_atlas_size() -> Vector2i:
    return _texture.get_size() if _texture != null else Vector2i.ZERO


func debug_mesh_bone_counts() -> Dictionary:
    var out := {}
    for mesh in _mesh_nodes:
        out[mesh.name] = mesh.get_bone_count()
    return out


func debug_animation_names() -> PackedStringArray:
    return _player.get_animation_list() if _player != null else PackedStringArray()


func debug_has_attack_attachment() -> bool:
    return _attack_sword_piece != null and _attack_sword_piece.get_parent() == _bones["ArmFront"]


func debug_attack_visibility() -> bool:
    _play("attack_sword")
    return _attack_sword_piece.visible and not _neutral_arms[0].visible and not _neutral_arms[1].visible


func debug_root_tracks_are_safe() -> bool:
    if _player == null:
        return false
    for action in ["idle", "walk", "attack_sword"]:
        var a := _player.get_animation(action)
        if a == null:
            return false
        for i in range(a.get_track_count()):
            var path := str(a.track_get_path(i))
            if path == "RigV3:position" or path == "RigV3/Skeleton2D:position":
                return false
    return true


func debug_rendered_height() -> float:
    return SOURCE_HEIGHT * _rig.scale.y


func debug_registration() -> Dictionary:
    var head_box := Rect2(PLACEMENTS["head"], REGIONS["head"].size)
    var torso_box := Rect2(PLACEMENTS["torso"], REGIONS["torso"].size)
    var back_sleeve := Rect2(PLACEMENTS["arm_back"], REGIONS["arm_back"].size)
    var front_sleeve := Rect2(PLACEMENTS["arm_front"], REGIONS["arm_front"].size)
    var front_foot := Rect2(PLACEMENTS["foot_front"], REGIONS["foot_front"].size)
    var robe_box := Rect2(PLACEMENTS["robe_left"], REGIONS["robe_left"].size)
    return {
        "head_to_torso": absf(head_box.end.y - torso_box.position.y),
        "rear_shoulder_overlap": torso_box.intersection(back_sleeve).size.x,
        "front_shoulder_overlap": torso_box.intersection(front_sleeve).size.x,
        "foot_baseline": front_foot.end.y,
        "hem_baseline": robe_box.end.y,
        "rig_scale": _rig.scale.x if _rig != null else 0.0,
    }
