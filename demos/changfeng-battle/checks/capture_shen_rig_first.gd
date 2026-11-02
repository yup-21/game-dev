extends SceneTree
## Captures the skeleton template before drawing artwork to match it.
const SCENE := preload("res://prototypes/shen_rig_first/shen_skeleton_first.tscn")
const OUTPUT := "res://captures/shen-rig-first/"
const RECT := Rect2i(585, 468, 440, 300)

var scene: Node
var player: AnimationPlayer

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Rig-first capture requires xvfb/graphical viewport")
        quit(1)
        return
    root.size = Vector2i(1600, 1000)
    scene = SCENE.instantiate()
    root.add_child(scene)
    await process_frame
    player = scene.get_node("AnimationPlayer") as AnimationPlayer
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
    scene.show_bind_pose()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _grab(OUTPUT.path_join("bind-pose.png"), true):
        quit(1)
        return
    for action in ["idle", "walk", "attack_sword"]:
        var output := OUTPUT.path_join(action)
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
        var clip := player.get_animation(action)
        for i in range(8):
            scene.play_motion(action)
            var t: float = clip.length * float(i) / float(7 if action == "attack_sword" else 8)
            player.seek(t, true)
            player.pause()
            await process_frame
            await RenderingServer.frame_post_draw
            if not _grab(output.path_join("frame-%02d.png" % i), true):
                quit(1)
                return
    scene.show_bind_pose()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _grab(OUTPUT.path_join("scene-overview.png"), false):
        quit(1)
        return
    print("SHEN_RIG_FIRST_VISUAL_OK")
    quit(0)

func _grab(path: String, crop: bool) -> bool:
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("Rig-first viewport returned no image")
        return false
    if crop:
        image = image.get_region(RECT)
    if image.save_png(path) != OK:
        push_error("Cannot save rig-first visual: " + path)
        return false
    return true
