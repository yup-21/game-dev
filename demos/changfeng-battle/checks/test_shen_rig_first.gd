extends SceneTree
## Skeleton-first validation: no art sprites are allowed in this milestone.
const SCENE := preload("res://prototypes/shen_rig_first/shen_skeleton_first.tscn")
const CombatScale = preload("res://scripts/combat_scale.gd")
var failures := 0

func check(condition: bool, label: String) -> void:
    if not condition:
        failures += 1
        push_error("SHEN_RIG_FIRST: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene := SCENE.instantiate()
    root.add_child(scene)
    await process_frame
    scene.show_bind_pose()
    await process_frame
    var state: Dictionary = scene.debug_validation()
    check(int(state.get("bone_count", -1)) == 34, "expected explicit 34 bones")
    check(int(state.get("part_count", -1)) == 20, "20 attachment guides declared")
    check(bool(state.get("hierarchy_ok", false)), "parent-child hierarchy follows contract")
    check(bool(state.get("anchors_match", false)), "all rest anchors match contract coordinates")
    check(bool(state.get("root_ground", false)), "foot anchor equals 800,730")
    check(absf(CombatScale.actor_height_pixels() - 200.0) < 0.01, "actor height contract is 200px")
    var weapon: Bone2D = scene.get_node("Skeleton2D/Root/Pelvis/Waist/Chest/FrontShoulder/FrontElbow/FrontWrist/FrontHand/SwordGrip/SwordBlade")
    check(weapon != null, "sword is attached through wrist and hand chain")
    var player: AnimationPlayer = scene.get_node("AnimationPlayer")
    check(player.get_animation_list().size() == 3, "three simple motion clips exist")
    var wrist: Bone2D = scene.get_node("Skeleton2D/Root/Pelvis/Waist/Chest/FrontShoulder/FrontElbow/FrontWrist")
    for action in ["idle", "walk", "attack_sword"]:
        check(player.has_animation(action), action + " exists")
        scene.play_motion(action)
        await process_frame
        check(player.current_animation == action, action + " plays")
        player.seek(player.get_animation(action).length * 0.5, true)
        await process_frame
        check(scene.get_node("Skeleton2D").position == Vector2(800, 730), action + " keeps grounded rig root")
    check(absf(wrist.rotation) > 0.03, "attack animates actual front wrist")
    scene.show_bind_pose()
    await process_frame
    var after: Dictionary = scene.debug_validation()
    check(bool(after.get("anchors_match", false)), "bind pose restores exact anchors")
    scene.queue_free()
    await process_frame
    print("SHEN_RIG_FIRST_PASS failures=%d" % failures)
    quit(0 if failures == 0 else 1)
