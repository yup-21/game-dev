extends SceneTree
## TRUE source frame -> 22 native Bone2D posing validation.
## Does not reuse pre-posed cutout art or fabricate attack legs.
const SCENE := preload("res://prototypes/shen_rig_first/shen_skeleton_first.tscn")
const FIT := preload("res://prototypes/shen_rig_first/source_frame_pose_trace.gd")
const OVERLAY := preload("res://prototypes/shen_rig_first/source_frame_trace_overlay.gd")
const OUTPUT := "res://captures/shen-rig-first/true-source-trace/"
const CROP := Rect2i(560, 365, 600, 475)
const SCALE := 1.376953125 # source 256px -> 470px reference board -> 0.75x game pixels

var _scene: Node2D
var _skeleton: Skeleton2D
var _reference: Sprite2D
var _visual: Node2D


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("True source-to-skeleton visual capture needs a graphical viewport")
        quit(1)
        return
    root.size = Vector2i(1600,1000)
    _scene = SCENE.instantiate()
    _scene.enable_hair = false
    _scene.enable_coat = false
    _scene.show_skeleton = false
    _scene.show_attachment_guides = false
    root.add_child(_scene)
    await process_frame
    _scene.show_bind_pose()
    _skeleton = _scene.get_node("Skeleton2D") as Skeleton2D

    var image: Texture2D = load("res://assets/imported/candidates/2026-11-01/shen_changfeng/sprite_shen_changfeng_atlas_normalized_v02.png") as Texture2D
    if image == null or image.get_size() != Vector2(1536,1024):
        push_error("Source atlas missing or atlas contract changed")
        quit(1)
        return
    _reference = Sprite2D.new()
    _reference.name = "TrueNormalizedSpriteFrame"
    _reference.centered = false
    _reference.position = Vector2(800,730) + Vector2(-245.0 * 0.75, (52.0-470.0) * 0.75)
    _reference.scale = Vector2.ONE * SCALE
    _reference.z_index = 20
    _scene.add_child(_reference)

    _visual = OVERLAY.new()
    _visual.name = "MeasuredPoseOverlay"
    _visual.position = Vector2(800,730)
    _visual.z_index = 25
    _scene.add_child(_visual)
    _visual.initialize(_skeleton)

    var dataset: Dictionary = FIT.reference_data()
    var results: Array = []
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
    for record in dataset.get("frames", []):
        var current: Dictionary = record
        var sprite := AtlasTexture.new()
        sprite.atlas = image
        var id: int = int(current["source_frame"])
        sprite.region = Rect2((id % 6) * 256, floori(float(id) / 6.0) * 256, 256, 256)
        _reference.texture = sprite

        var outcome: Dictionary = FIT.apply(_scene, current)
        results.append({
            "frame": current["name"],
            "source_frame": current["source_frame"],
            "mean_error_px": outcome["mean_error_px"],
            "max_error_px": outcome["max_error_px"],
            "scored_joints": outcome["scored_joints"],
            "errors": outcome["errors"],
            "weapon_grip_error_px": outcome["weapon_grip_error_px"],
            "weapon_tip_error_px": outcome["weapon_tip_error_px"],
            "low_confidence": outcome["low_confidence"],
            "root_still_fixed": outcome["root_still_fixed"],
            "source_quality": outcome["source_quality"],
        })
        _visual.targets = outcome["reference_landmarks_world"]
        _visual.uncertain = outcome["low_confidence"]
        _scene.queue_redraw()
        _reference.visible = true
        _visual.visible = false
        await process_frame
        await RenderingServer.frame_post_draw
        if not _capture(OUTPUT.path_join(str(current["name"]) + "-original.png")):
            quit(1)
            return

        _visual.visible = true
        _visual.show_goals = true
        _visual.show_bones = true
        _visual.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        if not _capture(OUTPUT.path_join(str(current["name"]) + "-overlay.png")):
            quit(1)
            return

        _reference.visible = false
        _visual.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        if not _capture(OUTPUT.path_join(str(current["name"]) + "-bones.png")):
            quit(1)
            return
        print("SHEN_TRUE_TRACE_FRAME ", current["name"], " mean=", outcome["mean_error_px"],
            " max=", outcome["max_error_px"], " scored=", outcome["scored_joints"])

    var report := {
        "status": "human_visual_review_required",
        "source": dataset["source_atlas"],
        "is_actual_godot_native_bone_pose": true,
        "pixel_coordinate_reference": "source image 256px cell, 470px guide, 0.75 game px / guide px",
        "frames": results,
    }
    var path := OUTPUT.path_join("joint-errors.json")
    var fd := FileAccess.open(path, FileAccess.WRITE)
    if fd == null:
        push_error("Cannot write measured joint errors: " + path)
        quit(1)
        return
    fd.store_string(JSON.stringify(report, "  ") + "\n")
    fd.close()
    print("SHEN_TRUE_SOURCE_TRACE_CAPTURE_OK total=", results.size())
    quit(0)


func _capture(path: String) -> bool:
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("Empty true-trace viewport image")
        return false
    var cropped: Image = image.get_region(CROP)
    var result := cropped.save_png(path)
    if result != OK:
        push_error("Cannot write source-trace visual " + path)
    return result == OK
