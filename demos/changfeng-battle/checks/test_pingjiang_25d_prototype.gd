extends SceneTree
## Isolated 3D render/scale/collision regression, never alters 2D map rules.
const Scene = preload("res://prototypes/pingjiang_25d/pingjiang_25d_validation.tscn")
const Scale = preload("res://scripts/combat_scale.gd")
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
    var map_ground: MeshInstance3D = scene.get_node("Street/MapGround")
    var floor_collider: CollisionShape3D = scene.get_node("Street/RoadCollider/CollisionShape3D")
    var wall: StaticBody3D = scene.get_node("Street/House_L_0")
    _check(scene.get_script() != null and camera.current, "standalone scene and camera instantiate")
    _check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "real perspective projection")
    _check(road.mesh is PlaneMesh and road.material_override.albedo_texture != null,
        "real 3D plane with independently loaded paving texture")
    _check(is_equal_approx(scene.MAP_SIZE_PIXELS.x, 1600.0)
        and is_equal_approx(scene.MAP_SIZE_PIXELS.y, 2000.0)
        and is_equal_approx(map_ground.mesh.size.x, 20.0)
        and is_equal_approx(map_ground.mesh.size.y, 25.0)
        and is_equal_approx(floor_collider.shape.size.x, 20.0)
        and is_equal_approx(road.mesh.size.x, scene.ROAD_WIDTH)
        and is_equal_approx(road.mesh.size.y, scene.ROAD_LENGTH),
        "full 1600x2000 world-pixel map with centered textured street and floor collision")
    var last_house: StaticBody3D = scene.get_node("Street/OuterHouse_R_3")
    _check(scene.get_node_or_null("Street/House_L_3") != null
        and scene.get_node_or_null("Street/OuterHouse_L_3") != null
        and last_house.position.z + 2.85 <= scene.ROAD_LENGTH * 0.5,
        "both rows of buildings fit inside the 2000px-long map")
    _check(wall.get_node("CollisionShape3D").shape is BoxShape3D,
        "side buildings own real 3D obstacle shapes")
    _check(player.get_node("FootprintCollider").shape is CapsuleShape3D,
        "actor has native 3D collision")
    # The right building sits at x=3.65 with half width=1.1. A 0.3u
    # character should stop before its inner face at x=2.55.
    player.position = Vector3(0.0, 0.5, scene.PLAYER_START_Z)
    for step in range(35):
        player.move_and_collide(Vector3(0.15, 0.0, 0.0))
    _check(player.position.x <= 2.26 and player.position.x > 1.5,
        "a moving CharacterBody3D is stopped by the actual facade collider")
    _check(sprite.texture != null and sprite.hframes > 1 and sprite.pixel_size > 0.0,
        "existing Shen Changfeng atlas appears on Sprite3D")
    _check(is_equal_approx(Scale.PIXELS_PER_UNIT, 80.0)
        and is_equal_approx(Scale.actor_height_pixels(), 200.0)
        and is_equal_approx(scene.FOOTPRINT_RADIUS, 0.3),
        "existing combat scale stays authoritative")
    var far_height: float = scene.projected_actor_height(-scene.REFERENCE_Z)
    var near_height: float = scene.projected_actor_height(scene.REFERENCE_Z)
    _check(near_height > far_height * 1.3 and far_height > 0.0,
        "two equally tall world sprites have measurably different screen heights")
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
