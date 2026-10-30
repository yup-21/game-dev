extends SceneTree
## Minimal windowed evidence of the real first-act and wounded elder.
## Script entry avoids driving an entire dialogue graph during a GPU readback.
const OUTPUT := "res://captures/"

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("STORY_CAPTURE_FAILED: " + reason)
    quit(1)

func _capture(name: String) -> bool:
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        return false
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
    var file := OUTPUT + name + ".png"
    if image.save_png(file) != OK:
        return false
    # Visible painted scene is required; a white/empty screenshot is failure.
    var scenic := 0
    for fy in [0.24,0.41,0.59,0.72]:
        for fx in [0.13,0.29,0.45,0.61,0.78,0.89]:
            var pixel: Color = image.get_pixel(
                mini(image.get_width()-1,int(image.get_width()*fx)),
                mini(image.get_height()-1,int(image.get_height()*fy)))
            if pixel.a > 0.9 and minf(pixel.r,minf(pixel.g,pixel.b)) < 0.85:
                scenic += 1
    return scenic >= 10

func _run() -> void:
    if DisplayServer.get_name() == "headless":
        _fail("graphical display required")
        return
    var view: Variant = load("res://opening.tscn").instantiate()
    root.add_child(view)
    for _i in range(3):
        await process_frame
    view._enter_new_game()
    for _i in range(3):
        await process_frame
    view.story.skip_cinematic()
    view.player_pos = Vector2(1037,570)
    for _i in range(3):
        await process_frame
    if view.story.phase != "explore" or not view.characters_layer.visible:
        _fail("first-act exploration did not start")
        return
    if not await _capture("opening-explore"):
        _fail("first-act painting frame is empty or blank")
        return
    view._start_dialogue()
    for _i in range(3):
        await process_frame
    if view.story.phase != "dialogue":
        _fail("wounded elder interaction missing")
        return
    view.visible_characters = float(view.story.current_dialogue().text.length())
    if not await _capture("opening-dialogue"):
        _fail("wounded elder dialogue frame is empty or blank")
        return
    print("STORY_CAPTURE_PASS explore + elder-dialogue real scene frames")
    quit(0)
