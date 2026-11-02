extends SceneTree
## Visual acceptance capture for the isolated Shen Changfeng Bone2D pilot.
## Produces deterministic key frames for idle / walk / attack_sword / guard.
## GIF assembly is intentionally kept outside Godot so the scene remains pure.

const PROTOTYPE_SCENE := preload("res://prototypes/shen_bone2d/shen_bone2d_validation.tscn")
const OUTPUT := "res://captures/shen-bone2d/"
const CAPTURE_RECT := Rect2i(270, 150, 1060, 700)

var scene: Node
var player: AnimationPlayer


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    if DisplayServer.get_name() == "headless":
        _fail("Shen Bone2D visual capture requires a graphical display")
        return

    root.size = Vector2i(1600, 1000)
    scene = PROTOTYPE_SCENE.instantiate()
    root.add_child(scene)
    await process_frame
    await RenderingServer.frame_post_draw

    player = scene.get_node_or_null("AnimationPlayer") as AnimationPlayer
    if player == null:
        _fail("AnimationPlayer missing from Shen Bone2D prototype")
        return

    var output_dir := ProjectSettings.globalize_path(OUTPUT)
    DirAccess.make_dir_recursive_absolute(output_dir)

    var specs := {
        "idle": {"length": 1.20, "frames": 8},
        "walk": {"length": 0.80, "frames": 8},
        "attack_sword": {"length": 0.58, "frames": 8},
        "guard": {"length": 1.00, "frames": 8},
    }

    for action in ["idle", "walk", "attack_sword", "guard"]:
        var spec: Dictionary = specs[action]
        var length: float = float(spec["length"])
        var frame_count: int = int(spec["frames"])
        var action_dir := OUTPUT.path_join(action)
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(action_dir))
        for index in range(frame_count):
            var t := 0.0
            if frame_count > 1:
                # Loop clips stop just short of their wrap point. One-shot attack
                # includes the authored final pose so recovery can be judged.
                var end_ratio := 1.0 if action == "attack_sword" else float(frame_count - 1) / float(frame_count)
                t = length * end_ratio * float(index) / float(frame_count - 1)
            scene.call("_play", action)
            player.seek(t, true)
            player.pause()
            await process_frame
            await RenderingServer.frame_post_draw
            if not _capture_region(action_dir.path_join("frame-%02d.png" % index)):
                quit(1)
                return

    # Keep one full-frame scene capture for scale/baseline review.
    scene.call("_play", "idle")
    player.seek(0.6, true)
    player.pause()
    await process_frame
    await RenderingServer.frame_post_draw
    if not _capture_full(OUTPUT.path_join("overview.png")):
        quit(1)
        return

    print("SHEN_BONE2D_VISUAL_EVIDENCE_OK ", output_dir)
    quit(0)


func _capture_region(target: String) -> bool:
    var full: Image = root.get_texture().get_image()
    if full == null or full.is_empty():
        push_error("Bone2D capture returned an empty viewport image")
        return false
    if not Rect2i(Vector2i.ZERO, full.get_size()).encloses(CAPTURE_RECT):
        push_error("Bone2D capture rectangle lies outside the viewport")
        return false
    var cropped := full.get_region(CAPTURE_RECT)
    if cropped == null or cropped.is_empty():
        push_error("Bone2D cropped image is empty")
        return false
    if cropped.save_png(target) != OK:
        push_error("Could not save Bone2D capture: " + target)
        return false
    print("SHEN_BONE2D_FRAME ", ProjectSettings.globalize_path(target))
    return true


func _capture_full(target: String) -> bool:
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty() or image.get_size() != Vector2i(1600, 1000):
        push_error("Bone2D full-frame capture resolution mismatch")
        return false
    if image.save_png(target) != OK:
        push_error("Could not save Bone2D overview: " + target)
        return false
    print("SHEN_BONE2D_OVERVIEW ", ProjectSettings.globalize_path(target))
    return true


func _fail(message: String) -> void:
    push_error(message)
    quit(1)
