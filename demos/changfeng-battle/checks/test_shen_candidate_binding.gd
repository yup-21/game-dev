extends SceneTree
## Candidate pilot binds 16 body/weapon cutouts + 4 optional decorations.
## Does not approve the artwork; verifies actual PNGs/pivots and playback.
const SCENE := preload("res://prototypes/shen_rig_first/shen_candidate_bound_animation.tscn")
var failures := 0

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("SHEN_CUTOUT_BIND: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene := SCENE.instantiate()
    root.add_child(scene)
    await process_frame
    var summary: Dictionary = scene.debug_candidate_binding()
    check(int(summary.get("count",0))==20, "20 independent layers bound")
    check(summary.get("missing",[]).is_empty(), "all textures and anchors present")
    var groups: Dictionary = summary.get("by_group",{})
    check(int(groups.get("body",0))==15, "15 independent human part layers")
    check(int(groups.get("weapon",0))==1, "separate grip-bound sword texture")
    check(int(groups.get("hair",0))==1, "hair weighted ornament attached")
    check(int(groups.get("coat",0))==3, "coat meshes weighted to independent rig")
    check(scene.has_node("Skeleton2D/Root/Pelvis/Waist/Chest/FrontShoulder/FrontElbow/FrontWrist/Art_hand_front"),
        "independent front hand bound to wrist")
    check(scene.has_node("Skeleton2D/Root/Pelvis/Waist/Chest/FrontShoulder/FrontElbow/FrontWrist/FrontHand/WeaponSocket/Art_sword"),
        "sword attached to weapon marker")
    var player: AnimationPlayer = scene.get_node("AnimationPlayer")
    for action in ["idle","walk","attack_sword"]:
        scene.play_motion(action)
        await process_frame
        check(player.current_animation==action, action+" starts")
        player.seek(player.get_animation(action).length*0.5,true)
        await process_frame
        check(scene.get_node("Skeleton2D").position == Vector2(800,730),
            action+" retains world anchor")
        check(scene.debug_candidate_binding().get("count",0)==20,
            action+" does not swap or reconstruct body layers")
    scene.show_bind_pose()
    await process_frame
    check(bool(scene.debug_validation().get("anchors_match",false)),
        "bind pose restores core Bone2D anchors")
    scene.queue_free()
    await process_frame
    print("SHEN_CUTOUT_BIND_PASS failures=%d"%failures)
    quit(0 if failures==0 else 1)
