extends SceneTree
## Confirms real Skeleton2D nodes follow actual 8 sprite-frame joint targets.
## This checks the tracing pipeline; fit quality remains visible in the
## generated joint-errors.json and must pass separate human art review.

const SCENE := preload("res://prototypes/shen_rig_first/shen_skeleton_first.tscn")
const FIT := preload("res://prototypes/shen_rig_first/source_frame_pose_trace.gd")
var errors := 0

func check(ok: bool, message: String) -> void:
    if not ok:
        errors += 1
        push_error("SHEN_SOURCE_FRAME_TRACE: " + message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var dataset: Dictionary = FIT.reference_data()
    check(int(dataset.get("version",-1)) == 1, "source landmark contract v1")
    var frames: Array = dataset.get("frames",[])
    check(frames.size() == 8, "idle 1 + move 4 + attack 3 source frames")
    if frames.size() != 8:
        quit(1)
        return
    var seen := {}
    var scene := SCENE.instantiate()
    scene.enable_hair = false
    scene.enable_coat = false
    root.add_child(scene)
    await process_frame
    for record in frames:
        var name: String = str(record["name"])
        check(not seen.has(name), "unique frame: " + name)
        seen[name] = true
        check(record["points"].has("pelvis") and record["points"].has("head"),
            "observable torso landmarks: " + name)
        var result: Dictionary = FIT.apply(scene,record)
        check(result.get("root_still_fixed",false), "world foot root is stable: " + name)
        check(int(result.get("scored_joints",0)) >= 10,
            "enough clearly observed joints: " + name)
        check(is_finite(float(result["mean_error_px"]))
            and is_finite(float(result["max_error_px"])),
            "no invalid native bone joint positions: " + name)
        check(float(result["mean_error_px"]) < 80.0,
            "fitter is not completely detached from source art: " + name)
        if name.begins_with("attack"):
            check(record["low_confidence"].has("FrontFoot")
                and record["low_confidence"].has("RearFoot"),
                "detached source boots are explicitly excluded: " + name)
        print("SHEN_SOURCE_TRACE_RESULT name=",name,
            " error_avg_world_px=",result["mean_error_px"],
            " error_max_world_px=",result["max_error_px"],
            " n=",result["scored_joints"])

    scene.show_bind_pose()
    await process_frame
    var state: Dictionary = scene.debug_validation()
    check(bool(state.get("anchors_match",false)),
        "every limb restores original skeleton rest pose")
    check(bool(state.get("sockets_aligned",false)), "weapon socket restores")
    scene.queue_free()
    await process_frame
    print("SHEN_SOURCE_FRAME_TRACE_PASS failures=%d" % errors)
    quit(0 if errors==0 else 1)
