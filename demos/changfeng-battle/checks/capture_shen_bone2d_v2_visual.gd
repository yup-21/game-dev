extends SceneTree
## Visual evidence for Shen Changfeng v2 hybrid Bone2D rig.

const SCENE := preload("res://prototypes/shen_bone2d_v2/shen_bone2d_v2_validation.tscn")
const OUTPUT := "res://captures/shen-bone2d-v2/"
# Close crop for checking shoulders, hands, knees and boot contact.
# The full overview remains 1600x1000 at the true 200px game scale.
const CAPTURE_RECT := Rect2i(575, 450, 450, 350)

var scene: Node
var player: AnimationPlayer

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Bone2D v2 visual capture requires graphical display")
        quit(1)
        return
    root.size = Vector2i(1600, 1000)
    scene = SCENE.instantiate()
    root.add_child(scene)
    await process_frame
    await RenderingServer.frame_post_draw
    player = scene.get_node_or_null("AnimationPlayer") as AnimationPlayer
    if player == null:
        push_error("Bone2D v2 AnimationPlayer missing")
        quit(1)
        return

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
    var specs := {
        "idle": [1.20, 8],
        "walk": [0.80, 8],
        "attack_sword": [0.68, 8],
        "guard": [1.00, 8],
    }
    for action in ["idle", "walk", "attack_sword", "guard"]:
        var length: float = float(specs[action][0])
        var count: int = int(specs[action][1])
        var folder := OUTPUT.path_join(action)
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
        for index in range(count):
            var end_ratio := 1.0 if action == "attack_sword" else float(count - 1) / float(count)
            var time := length * end_ratio * float(index) / float(count - 1)
            scene.call("_play", action)
            player.seek(time, true)
            player.pause()
            await process_frame
            await RenderingServer.frame_post_draw
            if not _capture(folder.path_join("frame-%02d.png" % index), true):
                quit(1)
                return

    scene.call("_play", "idle")
    player.seek(0.6, true)
    player.pause()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _capture(OUTPUT.path_join("overview.png"), false):
        quit(1)
        return
    print("SHEN_BONE2D_V2_VISUAL_OK")
    quit(0)

func _capture(path: String, crop: bool) -> bool:
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("v2 capture image empty")
        return false
    if crop:
        image = image.get_region(CAPTURE_RECT)
    if image.save_png(path) != OK:
        push_error("cannot save " + path)
        return false
    print("SHEN_BONE2D_V2_CAPTURE ", ProjectSettings.globalize_path(path))
    return true
