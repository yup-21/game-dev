extends Node2D
## Shen Changfeng Bone2D v2 validation.
## Uses purpose-built cutout material, Polygon2D skinning for hair/robe,
## and action-specific swap attachments for large sword poses.

const CombatScale = preload("res://scripts/combat_scale.gd")
const ATLAS_PARTS := [
    "res://prototypes/shen_bone2d_v2/atlas.b64.00",
    "res://prototypes/shen_bone2d_v2/atlas.b64.01",
    "res://prototypes/shen_bone2d_v2/atlas.b64.02",
    "res://prototypes/shen_bone2d_v2/atlas.b64.03",
]
const ART_SCALE := 0.45
const SOURCE_ORIGIN := Vector2(310, 525) * ART_SCALE
const SOURCE_TOP_Y := 70.0 * ART_SCALE
const SOURCE_HEIGHT := 455.0 * ART_SCALE
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
const PLACEMENTS := {
    "hair_back": Vector2(230, 70) * ART_SCALE,
    "arm_back": Vector2(210, 180) * ART_SCALE,
    "robe_left": Vector2(215, 270) * ART_SCALE,
    "torso": Vector2(270, 150) * ART_SCALE,
    "pelvis": Vector2(275, 255) * ART_SCALE,
    "robe_inner": Vector2(270, 285) * ART_SCALE,
    "robe_right": Vector2(340, 270) * ART_SCALE,
    "belt": Vector2(276, 255) * ART_SCALE,
    "thigh_back": Vector2(275, 355) * ART_SCALE,
    "shin_back": Vector2(280, 420) * ART_SCALE,
    "foot_back": Vector2(280, 485) * ART_SCALE,
    "thigh_front": Vector2(330, 355) * ART_SCALE,
    "shin_front": Vector2(334, 421) * ART_SCALE,
    "foot_front": Vector2(330, 485) * ART_SCALE,
    "arm_front": Vector2(340, 180) * ART_SCALE,
    "head": Vector2(300, 100) * ART_SCALE,
    "torso_attack": Vector2(245, 150) * ART_SCALE,
    "torso_guard": Vector2(255, 145) * ART_SCALE,
    "guard_arms": Vector2(245, 135) * ART_SCALE,
    "attack_swing": Vector2(190, 215) * ART_SCALE,
    "hair_motion": Vector2(210, 70) * ART_SCALE,
    "robe_flare_mid": Vector2(275, 295) * ART_SCALE,
    "leg_extend": Vector2(245, 350) * ART_SCALE,
    "leg_crouch": Vector2(315, 345) * ART_SCALE,
}

var _texture: ImageTexture
var _rig: Node2D
var _skeleton: Skeleton2D
var _player: AnimationPlayer
var _status_label: Label
var _bones: Dictionary = {}
var _neutral_upper: Array[CanvasItem] = []
var _neutral_legs: Array[CanvasItem] = []
var _neutral_meshes: Array[CanvasItem] = []
var _attack_upper: Node2D
var _attack_legs: Node2D
var _guard_upper: Node2D
var _hair_mesh: Polygon2D
var _mesh_nodes: Array[Polygon2D] = []


func _ready() -> void:
    _texture = _load_embedded_atlas()
    if _texture == null:
        push_error("SHEN_BONE2D_V2: failed to decode embedded cutout atlas")
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
            push_error("SHEN_BONE2D_V2: missing atlas chunk " + path)
            return null
        encoded += FileAccess.get_file_as_string(path).strip_edges()
    var bytes := Marshalls.base64_to_raw(encoded)
    var image := Image.new()
    if image.load_webp_from_buffer(bytes) != OK:
        push_error("SHEN_BONE2D_V2: invalid WebP payload")
        return null
    if image.get_size() != Vector2i(512, 221):
        push_error("SHEN_BONE2D_V2: unexpected atlas size " + str(image.get_size()))
        return null
    return ImageTexture.create_from_image(image)


func _build_stage() -> void:
    var background := ColorRect.new()
    background.size = Vector2(1600, 1000)
    background.color = Color(0.045, 0.058, 0.065, 1.0)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    move_child(background, 0)

    var floor := Line2D.new()
    floor.name = "FootBaseline"
    floor.width = 2.0
    floor.default_color = Color(0.58, 0.68, 0.66, 0.55)
    floor.add_point(Vector2(420, 730))
    floor.add_point(Vector2(1180, 730))
    add_child(floor)

    var tag := Label.new()
    tag.text = "V2 / 真拆件 + Mesh 权重 + 动作附件"
    tag.position = Vector2(625, 775)
    tag.add_theme_font_size_override("font_size", 22)
    add_child(tag)


func _build_rig() -> void:
    _rig = Node2D.new()
    _rig.name = "RigV2"
    _rig.position = Vector2(800, 730)
    _rig.scale = Vector2.ONE * (CombatScale.actor_height_pixels() / SOURCE_HEIGHT)
    add_child(_rig)

    _skeleton = Skeleton2D.new()
    _skeleton.name = "Skeleton2D"
    _rig.add_child(_skeleton)

    var hips := _add_bone("Hips", _skeleton, Vector2(310, 270) * ART_SCALE, SOURCE_ORIGIN)
    var spine := _add_bone("Spine", hips, Vector2(310, 180) * ART_SCALE, Vector2(310, 270) * ART_SCALE)
    var head := _add_bone("Head", spine, Vector2(325, 120) * ART_SCALE, Vector2(310, 180) * ART_SCALE)
    var hair_root := _add_bone("HairRoot", head, Vector2(300, 90) * ART_SCALE, Vector2(325, 120) * ART_SCALE)
    _add_bone("HairTip", hair_root, Vector2(280, 235) * ART_SCALE, Vector2(300, 90) * ART_SCALE)
    var arm_back := _add_bone("ArmBack", spine, Vector2(275, 185) * ART_SCALE, Vector2(310, 180) * ART_SCALE)
    var arm_front := _add_bone("ArmFront", spine, Vector2(345, 185) * ART_SCALE, Vector2(310, 180) * ART_SCALE)
    var leg_back := _add_bone("LegBack", hips, Vector2(295, 340) * ART_SCALE, Vector2(310, 270) * ART_SCALE)
    var shin_back := _add_bone("ShinBack", leg_back, Vector2(295, 410) * ART_SCALE, Vector2(295, 340) * ART_SCALE)
    _add_bone("FootBack", shin_back, Vector2(295, 480) * ART_SCALE, Vector2(295, 410) * ART_SCALE)
    var leg_front := _add_bone("LegFront", hips, Vector2(335, 340) * ART_SCALE, Vector2(310, 270) * ART_SCALE)
    var shin_front := _add_bone("ShinFront", leg_front, Vector2(335, 410) * ART_SCALE, Vector2(335, 340) * ART_SCALE)
    _add_bone("FootFront", shin_front, Vector2(335, 480) * ART_SCALE, Vector2(335, 410) * ART_SCALE)
    var skirt_root := _add_bone("SkirtRoot", hips, Vector2(310, 275) * ART_SCALE, Vector2(310, 270) * ART_SCALE)
    _add_bone("SkirtTipLeft", skirt_root, Vector2(255, 485) * ART_SCALE, Vector2(310, 275) * ART_SCALE)
    _add_bone("SkirtTipCenter", skirt_root, Vector2(310, 500) * ART_SCALE, Vector2(310, 275) * ART_SCALE)
    _add_bone("SkirtTipRight", skirt_root, Vector2(370, 485) * ART_SCALE, Vector2(310, 275) * ART_SCALE)

    for bone in _bones.values():
        bone.rest = bone.transform

    var back_arm_sprite := _add_rigid_piece("ArmBackPiece", arm_back, "arm_back", Vector2(275, 185) * ART_SCALE, -6)
    var torso_sprite := _add_rigid_piece("TorsoPiece", spine, "torso", Vector2(310, 180) * ART_SCALE, 2)
    var pelvis_sprite := _add_rigid_piece("PelvisPiece", hips, "pelvis", Vector2(310, 270) * ART_SCALE, 1)
    var belt_sprite := _add_rigid_piece("BeltPiece", hips, "belt", Vector2(310, 270) * ART_SCALE, 5)
    var front_arm_sprite := _add_rigid_piece("ArmFrontPiece", arm_front, "arm_front", Vector2(345, 185) * ART_SCALE, 7)
    var head_sprite := _add_rigid_piece("HeadPiece", head, "head", Vector2(325, 120) * ART_SCALE, 8)
    _neutral_upper.assign([back_arm_sprite, torso_sprite, pelvis_sprite, belt_sprite, front_arm_sprite, head_sprite])

    var tb := _add_rigid_piece("ThighBackPiece", leg_back, "thigh_back", Vector2(295, 340) * ART_SCALE, -5)
    var sb := _add_rigid_piece("ShinBackPiece", shin_back, "shin_back", Vector2(295, 410) * ART_SCALE, -5)
    var fb := _add_rigid_piece("FootBackPiece", _bones["FootBack"], "foot_back", Vector2(295, 480) * ART_SCALE, -5)
    var tf := _add_rigid_piece("ThighFrontPiece", leg_front, "thigh_front", Vector2(335, 340) * ART_SCALE, 3)
    var sf := _add_rigid_piece("ShinFrontPiece", shin_front, "shin_front", Vector2(335, 410) * ART_SCALE, 3)
    var ff := _add_rigid_piece("FootFrontPiece", _bones["FootFront"], "foot_front", Vector2(335, 480) * ART_SCALE, 3)
    _neutral_legs.assign([tb, sb, fb, tf, sf, ff])

    _hair_mesh = _add_weighted_piece(
        "HairMesh", "hair_back", PLACEMENTS["hair_back"], -8,
        "Hips/Spine/Head/HairRoot", "Hips/Spine/Head/HairRoot/HairTip")
    _neutral_meshes.append(_hair_mesh)
    _neutral_meshes.append(_add_weighted_piece(
        "RobeLeftMesh", "robe_left", PLACEMENTS["robe_left"], -1,
        "Hips/SkirtRoot", "Hips/SkirtRoot/SkirtTipLeft"))
    _neutral_meshes.append(_add_weighted_piece(
        "RobeInnerMesh", "robe_inner", PLACEMENTS["robe_inner"], 0,
        "Hips/SkirtRoot", "Hips/SkirtRoot/SkirtTipCenter"))
    _neutral_meshes.append(_add_weighted_piece(
        "RobeRightMesh", "robe_right", PLACEMENTS["robe_right"], 4,
        "Hips/SkirtRoot", "Hips/SkirtRoot/SkirtTipRight"))

    _attack_upper = Node2D.new()
    _attack_upper.name = "AttackUpper"
    _rig.add_child(_attack_upper)
    _add_free_piece(_attack_upper, "AttackTorso", "torso_attack", PLACEMENTS["torso_attack"], 3)
    _add_free_piece(_attack_upper, "AttackArmsSword", "attack_swing", PLACEMENTS["attack_swing"], 8)
    _add_free_piece(_attack_upper, "AttackHair", "hair_motion", PLACEMENTS["hair_motion"], -7)
    _add_free_piece(_attack_upper, "AttackRobeFlare", "robe_flare_mid", PLACEMENTS["robe_flare_mid"], 5)

    _attack_legs = Node2D.new()
    _attack_legs.name = "AttackLegs"
    _rig.add_child(_attack_legs)
    _add_free_piece(_attack_legs, "RearExtendedLeg", "leg_extend", PLACEMENTS["leg_extend"], -4)
    _add_free_piece(_attack_legs, "FrontCrouchLeg", "leg_crouch", PLACEMENTS["leg_crouch"], 4)

    _guard_upper = Node2D.new()
    _guard_upper.name = "GuardUpper"
    _rig.add_child(_guard_upper)
    _add_free_piece(_guard_upper, "GuardTorso", "torso_guard", PLACEMENTS["torso_guard"], 3)
    _add_free_piece(_guard_upper, "GuardArmsSword", "guard_arms", PLACEMENTS["guard_arms"], 8)

    _attack_upper.visible = false
    _attack_legs.visible = false
    _guard_upper.visible = false


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
    sprite.centered = false
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
    library.add_animation("guard", _guard_animation())
    _player.add_animation_library("", library)


func _idle_animation() -> Animation:
    var a := _new_animation(1.2, true)
    _track(a, "RigV2/Skeleton2D/Hips/Spine:rotation", [[0.0, -0.012], [0.6, 0.018], [1.2, -0.012]])
    _track(a, "RigV2/Skeleton2D/Hips/Spine/Head:rotation", [[0.0, 0.01], [0.6, -0.015], [1.2, 0.01]])
    _track(a, "RigV2/Skeleton2D/Hips/Spine/Head/HairRoot/HairTip:rotation", [[0.0, 0.04], [0.6, -0.05], [1.2, 0.04]])
    _track(a, "RigV2/Skeleton2D/Hips/SkirtRoot/SkirtTipLeft:rotation", [[0.0, -0.025], [0.6, 0.035], [1.2, -0.025]])
    _track(a, "RigV2/Skeleton2D/Hips/SkirtRoot/SkirtTipRight:rotation", [[0.0, 0.025], [0.6, -0.035], [1.2, 0.025]])
    return a


func _walk_animation() -> Animation:
    var a := _new_animation(0.8, true)
    _track(a, "RigV2/Skeleton2D/Hips/LegBack:rotation", [[0.0, 0.22], [0.4, -0.22], [0.8, 0.22]])
    _track(a, "RigV2/Skeleton2D/Hips/LegFront:rotation", [[0.0, -0.22], [0.4, 0.22], [0.8, -0.22]])
    _track(a, "RigV2/Skeleton2D/Hips/LegBack/ShinBack:rotation", [[0.0, -0.11], [0.4, 0.16], [0.8, -0.11]])
    _track(a, "RigV2/Skeleton2D/Hips/LegFront/ShinFront:rotation", [[0.0, 0.16], [0.4, -0.11], [0.8, 0.16]])
    _track(a, "RigV2/Skeleton2D/Hips/Spine/ArmBack:rotation", [[0.0, -0.15], [0.4, 0.15], [0.8, -0.15]])
    _track(a, "RigV2/Skeleton2D/Hips/Spine/ArmFront:rotation", [[0.0, 0.15], [0.4, -0.15], [0.8, 0.15]])
    _track(a, "RigV2/Skeleton2D/Hips/Spine:rotation", [[0.0, -0.025], [0.4, 0.035], [0.8, -0.025]])
    _track(a, "RigV2/Skeleton2D/Hips/Spine/Head/HairRoot/HairTip:rotation", [[0.0, 0.10], [0.4, -0.11], [0.8, 0.10]])
    _track(a, "RigV2/Skeleton2D/Hips/SkirtRoot/SkirtTipLeft:rotation", [[0.0, 0.09], [0.4, -0.10], [0.8, 0.09]])
    _track(a, "RigV2/Skeleton2D/Hips/SkirtRoot/SkirtTipRight:rotation", [[0.0, -0.08], [0.4, 0.10], [0.8, -0.08]])
    return a


func _attack_animation() -> Animation:
    var a := _new_animation(0.68, false)
    _track(a, "RigV2/AttackUpper:rotation", [[0.0, -0.08], [0.17, -0.20], [0.40, 0.13], [0.68, 0.0]])
    _track(a, "RigV2/AttackUpper:position", [[0.0, Vector2(-5, 2)], [0.17, Vector2(-8, 4)], [0.40, Vector2(10, -2)], [0.68, Vector2(2, 0)]])
    _track(a, "RigV2/Skeleton2D/Hips/SkirtRoot/SkirtTipLeft:rotation", [[0.0, 0.0], [0.20, 0.12], [0.42, -0.16], [0.68, 0.0]])
    _track(a, "RigV2/Skeleton2D/Hips/SkirtRoot/SkirtTipRight:rotation", [[0.0, 0.0], [0.20, -0.10], [0.42, 0.17], [0.68, 0.0]])
    return a


func _guard_animation() -> Animation:
    var a := _new_animation(1.0, true)
    _track(a, "RigV2/GuardUpper:rotation", [[0.0, -0.025], [0.5, -0.055], [1.0, -0.025]])
    _track(a, "RigV2/GuardUpper:position", [[0.0, Vector2.ZERO], [0.5, Vector2(-1.5, 1.5)], [1.0, Vector2.ZERO]])
    _track(a, "RigV2/Skeleton2D/Hips/SkirtRoot/SkirtTipLeft:rotation", [[0.0, -0.015], [0.5, 0.02], [1.0, -0.015]])
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
    var is_attack := action == "attack_sword"
    var is_guard := action == "guard"
    for item in _neutral_upper:
        item.visible = not is_attack and not is_guard
    for item in _neutral_legs:
        item.visible = not is_attack
    _hair_mesh.visible = not is_attack
    _attack_upper.visible = is_attack
    _attack_legs.visible = is_attack
    _guard_upper.visible = is_guard


func _play(action: String) -> void:
    if _player == null or not _player.has_animation(action):
        return
    _set_visual_mode(action)
    _player.play(action)
    if _status_label != null:
        _status_label.text = "当前动作：%s   V2 hybrid rig" % action


func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)
    var title := Label.new()
    title.text = "沈长风 · Bone2D V2 验证（真拆件 / Mesh / 动作换件）"
    title.position = Vector2(455, 35)
    title.add_theme_font_size_override("font_size", 30)
    canvas.add_child(title)
    var controls := HBoxContainer.new()
    controls.position = Vector2(510, 90)
    controls.add_theme_constant_override("separation", 12)
    canvas.add_child(controls)
    for entry in [["1 待机", "idle"], ["2 行走", "walk"], ["3 出剑", "attack_sword"], ["4 格挡", "guard"]]:
        var button := Button.new()
        button.text = entry[0]
        button.custom_minimum_size = Vector2(125, 42)
        button.pressed.connect(_play.bind(entry[1]))
        controls.add_child(button)
    _status_label = Label.new()
    _status_label.position = Vector2(590, 147)
    _status_label.add_theme_font_size_override("font_size", 20)
    canvas.add_child(_status_label)
    var note := Label.new()
    note.text = "V2：头发/衣摆为 Polygon2D 双骨权重；出剑/格挡使用专用换件。Rig 根脚点固定。"
    note.position = Vector2(405, 915)
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


func debug_has_action_swaps() -> bool:
    return _attack_upper != null and _attack_legs != null and _guard_upper != null


func debug_root_tracks_are_safe() -> bool:
    if _player == null:
        return false
    for action in ["idle", "walk", "attack_sword", "guard"]:
        var a := _player.get_animation(action)
        for i in range(a.get_track_count()):
            var path := str(a.track_get_path(i))
            if path == "RigV2:position" or path == "RigV2/Skeleton2D:position":
                return false
    return true


func debug_rendered_height() -> float:
    return SOURCE_HEIGHT * _rig.scale.y
