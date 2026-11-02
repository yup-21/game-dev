extends SceneTree
## Core 22 bones only; hair/coat are independent Skeleton2D attachments.

const SCENE := preload("res://prototypes/shen_rig_first/shen_skeleton_first.tscn")
const CORE_SCENE := preload("res://prototypes/humanoid_rig/humanoid_side_core.tscn")
const CombatScale = preload("res://scripts/combat_scale.gd")
var failures := 0


func check(condition: bool, label: String) -> void:
    if not condition:
        failures += 1
        push_error("SHEN_RIG_FIRST: " + label)


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    # The universal skeleton must load alone, without Shen's art or accessories.
    var standalone: Skeleton2D = CORE_SCENE.instantiate() as Skeleton2D
    root.add_child(standalone)
    await process_frame
    check(standalone.get_bone_count() == 22, "standalone reusable core is exactly 22 bones")
    check(standalone.has_node("Root/Pelvis/Waist/Chest/FrontShoulder/FrontElbow/FrontWrist/FrontHand/WeaponSocket"),
        "weapon socket is a marker, not a human bone")
    check(standalone.has_node("Root/Pelvis/Waist/Chest/Neck/Head/HairSocket"),
        "hair socket belongs to head bone")
    check(standalone.has_node("Root/Pelvis/CoatSocket"), "coat socket belongs to pelvis bone")
    standalone.queue_free()
    await process_frame

    var scene := SCENE.instantiate()
    root.add_child(scene)
    await process_frame
    scene.show_bind_pose()
    await process_frame
    var state: Dictionary = scene.debug_validation()
    check(int(state.get("bone_count", -1)) == 22, "22 humanoid bones, no ornament bones in core")
    check(int(state.get("accessory_bone_count", -1)) == 10, "3 hair + 7 coat bones independent")
    check(int(state.get("part_count", -1)) == 20, "20 art guides preserved")
    check(bool(state.get("core_is_separate", false)), "core Skeleton2D excludes all accessory bones")
    check(bool(state.get("hierarchy_ok", false)), "humanoid hierarchy matches core contract")
    check(bool(state.get("anchors_match", false)), "rest anchors equal shared geometry")
    if not bool(state.get("accessories_aligned", false)):
        print("SHEN_RIG_FIRST_ACCESSORY_DELTAS: ", state.get("accessory_deltas", []))
    check(bool(state.get("accessories_aligned", false)), "optional bones follow head/pelvis sockets")
    check(bool(state.get("sockets_aligned", false)), "weapon grip and tip align to hand")
    check(bool(state.get("root_ground", false)), "actor foot anchor is locked")
    check(absf(float(state["anchors"]["RearFoot"][1])) < 0.01, "rear foot touches ground")
    check(absf(float(state["anchors"]["FrontFoot"][1])) < 0.01, "front foot touches ground")
    check(absf(CombatScale.actor_height_pixels() - 200.0) < 0.01, "200px actor height contract")

    var wrist: Bone2D = scene.get_node("Skeleton2D/Root/Pelvis/Waist/Chest/FrontShoulder/FrontElbow/FrontWrist")
    var sword: Marker2D = scene.get_node("Skeleton2D/Root/Pelvis/Waist/Chest/FrontShoulder/FrontElbow/FrontWrist/FrontHand/WeaponSocket")
    var player: AnimationPlayer = scene.get_node("AnimationPlayer")
    check(player.get_animation_list().size() == 3, "exactly idle/walk/attack clips")
    for action in ["idle", "walk", "attack_sword"]:
        check(player.has_animation(action), action + " exists")
        scene.play_motion(action)
        await process_frame
        check(player.current_animation == action, action + " plays")
        player.seek(player.get_animation(action).length * 0.5, true)
        await process_frame
        check(scene.get_node("Skeleton2D").position == Vector2(800, 730), action + " root is grounded")
    check(absf(wrist.rotation) > 0.03, "attack drives wrist")
    check(absf(sword.rotation) > 0.03, "attack drives independent weapon socket")
    scene.show_bind_pose()
    await process_frame
    var after: Dictionary = scene.debug_validation()
    check(bool(after.get("anchors_match", false)), "bind restores body anchors")
    check(bool(after.get("accessories_aligned", false)), "bind restores accessory anchors")
    scene.queue_free()
    await process_frame

    # The same core plays all three motions with neither optional rig equipped.
    var plain := SCENE.instantiate()
    plain.enable_hair = false
    plain.enable_coat = false
    root.add_child(plain)
    await process_frame
    plain.show_bind_pose()
    var plain_state: Dictionary = plain.debug_validation()
    check(int(plain_state["bone_count"]) == 22, "unadorned character keeps 22 bones")
    check(int(plain_state["accessory_bone_count"]) == 0, "unadorned character has zero decoration bones")
    check(bool(plain_state["anchors_match"]), "unadorned character remains aligned")
    for motion in ["idle", "walk", "attack_sword"]:
        plain.play_motion(motion)
        await process_frame
        check(plain.get_node("AnimationPlayer").current_animation == motion,
            "unadorned body plays " + motion)
    plain.queue_free()
    await process_frame

    print("SHEN_RIG_FIRST_PASS failures=%d" % failures)
    quit(0 if failures == 0 else 1)
