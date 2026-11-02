extends SceneTree
## Validate grounded IK, attack key poses, loop seam and pose reset.
## This is a geometric motion regression, not approval of painted assets.

const SCENE := preload("res://prototypes/shen_rig_first/shen_skeleton_first.tscn")
const BASE := "Skeleton2D/Root/Pelvis/"
var errors := 0


func check(ok: bool, message: String) -> void:
    if not ok:
        errors += 1
        push_error("SHEN_MOTION_V2: " + message)


func _initialize() -> void:
    call_deferred("_run")


func _local(scene: Node, node_path: String) -> Vector2:
    var skeleton: Skeleton2D = scene.get_node("Skeleton2D")
    var part: Node2D = scene.get_node(node_path)
    return skeleton.to_local(part.global_position)


func _run() -> void:
    var scene := SCENE.instantiate()
    root.add_child(scene)
    await process_frame
    var player: AnimationPlayer = scene.get_node("AnimationPlayer")
    var front_foot := BASE + "FrontHip/FrontKnee/FrontAnkle/FrontFoot"
    var rear_foot := BASE + "RearHip/RearKnee/RearAnkle/RearFoot"
    var front_shoulder := BASE + "Waist/Chest/FrontShoulder"
    var elbow := front_shoulder + "/FrontElbow"
    var wrist := elbow + "/FrontWrist"
    var sword := wrist + "/FrontHand/WeaponSocket/WeaponTip"
    check(player.get_animation("idle").loop_mode == Animation.LOOP_LINEAR, "idle loops")
    check(player.get_animation("walk").loop_mode == Animation.LOOP_LINEAR, "walk loops")
    check(player.get_animation("attack_sword").loop_mode == Animation.LOOP_NONE, "attack completes")

    scene.play_motion("idle")
    player.seek(0.65, true)
    await process_frame
    check(absf(_local(scene, front_foot).y) < 0.1, "idle front foot on floor")
    check(absf(_local(scene, rear_foot).y) < 0.1, "idle rear foot on floor")

    scene.play_motion("walk")
    var first_front := Vector2.ZERO
    var min_front_x := 1000.0
    var max_front_x := -1000.0
    var max_foot_sinking := 0.0
    var lifted_samples := 0
    var front_mid := Vector2.ZERO
    for i in range(9):
        var t := 0.80 * float(i) / 8.0
        player.seek(t, true)
        await process_frame
        var front: Vector2 = _local(scene, front_foot)
        var rear: Vector2 = _local(scene, rear_foot)
        if i == 0:
            first_front = front
        if i == 4:
            front_mid = front
        min_front_x = minf(min_front_x, front.x)
        max_front_x = maxf(max_front_x, front.x)
        max_foot_sinking = maxf(max_foot_sinking, maxf(front.y, rear.y))
        if front.y < -3.0 or rear.y < -3.0:
            lifted_samples += 1
        check(scene.get_node("Skeleton2D").position == Vector2(800,730),
            "walking never moves root anchor")
    check(max_foot_sinking < 1.6, "walk feet never sink through floor")
    check(lifted_samples >= 2, "walk has distinct swing/foot-lift phase")
    check(max_front_x-min_front_x > 13.0, "walk is not tiny in-place leg rocking")
    check(first_front.distance_to(_local(scene, front_foot)) < 2.0,
        "walk loop joins its starting leg pose")
    check(first_front.distance_to(front_mid) > 8.0,
        "left and right step poses visibly differ")

    scene.play_motion("attack_sword")
    var sword_before := Vector2.ZERO
    var sword_after := Vector2.ZERO
    var moving_joints := 0
    for idx in range(7):
        var times := [0.0, 0.12, 0.24, 0.36, 0.43, 0.57, 0.76]
        player.seek(float(times[idx]), true)
        await process_frame
        var front: Vector2 = _local(scene, front_foot)
        var rear: Vector2 = _local(scene, rear_foot)
        check(front.y < 1.6 and rear.y < 1.6, "attack keeps toes above ground")
        if idx == 2:
            sword_before = _local(scene, sword)
        if idx == 4:
            sword_after = _local(scene, sword)
            for joint in [front_shoulder, elbow, wrist]:
                if absf(float(scene.get_node(joint).rotation)) > 0.10:
                    moving_joints += 1
    check(sword_before.distance_to(sword_after) > 16.0,
        "sword trajectory changes substantially from windup to hit")
    check(moving_joints == 3, "shoulder, elbow, wrist all participate in strike")

    scene.show_bind_pose()
    await process_frame
    var state: Dictionary = scene.debug_validation()
    check(bool(state["anchors_match"]), "pelvis translation resets to exact rest pose")
    check(bool(state["accessories_aligned"]), "accessory bones reset with body")
    check(bool(state["sockets_aligned"]), "weapon grip reset follows rest pose")

    scene.queue_free()
    await process_frame
    print("SHEN_MOTION_V2_PASS failures=%d" % errors)
    quit(0 if errors == 0 else 1)
