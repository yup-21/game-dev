extends SceneTree
## Technical acceptance of V3. Visual quality is reviewed separately.

const SCENE := preload("res://prototypes/shen_bone2d_v3/shen_bone2d_v3_validation.tscn")
const CombatScale = preload("res://scripts/combat_scale.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("SHEN_BONE2D_V3: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene := SCENE.instantiate()
    root.add_child(scene)
    await process_frame
    check(scene.debug_atlas_size() == Vector2i(512, 221), "atlas decodes")
    for path in [
        "RigV3/Skeleton2D/Hips/Spine/Head",
        "RigV3/Skeleton2D/Hips/LegFront/ShinFront/FootFront",
        "RigV3/Skeleton2D/Hips/LegBack/ShinBack/FootBack",
        "RigV3/Skeleton2D/Hips/Spine/ArmFront/AttackSwordPiece",
        "RigV3/Skeleton2D/Hips/SkirtRoot/SkirtTipLeft",
        "RigV3/BindOverlay",
    ]:
        check(scene.has_node(path), "required bone/attachment: " + path)
    for name in ["HairMesh", "RobeLeftMesh", "RobeInnerMesh", "RobeRightMesh"]:
        var counts: Dictionary = scene.debug_mesh_bone_counts()
        check(int(counts.get(name, 0)) == 2, name + " retains two-bone weights")
    var layout: Dictionary = scene.debug_registration()
    check(float(layout["head_to_torso"]) >= 8.0 and float(layout["head_to_torso"]) <= 24.0, "head and torso register")
    check(float(layout["rear_shoulder_overlap"]) >= 15.0, "back sleeve joins torso")
    check(float(layout["front_shoulder_overlap"]) >= 15.0, "front sleeve joins torso")
    check(absf(float(layout["foot_baseline"])) <= 2.0, "front boot meets ground")
    check(absf(float(layout["hem_baseline"])) <= 5.0, "robe hem meets ground")
    check(absf(scene.debug_rendered_height() - CombatScale.actor_height_pixels()) < 1.0, "shared character scale")
    check(scene.debug_root_tracks_are_safe(), "animation does not move authoritative root")
    check(scene.debug_has_attack_attachment(), "sword arm is attached to ArmFront")

    var clips: PackedStringArray = scene.debug_animation_names()
    check(clips.size() == 3, "V3 contains exactly three clips")
    for clip in ["idle", "walk", "attack_sword"]:
        check(clip in clips, "clip exists: " + clip)
        scene.call("_play", clip)
        await process_frame
        var player: AnimationPlayer = scene.get_node("AnimationPlayer")
        check(player.current_animation == clip, "AnimationPlayer runs: " + clip)
        player.seek(player.get_animation(clip).length * 0.45, true)
        await process_frame
        check(scene.get_node("RigV3").position == Vector2(800, 730), "world foot anchor fixed: " + clip)

    check(scene.debug_attack_visibility(), "attack hides neutral arms only")
    check(scene.get_node("RigV3/Skeleton2D/Hips/Spine/TorsoPiece").visible, "torso persists in attack")
    check(scene.get_node("RigV3/Skeleton2D/Hips/LegFront/ThighFrontPiece").visible, "front leg persists in attack")
    scene.call("_play", "walk")
    await process_frame
    check(not scene.get_node("RigV3/Skeleton2D/Hips/Spine/ArmFront/AttackSwordPiece").visible, "attack sprite clears in walk")
    scene.call("debug_show_bind_pose", true)
    check(scene.get_node("RigV3/BindOverlay").visible, "bind pose wire overlay can be enabled")
    scene.queue_free()
    await process_frame
    print("SHEN_BONE2D_V3_PASS failures=%d" % failures)
    quit(1 if failures else 0)
