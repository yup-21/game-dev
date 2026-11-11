extends SceneTree
## The committed candidate is always tested; optional RIG2D_TEST_PROJECT
## additionally checks all source PNGs and regenerates the 117-frame solve.
const Service = preload("res://addons/wuxia_art_importer/rig2d_pose_service.gd")
var failures := 0


func _initialize() -> void:
    call_deferred("_run")


func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error("RIG2D_POSE: " + message)


func _run() -> void:
    var path := OS.get_environment("RIG2D_TEST_PROJECT")
    if path.is_empty():
        _check_native_scene()
        print("RIG2D_POSE_EDITOR_PASS failures=", failures, " native-only")
        quit(1 if failures else 0)
        return
    var rig: Dictionary = Service.read_project(path)
    check(str(rig.get("error", "")).is_empty(), str(rig.get("error", "")))
    if failures > 0:
        quit(1)
        return
    check(rig["parts"].size() == 25, "v6 source has 25 distinct bound parts")
    check(rig["motions"].size() == 12, "v6 source has 12 actions")
    var total := 0
    for action in rig["motions"]:
        for frame in rig["motions"][action]["frames"]:
            total += 1
            var solved: Dictionary = Service.solve_pose(rig, frame)
            check(solved["placements"].size() == rig["parts"].size(),
                "%s frame has complete rigid-body transforms" % action)
            for part_name in solved["placements"]:
                var pose: Dictionary = solved["placements"][part_name]
                check((pose["origin"] as Vector2).is_finite(), "finite position: " + str(part_name))
                check(is_finite(float(pose["angle"])), "finite rotation: " + str(part_name))
    check(total == 117, "real v6 has 117 frames")
    var old_wrist: Array = rig["motions"]["run"]["frames"][0]["authored_keypoints_coco18"]["left_wrist"].duplicate()
    Service.update_left_joint(rig, "run", 0, "left_wrist", Vector2(old_wrist[0] + 5.0, old_wrist[1] - 5.0))
    var updated: Array = rig["motions"]["run"]["frames"][0]["authored_keypoints_coco18"]["left_wrist"]
    check(is_equal_approx(float(updated[0]), float(old_wrist[0]) + 5.0), "dragged wrist changes authored IK target")
    Service.update_left_joint(rig, "run", 0, "left_wrist", Service.vec(old_wrist))
    var target := "res://assets/imported/characters/gu_qingshuang/rig2d/rig_pose_candidate.tscn"
    var saved: Dictionary = {"error": ""}
    if not FileAccess.file_exists(target):
        saved = Service.save_native_candidate(rig, target)
    else:
        var refuse: Dictionary = Service.save_native_candidate(rig, target)
        check(not str(refuse.get("error", "")).is_empty(), "existing native edits cannot be overwritten")
    check(str(saved.get("error", "")).is_empty(), str(saved.get("error", "")))
    if str(saved.get("error", "")).is_empty():
        _check_native_scene()
    print("RIG2D_POSE_EDITOR_PASS failures=", failures, " frames=", total)
    quit(1 if failures else 0)


func _check_native_scene() -> void:
    var path := "res://assets/imported/characters/gu_qingshuang/rig2d/rig_pose_candidate.tscn"
    var packed := ResourceLoader.load(path) as PackedScene
    check(packed != null, "committed Godot .tscn is loadable")
    if packed == null:
        return
    var candidate: Node = packed.instantiate()
    self.root.add_child(candidate)
    var skeleton: Skeleton2D = candidate.get_node_or_null("Skeleton2D") as Skeleton2D
    var player: AnimationPlayer = candidate.get_node_or_null("AnimationPlayer") as AnimationPlayer
    check(skeleton != null and skeleton.get_bone_count() == 25, "25 native editable Bone2D parts")
    check(player != null and player.get_animation_list().size() == 12, "12 native action timelines")
    if player != null and skeleton != null:
        check(player.get_animation("run").get_track_count() == 50,
            "position and rotation keyframes for all 25 parts")
        player.play("run")
        player.seek(0.0, true)
        var start_position: Vector2 = skeleton.get_node("left_forearm").position
        var start_rotation: float = skeleton.get_node("left_forearm").rotation
        player.seek(0.22, true)
        var forearm: Bone2D = skeleton.get_node("left_forearm")
        check(start_position.distance_to(forearm.position) > 0.01
                or absf(angle_difference(start_rotation, forearm.rotation)) > 0.01,
            "AnimationPlayer actually moves the left forearm across run frames")
    if skeleton != null:
        for bone in skeleton.get_children():
            check(bone is Bone2D and bone.get_node_or_null("Art") is Polygon2D,
                "native Bone2D + textured Polygon2D: " + bone.name)
            if bone.get_node_or_null("Art") is Polygon2D:
                check((bone.get_node("Art") as Polygon2D).texture != null,
                    "PNG reference loaded for: " + bone.name)
    self.root.remove_child(candidate)
    candidate.free()
