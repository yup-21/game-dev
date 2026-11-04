extends Node3D
## Standalone 2.5D technical experiment. No Content Manifest, combat rules,
## production map Resource, or existing camera/scaling contract is changed.
const CombatScale = preload("res://scripts/combat_scale.gd")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")
const ActorProfile = preload("res://data/native/animations/shen_changfeng.tres")
const RoadTexture = preload("res://prototypes/pingjiang_25d/stone_road.svg")
const FacadeTexture = preload("res://prototypes/pingjiang_25d/house_facade.svg")

const ROAD_WIDTH := 5.0
const ROAD_LENGTH := 25.0
const WALK_SPEED := 4.0
const FOOTPRINT_RADIUS := CombatScale.FOOTPRINT_RADIUS_UNITS
const ACTOR_HEIGHT := CombatScale.ACTOR_HEIGHT_UNITS

@onready var camera: Camera3D = $Camera3D

var player: CharacterBody3D
var actor_sprite: Sprite3D
var actor_elapsed := 0.0
var status: Label

func _ready() -> void:
    camera.look_at(Vector3(0.0, 0.0, -1.0), Vector3.UP)
    camera.projection = Camera3D.PROJECTION_PERSPECTIVE
    _build_street()
    _build_character()
    _build_hud()
    _update_status()

func _material(texture: Texture2D, tint: Color = Color.WHITE) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_texture = texture
    material.albedo_color = tint
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    return material

func _build_street() -> void:
    var street := Node3D.new()
    street.name = "Street"
    add_child(street)

    var ground := MeshInstance3D.new()
    ground.name = "TexturedRoad"
    var road_mesh := PlaneMesh.new()
    road_mesh.size = Vector2(ROAD_WIDTH, ROAD_LENGTH)
    ground.mesh = road_mesh
    var road_material := _material(RoadTexture)
    # UVs repeat on the real 3D plane; this is not a perspective-baked image.
    road_material.uv1_scale = Vector3(1.0, 5.0, 1.0)
    ground.material_override = road_material
    street.add_child(ground)
    _add_solid_box(street, "RoadCollider", Vector3(ROAD_WIDTH, 0.12, ROAD_LENGTH),
        Vector3(0.0, -0.10, 0.0), _material(null, Color(0.30, 0.35, 0.33)), false)

    var facade_material := _material(FacadeTexture)
    for side in [-1, 1]:
        for index in range(4):
            var z: float = -9.15 + float(index) * 6.1
            var x: float = float(side) * 3.65
            _add_solid_box(street, "House_%s_%d" % ["L" if side == -1 else "R", index],
                Vector3(2.2, 3.3, 5.7), Vector3(x, 1.65, z), facade_material)
            _add_solid_box(street, "Roof_%s_%d" % ["L" if side == -1 else "R", index],
                Vector3(2.8, 0.35, 6.0), Vector3(x, 3.47, z),
                _material(null, Color(0.19, 0.24, 0.24)))

    # A tangible gate at the far end provides an unambiguous perspective ruler.
    var pillar_material := _material(null, Color(0.50, 0.52, 0.48))
    for side in [-1, 1]:
        _add_solid_box(street, "GatePillar_%s" % side, Vector3(0.65, 3.6, 0.8),
            Vector3(float(side) * 2.15, 1.8, -10.8), pillar_material)
    _add_solid_box(street, "GateLintel", Vector3(5.0, 0.55, 1.1),
        Vector3(0.0, 3.85, -10.8), _material(null, Color(0.24, 0.31, 0.30)))

func _add_solid_box(parent: Node3D, node_name: String, size: Vector3,
        location: Vector3, material: StandardMaterial3D, visible_mesh: bool = true) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = node_name
    body.position = location
    parent.add_child(body)
    var shape := CollisionShape3D.new()
    shape.name = "CollisionShape3D"
    var box_shape := BoxShape3D.new()
    box_shape.size = size
    shape.shape = box_shape
    body.add_child(shape)
    if visible_mesh:
        var visual := MeshInstance3D.new()
        visual.name = "MeshInstance3D"
        var box := BoxMesh.new()
        box.size = size
        visual.mesh = box
        visual.material_override = material
        body.add_child(visual)
    return body

func _build_character() -> void:
    var profile: WuxiaActorAnimationProfile = ActorProfile
    assert(profile.valid_profile(), "The existing Shen Changfeng animation profile must load")
    var idle: WuxiaActorAnimationClip = profile.clip_for("idle")
    assert(idle != null and not idle.frames.is_empty())

    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0.0, 0.5, 3.0)
    add_child(player)
    var collider := CollisionShape3D.new()
    collider.name = "FootprintCollider"
    var capsule := CapsuleShape3D.new()
    capsule.radius = FOOTPRINT_RADIUS
    capsule.height = 1.0
    collider.shape = capsule
    player.add_child(collider)

    actor_sprite = _new_actor_sprite(profile, idle)
    actor_sprite.name = "ActorSprite"
    player.add_child(actor_sprite)

    # Same sprite, same world height, two depths: perspective changes pixels.
    for z in [-8.0, 8.0]:
        var witness := Node3D.new()
        witness.name = "FarReference" if z < 0.0 else "NearReference"
        witness.position = Vector3(-1.3, 0.0, z)
        add_child(witness)
        var sprite := _new_actor_sprite(profile, idle)
        sprite.position.y += 0.5 # reference actor has no CharacterBody3D origin offset
        sprite.modulate = Color(0.70, 0.89, 0.95, 0.75)
        witness.add_child(sprite)

func _new_actor_sprite(profile: WuxiaActorAnimationProfile,
        idle: WuxiaActorAnimationClip) -> Sprite3D:
    var sprite := Sprite3D.new()
    sprite.texture = idle.effective_atlas(profile.atlas)
    sprite.hframes = idle.effective_columns(profile.columns)
    sprite.vframes = idle.effective_rows(profile.rows)
    var frame_id: int = idle.frames[0]
    sprite.frame = frame_id
    sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sprite.shaded = false
    sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
    var bounds: Rect2i = VisualScale._opaque_bounds(sprite.texture, sprite.hframes,
        sprite.vframes, frame_id)
    var frame_height: float = float(sprite.texture.get_height()) / float(sprite.vframes)
    var visible_height: float = float(bounds.size.y) if bounds.size.y > 0 else frame_height
    sprite.pixel_size = ACTOR_HEIGHT / visible_height
    # Translate the visible feet, not the transparent atlas cell, to Y=0.
    var feet_from_center: float = float(bounds.end.y) - frame_height * 0.5
    sprite.position.y = feet_from_center * sprite.pixel_size - 0.5
    return sprite

func _build_hud() -> void:
    var ui := CanvasLayer.new()
    ui.name = "QAOverlay"
    add_child(ui)
    status = Label.new()
    status.name = "Status"
    status.position = Vector2(24.0, 18.0)
    status.add_theme_font_size_override("font_size", 22)
    status.add_theme_color_override("font_color", Color(0.94, 0.95, 0.86))
    status.add_theme_color_override("font_shadow_color", Color(0.03, 0.06, 0.07))
    ui.add_child(status)

func _physics_process(delta: float) -> void:
    if player == null:
        return
    var movement := Vector2(
        Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
        Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up"))
    movement.x += float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
    movement.y += float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
    movement = movement.limit_length(1.0)
    player.velocity = Vector3(movement.x, 0.0, movement.y) * WALK_SPEED
    player.move_and_slide()
    player.position.z = clampf(player.position.z, -11.8, 11.8)
    _play_actor(movement.length_squared() > 0.01, delta)
    _update_status()

func _play_actor(moving: bool, delta: float) -> void:
    var profile: WuxiaActorAnimationProfile = ActorProfile
    var clip: WuxiaActorAnimationClip = profile.resolved_clip_for("walk") if moving else profile.clip_for("idle")
    if clip == null or clip.frames.is_empty():
        return
    actor_elapsed = actor_elapsed + delta if moving else 0.0
    var tick: int = int(floor(actor_elapsed * clip.loop_fps)) % clip.frames.size()
    actor_sprite.frame = clip.frames[tick]

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    if event.keycode == KEY_P:
        camera.projection = Camera3D.PROJECTION_ORTHOGONAL \
            if camera.projection == Camera3D.PROJECTION_PERSPECTIVE \
            else Camera3D.PROJECTION_PERSPECTIVE
        camera.size = 28.0
    elif event.keycode == KEY_R:
        player.position = Vector3(0.0, 0.5, 3.0)
        player.velocity = Vector3.ZERO
    else:
        return
    _update_status()
    get_viewport().set_input_as_handled()

func projected_actor_height(z: float) -> float:
    var feet := camera.unproject_position(Vector3(0.0, 0.0, z))
    var head := camera.unproject_position(Vector3(0.0, ACTOR_HEIGHT, z))
    return absf(feet.y - head.y)

func _update_status() -> void:
    if status == null or player == null:
        return
    var mode := "透视" if camera.projection == Camera3D.PROJECTION_PERSPECTIVE else "正交"
    status.text = "平江府 2.5D 独立验证 · %s\nWASD / 方向键移动 · P 对比投影 · R 复位\n位置 Z: %.1f u  可见高: %.0f px\n同尺寸参照：远 %.0f px / 近 %.0f px" % [
        mode, player.position.z, projected_actor_height(player.position.z),
        projected_actor_height(-8.0), projected_actor_height(8.0)]
