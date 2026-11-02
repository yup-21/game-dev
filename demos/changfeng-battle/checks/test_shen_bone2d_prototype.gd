extends SceneTree

const PROTOTYPE_SCENE := preload("res://prototypes/shen_bone2d/shen_bone2d_validation.tscn")
const CombatScale = preload("res://scripts/combat_scale.gd")

var failures := 0

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("SHEN_BONE2D: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene := PROTOTYPE_SCENE.instantiate()
    root.add_child(scene)
    await process_frame

    check(scene.has_node("Rig/Skeleton2D/Hips"), "native Skeleton2D/Bone2D hierarchy exists")
    check(scene.has_node("Rig/Skeleton2D/Hips/Spine/Head"), "head bone exists")
    check(scene.has_node("Rig/Skeleton2D/Hips/Spine/ArmBack"), "back arm bone exists")
    check(scene.has_node("Rig/Skeleton2D/Hips/Spine/ArmFront"), "front arm bone exists")
    check(scene.has_node("Rig/Skeleton2D/Hips/LegBack"), "back leg bone exists")
    check(scene.has_node("Rig/Skeleton2D/Hips/LegFront"), "front leg bone exists")
    check(scene.has_node("Rig/Skeleton2D/Hips/Skirt"), "skirt bone exists")
    check(scene.has_node("Rig/Skeleton2D/Hips/Spine/ArmFront/Sword"), "sword bone exists")

    var expected_pieces := [
        "HeadPiece",
        "TorsoPiece",
        "ArmBackPiece",
        "ArmFrontPiece",
        "LegBackPiece",
        "LegFrontPiece",
        "SkirtPiece",
        "SwordPiece",
    ]
    var pieces: Array[String] = scene.debug_piece_names()
    for piece_name in expected_pieces:
        check(piece_name in pieces, piece_name + " is split as an independent visual piece")

    check(scene.debug_source_frame() == 1, "pilot uses the existing side-facing battle idle frame")
    check(scene.debug_source_texture_path().contains("shen_changfeng"),
        "pilot reuses Shen Changfeng production candidate art")
    check(absf(scene.debug_rendered_reference_height() - CombatScale.actor_height_pixels()) < 2.0,
        "pilot follows the shared 200px actor height contract")

    var names: PackedStringArray = scene.debug_animation_names()
    for animation_name in ["idle", "walk", "attack_sword", "guard"]:
        check(animation_name in names, animation_name + " native AnimationPlayer clip exists")

    check(scene.debug_anchor_tracks_are_safe(),
        "animations do not move the rig/skeleton foot anchor away from the world baseline")

    scene.queue_free()
    await process_frame
    print("SHEN_BONE2D_PASS failures=%d" % failures)
    quit(1 if failures else 0)
