extends SceneTree

const SCENE := preload("res://prototypes/shen_bone2d_v2/shen_bone2d_v2_validation.tscn")
const CombatScale = preload("res://scripts/combat_scale.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("SHEN_BONE2D_V2: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene := SCENE.instantiate()
    root.add_child(scene)
    await process_frame

    check(scene.debug_atlas_size() == Vector2i(512, 221), "embedded clean atlas decodes")
    check(scene.has_node("RigV2/Skeleton2D/Hips/Spine/Head"), "head bone exists")
    check(scene.has_node("RigV2/Skeleton2D/Hips/Spine/Head/HairRoot/HairTip"), "hair chain exists")
    check(scene.has_node("RigV2/Skeleton2D/Hips/SkirtRoot/SkirtTipLeft"), "left skirt chain exists")
    check(scene.has_node("RigV2/Skeleton2D/Hips/LegFront/ShinFront/FootFront"), "front leg chain exists")
    check(scene.has_node("RigV2/Skeleton2D/Hips/LegBack/ShinBack/FootBack"), "back leg chain exists")

    var mesh_counts: Dictionary = scene.debug_mesh_bone_counts()
    for name in ["HairMesh", "RobeLeftMesh", "RobeInnerMesh", "RobeRightMesh"]:
        check(int(mesh_counts.get(name, 0)) == 2, name + " has two-bone Polygon2D weights")

    check(scene.debug_has_action_swaps(), "attack and guard swap groups exist")
    check(scene.has_node("RigV2/AttackUpper/AttackArmsSword"), "attack sword attachment exists")
    check(scene.has_node("RigV2/GuardUpper/GuardArmsSword"), "guard sword attachment exists")
    check(scene.has_node("RigV2/AttackLegs/RearExtendedLeg"), "attack rear-leg swap exists")
    check(scene.has_node("RigV2/AttackLegs/FrontCrouchLeg"), "attack front-leg swap exists")

    var names: PackedStringArray = scene.debug_animation_names()
    for action in ["idle", "walk", "attack_sword", "guard"]:
        check(action in names, action + " animation exists")

    check(scene.debug_root_tracks_are_safe(), "animations never move the authoritative rig foot anchor")
    check(absf(scene.debug_rendered_height() - CombatScale.actor_height_pixels()) < 1.0,
        "v2 visible reference height follows shared 200px actor scale")

    scene.call("_play", "attack_sword")
    await process_frame
    check(scene.get_node("RigV2/AttackUpper").visible, "attack swaps turn on")
    check(not scene.get_node("RigV2/Skeleton2D/Hips/Spine/TorsoPiece").visible,
        "neutral torso turns off during attack")
    scene.call("_play", "guard")
    await process_frame
    check(scene.get_node("RigV2/GuardUpper").visible, "guard swaps turn on")
    scene.call("_play", "idle")
    await process_frame
    check(not scene.get_node("RigV2/AttackUpper").visible and not scene.get_node("RigV2/GuardUpper").visible,
        "idle restores neutral presentation")

    scene.queue_free()
    await process_frame
    print("SHEN_BONE2D_V2_PASS failures=%d" % failures)
    quit(1 if failures else 0)
