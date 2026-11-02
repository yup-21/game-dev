extends SceneTree
const SCENE := preload("res://prototypes/shen_rig_first/shen_candidate_bound_animation.tscn")
const OVERLAY := preload("res://prototypes/shen_rig_first/source_frame_trace_overlay.gd")
const OUTPUT := "res://captures/shen-rig-first/candidate-bound/"
const RECT := Rect2i(550, 385, 570, 465)
var scene: Node2D
var player: AnimationPlayer
var overlay: Node2D

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if DisplayServer.get_name()=="headless":
        push_error("SHEN_CANDIDATE_CAPTURE: graphical viewport required")
        quit(1)
        return
    root.size=Vector2i(1600,1000)
    scene=SCENE.instantiate()
    root.add_child(scene)
    await process_frame
    player=scene.get_node("AnimationPlayer") as AnimationPlayer
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
    scene.show_bind_pose()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save(OUTPUT.path_join("bind-pose.png")):
        quit(1)
        return
    overlay=OVERLAY.new()
    overlay.name="AcceptedBonesCheckOverlay"
    overlay.position=Vector2(800,730)
    overlay.z_index=90
    scene.add_child(overlay)
    overlay.initialize(scene.get_node("Skeleton2D") as Skeleton2D)
    overlay.show_goals=false
    overlay.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _save(OUTPUT.path_join("bind-with-bones.png")):
        quit(1)
        return
    overlay.visible=false
    for action in ["idle","walk","attack_sword"]:
        var target:=OUTPUT.path_join(action)
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target))
        var clip:=player.get_animation(action)
        for index in range(8):
            scene.play_motion(action)
            var ratio:=float(index)/float(7 if action=="attack_sword" else 8)
            player.seek(clip.length*ratio,true)
            player.pause()
            await process_frame
            await RenderingServer.frame_post_draw
            if not _save(target.path_join("frame-%02d.png"%index)):
                quit(1)
                return
    print("SHEN_CANDIDATE_BOUND_VISUAL_OK")
    quit(0)

func _save(path: String) -> bool:
    var image: Image=root.get_texture().get_image()
    if image==null or image.is_empty(): return false
    var region:=image.get_region(RECT)
    return region.save_png(path)==OK
