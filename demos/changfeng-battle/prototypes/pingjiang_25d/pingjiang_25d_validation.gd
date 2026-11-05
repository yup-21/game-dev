extends Node3D
## Standalone 2.5D technical experiment. No Content Manifest, combat rules,
## production map Resource, or existing camera/scaling contract is changed.
const CombatScale = preload("res://scripts/combat_scale.gd")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")
const ActorProfile = preload("res://data/native/animations/shen_changfeng.tres")
const RoadTexture = preload("res://prototypes/pingjiang_25d/stone_road.svg")
const FacadeTexture = preload("res://prototypes/pingjiang_25d/house_facade.svg")

const MAP_SIZE_PIXELS := Vector2(1600.0, 2000.0)
const MAP_WIDTH := MAP_SIZE_PIXELS.x / CombatScale.PIXELS_PER_UNIT
const ROAD_LENGTH := MAP_SIZE_PIXELS.y / CombatScale.PIXELS_PER_UNIT
const ROAD_WIDTH := 5.0
const CROSS_STREET_WIDTH := 5.0
const WALK_SPEED := 4.0
const PLAYER_START_Z := ROAD_LENGTH * 0.5 - 5.0
const PLAYER_LIMIT_Z := ROAD_LENGTH * 0.5 - 1.2
const REFERENCE_Z := ROAD_LENGTH * 0.3
const CAMERA_HEIGHT := 10.0
const CAMERA_OFFSET_Z := 8.0
const CAMERA_AIM_Z := -1.0
const CAMERA_Z_MIN := -ROAD_LENGTH * 0.5 + 10.0
const CAMERA_Z_MAX := ROAD_LENGTH * 0.5 + 6.5
const CAMERA_FOLLOW_SPEED := 5.0
const ACTOR_DISPLAY_SCALE := 0.30 # Only the isolated perspective QA sprite, not the 2D actor contract.
const ORTHOGRAPHIC_SIZE := 15.0
const FOOTPRINT_RADIUS := CombatScale.FOOTPRINT_RADIUS_UNITS
const ACTOR_HEIGHT := CombatScale.ACTOR_HEIGHT_UNITS

@onready var camera: Camera3D = $Camera3D

var player: CharacterBody3D
var actor_sprite: Sprite3D
var actor_elapsed := 0.0
var status: Label

func _ready() -> void:
    if not has_node("Street"):
        _build_street()
    if has_node("Player"):
        player = get_node("Player") as CharacterBody3D
        actor_sprite = player.get_node("ActorSprite") as Sprite3D
    else:
        _build_character()
    if has_node("QAOverlay/Status"):
        status = get_node("QAOverlay/Status") as Label
    else:
        _build_hud()
    if not camera.has_meta("native_authoring_camera"):
        camera.position = Vector3(0.0, CAMERA_HEIGHT, PLAYER_START_Z + CAMERA_OFFSET_Z)
        camera.look_at(Vector3(0.0, 0.0, PLAYER_START_Z + CAMERA_AIM_Z), Vector3.UP)
        camera.projection = Camera3D.PROJECTION_PERSPECTIVE
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

    # Full 1600×2000 world-pixel footprint. Both flat road strips meet at (0,0)
    # without hiding a smaller level under a large perspective illustration.
    var terrain := MeshInstance3D.new()
    terrain.name = "MapGround"
    var terrain_mesh := PlaneMesh.new()
    terrain_mesh.size = Vector2(MAP_WIDTH, ROAD_LENGTH)
    terrain.mesh = terrain_mesh
    terrain.position.y = -0.025
    terrain.material_override = _material(null, Color(0.36, 0.43, 0.36))
    street.add_child(terrain)

    var ground := MeshInstance3D.new()
    ground.name = "TexturedRoad"
    var road_mesh := PlaneMesh.new()
    road_mesh.size = Vector2(ROAD_WIDTH, ROAD_LENGTH)
    ground.mesh = road_mesh
    ground.position.y = 0.001
    var road_material := _material(RoadTexture)
    # UVs repeat on the real 3D plane; this is not a perspective-baked image.
    road_material.uv1_scale = Vector3(1.0, ROAD_LENGTH / 5.0, 1.0)
    ground.material_override = road_material
    street.add_child(ground)
    var cross_street := MeshInstance3D.new()
    cross_street.name = "CrossStreet"
    var cross_mesh := PlaneMesh.new()
    cross_mesh.size = Vector2(MAP_WIDTH, CROSS_STREET_WIDTH)
    cross_street.mesh = cross_mesh
    cross_street.position.y = 0.003 # Avoid coplanar z-fighting at the intersection.
    var cross_material := _material(RoadTexture)
    cross_material.uv1_scale = Vector3(MAP_WIDTH / 5.0, 1.0, 1.0)
    cross_street.material_override = cross_material
    street.add_child(cross_street)
    _add_solid_box(street, "RoadCollider", Vector3(MAP_WIDTH, 0.12, ROAD_LENGTH),
        Vector3(0.0, -0.10, 0.0), _material(null, Color(0.30, 0.35, 0.33)), false)

    var facade_material := _material(FacadeTexture)
    facade_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    # Only textured upright quads: no building boxes, roof meshes, or roof surfaces.
    # Thin hidden colliders prevent passing through a painted facade while the
    # middle of all four roads stays open and connected.
    for side in [-1, 1]:
        var side_label := "W" if side == -1 else "E"
        var cross_label := "N" if side == -1 else "S"
        for half in [-1, 1]:
            var half_label := "N" if half == -1 else "S"
            var horizontal_label := "W" if half == -1 else "E"
            _add_flat_facade(street, "SideFacade_%s_%s" % [side_label, half_label],
                Vector2(5.5, 3.3), Vector3(float(side) * 3.25, 1.65, float(half) * 8.2),
                -float(side) * PI * 0.5, facade_material)
            _add_flat_facade(street, "CrossFacade_%s_%s" % [cross_label, horizontal_label],
                Vector2(5.5, 3.3), Vector3(float(half) * 6.2, 1.65, float(side) * 3.25),
                PI if side == 1 else 0.0, facade_material)

func _add_flat_facade(parent: Node3D, node_name: String, dimensions: Vector2,
        location: Vector3, facing_y: float, material: StandardMaterial3D) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = node_name
    body.position = location
    body.rotation.y = facing_y
    parent.add_child(body)
    var visual := MeshInstance3D.new()
    visual.name = "FacadePlane"
    var quad := QuadMesh.new()
    quad.size = dimensions
    visual.mesh = quad
    visual.material_override = material
    body.add_child(visual)
    var collision := CollisionShape3D.new()
    collision.name = "CollisionShape3D"
    var thin_panel := BoxShape3D.new()
    thin_panel.size = Vector3(dimensions.x, dimensions.y, 0.16)
    collision.shape = thin_panel
    body.add_child(collision)
    return body

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
    player.position = Vector3(0.0, 0.5, PLAYER_START_Z)
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
    for z in [-REFERENCE_Z, REFERENCE_Z]:
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
    sprite.pixel_size = ACTOR_HEIGHT * ACTOR_DISPLAY_SCALE / visible_height
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
    player.position.x = clampf(player.position.x, -MAP_WIDTH * 0.5 + FOOTPRINT_RADIUS,
        MAP_WIDTH * 0.5 - FOOTPRINT_RADIUS)
    player.position.z = clampf(player.position.z, -PLAYER_LIMIT_Z, PLAYER_LIMIT_Z)
    _update_camera_follow(delta)
    _play_actor(movement.length_squared() > 0.01, delta)
    _update_status()

func _camera_target_position() -> Vector3:
    return Vector3(clampf(player.position.x * 0.6, -MAP_WIDTH * 0.25, MAP_WIDTH * 0.25), CAMERA_HEIGHT,
        clampf(player.position.z + CAMERA_OFFSET_Z, CAMERA_Z_MIN, CAMERA_Z_MAX))

func _update_camera_follow(delta: float) -> void:
    var target := _camera_target_position()
    var weight := 1.0 - exp(-CAMERA_FOLLOW_SPEED * delta)
    camera.position.x = lerpf(camera.position.x, target.x, weight)
    camera.position.z = lerpf(camera.position.z, target.z, weight)

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
        camera.size = ORTHOGRAPHIC_SIZE
    elif event.keycode == KEY_R:
        player.position = Vector3(0.0, 0.5, PLAYER_START_Z)
        player.velocity = Vector3.ZERO
        camera.position = _camera_target_position()
    elif event.keycode == KEY_ESCAPE:
        # Restore the existing title screen; QA never changes GameSession.
        get_tree().change_scene_to_file("res://opening.tscn")
        get_viewport().set_input_as_handled()
        return
    else:
        return
    _update_status()
    get_viewport().set_input_as_handled()

func projected_actor_height(z: float) -> float:
    var feet := camera.unproject_position(Vector3(0.0, 0.0, z))
    var head := camera.unproject_position(Vector3(0.0, ACTOR_HEIGHT * ACTOR_DISPLAY_SCALE, z))
    return absf(feet.y - head.y)

func _update_status() -> void:
    if status == null or player == null:
        return
    var mode := "透视" if camera.projection == Camera3D.PROJECTION_PERSPECTIVE else "正交"
    status.text = "平江府 2.5D 十字街 · %s · 地图 %.0f×%.0f px (20×25u)\n四向路口 · 贴图立面/无房顶 · WASD/方向键 · P 投影 · R 复位 · Esc 返回\n位置 Z: %.1f u  镜头 Z: %.1f u  角色画面高: %.0f px\n同尺寸参照：远 %.0f px / 近 %.0f px" % [
        mode, MAP_SIZE_PIXELS.x, MAP_SIZE_PIXELS.y, player.position.z, camera.position.z,
        projected_actor_height(player.position.z),
        projected_actor_height(-REFERENCE_Z), projected_actor_height(REFERENCE_Z)]
