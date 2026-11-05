extends SceneTree
## Isolated 3D render/scale/collision regression, never alters 2D map rules.
const Scene = preload("res://prototypes/pingjiang_25d/pingjiang_25d_validation.tscn")
const Scale = preload("res://scripts/combat_scale.gd")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("PINGJIANG_25D: " + reason)

func _run() -> void:
    var scene: Node3D = Scene.instantiate()
    root.add_child(scene)
    await process_frame
    await physics_frame
    var camera: Camera3D = scene.get_node("Camera3D")
    var player: CharacterBody3D = scene.get_node("Player")
    var sprite: Sprite3D = scene.get_node("Player/ActorSprite")
    var road: MeshInstance3D = scene.get_node("Street/TexturedRoad")
    var cross_street: MeshInstance3D = scene.get_node("Street/CrossStreet")
    var map_ground: MeshInstance3D = scene.get_node("Street/MapGround")
    var floor_collider: CollisionShape3D = scene.get_node("Street/RoadCollider/CollisionShape3D")
    var wall: StaticBody3D = scene.get_node("Street/SideFacade_W_N")
    _check(scene.get_script() != null and camera.current, "standalone scene and camera instantiate")
    _check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "real perspective projection")
    _check(road.mesh is PlaneMesh and cross_street.mesh is PlaneMesh
        and road.material_override.albedo_texture != null
        and cross_street.material_override.albedo_texture != null
        and cross_street.position.y > road.position.y,
        "two textured 3D road planes cross without z-fighting")
    _check(is_equal_approx(scene.MAP_SIZE_PIXELS.x, 1600.0)
        and is_equal_approx(scene.MAP_SIZE_PIXELS.y, 2000.0)
        and is_equal_approx(map_ground.mesh.size.x, 20.0)
        and is_equal_approx(map_ground.mesh.size.y, 25.0)
        and is_equal_approx(floor_collider.shape.size.x, 20.0)
        and is_equal_approx(road.mesh.size.x, scene.ROAD_WIDTH)
        and is_equal_approx(road.mesh.size.y, scene.ROAD_LENGTH)
        and is_equal_approx(cross_street.mesh.size.x, scene.MAP_WIDTH)
        and is_equal_approx(cross_street.mesh.size.y, scene.CROSS_STREET_WIDTH),
        "actual map footprint is 20x25u with four continuous street arms")
    var facade_count := 0
    var flat_facades := true
    var roof_present := false
    for child in scene.get_node("Street").get_children():
        if child.name.begins_with("SideFacade_") or child.name.begins_with("CrossFacade_"):
            facade_count += 1
            var plane: MeshInstance3D = child.get_node("FacadePlane")
            var collider: CollisionShape3D = child.get_node("CollisionShape3D")
            flat_facades = flat_facades and plane.mesh is QuadMesh
            flat_facades = flat_facades and collider.shape is BoxShape3D
            flat_facades = flat_facades and collider.shape.size.z < 0.2
        if child.name.begins_with("Roof_") or child.name.begins_with("Gate"):
            roof_present = true
    _check(facade_count == 8 and flat_facades and not roof_present
        and scene.get_node("Street").get_child_count() == 12,
        "eight flat textured facade panels, thin invisible blockers, no roof or gate meshes")
    _check(wall.get_node("CollisionShape3D").shape is BoxShape3D,
        "facade plane owns an invisible narrow obstacle")
    _check(player.get_node("FootprintCollider").shape is CapsuleShape3D,
        "actor has native 3D collision")
    # A 0.3u foot radius meets the paper-thin western wall before x=-3.17.
    player.position = Vector3(0.0, 0.5, -8.2)
    for step in range(35):
        player.move_and_collide(Vector3(-0.15, 0.0, 0.0))
    _check(player.position.x < -2.0 and player.position.x > -3.0,
        "invisible facade collider stops the character, without a 3D building block")
    player.position = Vector3(-9.0, 0.5, 0.0)
    for step in range(90):
        player.move_and_collide(Vector3(0.2, 0.0, 0.0))
    _check(player.position.x > 8.5,
        "the west-east stone road stays physically open through the junction")
    player.position = Vector3(0.0, 0.5, -11.0)
    for step in range(110):
        player.move_and_collide(Vector3(0.0, 0.0, 0.2))
    _check(player.position.z > 10.5,
        "the north-south stone road stays physically open through the junction")
    _check(sprite.texture != null and sprite.hframes > 1 and sprite.pixel_size > 0.0,
        "existing Shen Changfeng atlas appears on Sprite3D")
    _check(is_equal_approx(Scale.PIXELS_PER_UNIT, 80.0)
        and is_equal_approx(Scale.actor_height_pixels(), 200.0)
        and is_equal_approx(scene.FOOTPRINT_RADIUS, 0.3),
        "existing combat scale stays authoritative")
    var visible_bounds: Rect2i = VisualScale._opaque_bounds(sprite.texture,
        sprite.hframes, sprite.vframes, sprite.frame)
    _check(is_equal_approx(scene.ACTOR_DISPLAY_SCALE, 0.20)
        and is_equal_approx(sprite.pixel_size * float(visible_bounds.size.y),
            scene.ACTOR_HEIGHT * scene.ACTOR_DISPLAY_SCALE),
        "only the isolated prototype sprites are one-third smaller than the former 0.30 scale")
    _check(is_equal_approx(camera.fov, 38.0)
        and is_equal_approx(scene.CAMERA_HEIGHT, 8.0)
        and is_equal_approx(scene.CAMERA_OFFSET_Z, 6.4)
        and is_equal_approx(scene.ORTHOGRAPHIC_SIZE, 12.0)
        and is_equal_approx(camera.size, scene.ORTHOGRAPHIC_SIZE),
        "both camera projections use the closer, 20-percent tighter framing")
    player.position = Vector3(0.0, 0.5, scene.PLAYER_START_Z)
    camera.position = scene._camera_target_position()
    var north_screen := camera.unproject_position(Vector3(0.0, 0.0, -scene.ROAD_LENGTH * 0.5))
    var south_screen := camera.unproject_position(Vector3(0.0, 0.0, scene.ROAD_LENGTH * 0.5))
    _check(absf(north_screen.y - south_screen.y) > root.size.y,
        "camera framing is tighter than the full 2000px-long map")
    var far_height: float = scene.projected_actor_height(-scene.REFERENCE_Z)
    var near_height: float = scene.projected_actor_height(scene.REFERENCE_Z)
    _check(near_height > far_height * 1.1 and far_height > 0.0,
        "the tighter view still preserves measurable perspective size difference")
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    var ortho_far: float = scene.projected_actor_height(-scene.REFERENCE_Z)
    var ortho_near: float = scene.projected_actor_height(scene.REFERENCE_Z)
    _check(absf(ortho_far - ortho_near) < 0.5,
        "orthographic comparison removes depth scaling")
    _check(scene.get_node("NearReference").get_child_count() == 1
        and scene.get_node("FarReference").get_child_count() == 1,
        "near/far identical sprite references are present")
    camera.projection = Camera3D.PROJECTION_PERSPECTIVE
    var initial_camera_z: float = camera.position.z
    player.position = Vector3(2.0, 0.5, -scene.PLAYER_LIMIT_Z + 1.0)
    scene._update_camera_follow(0.1)
    _check(camera.position.z < initial_camera_z - 1.0
        and camera.position.z > scene._camera_target_position().z,
        "camera follows player smoothly, rather than teleporting")
    scene._update_camera_follow(2.0)
    _check(absf(camera.position.z - scene._camera_target_position().z) < 0.01
        and camera.position.x > 0.7,
        "camera reaches the distant player and follows sideways")
    player.position.z = -scene.PLAYER_LIMIT_Z
    scene._update_camera_follow(2.0)
    _check(absf(camera.position.z - scene.CAMERA_Z_MIN) < 0.01,
        "camera stops scrolling at the far edge")
    player.position.z = scene.PLAYER_LIMIT_Z
    scene._update_camera_follow(2.0)
    _check(absf(camera.position.z - scene.CAMERA_Z_MAX) < 0.01,
        "camera stops scrolling at the near edge")
    player.position.x = 100.0
    _check(scene._camera_target_position().x <= scene.MAP_WIDTH * 0.25,
        "horizontal camera tracking respects the full map boundaries")
    print("PINGJIANG_25D_PASS failures=%d near=%.1fpx far=%.1fpx" % [
        failures, near_height, far_height])
    scene.queue_free()
    quit(1 if failures > 0 else 0)
