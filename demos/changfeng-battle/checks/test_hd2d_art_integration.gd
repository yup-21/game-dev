extends SceneTree
const StoryFixture = preload("res://checks/story_test_helper.gd")
## Regression: committed character/landscape artwork is consumed by both runtime scenes.
## Run after Godot's import pass:
## godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_art_integration.gd
const Catalog = preload("res://scripts/hd2d_art_catalog.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("HD2D_ART: " + message)
    quit(1)

func _run() -> void:
    for actor_id in [0, 1, 2, 3, 4, 5]:
        if not Catalog.uses_supplied_sheet(actor_id):
            _fail("no art mapping for actor %d" % actor_id)
            return
        var texture: Texture2D = Catalog.sheet_for_actor(actor_id, actor_id > 3)
        var image: Image = texture.get_image()
        if image.get_size() != Vector2i(1536, 1024):
            _fail("wrong atlas size for actor %d" % actor_id)
            return
        if image.get_pixel(0, 0).a > 0.04:
            _fail("background still opaque for actor %d" % actor_id)
            return
        var idle: Image = image.get_region(Rect2i(0, 0, 256, 256))
        var attack: Image = image.get_region(Rect2i(0, 512, 256, 256))
        if idle.get_data() == attack.get_data():
            _fail("identical idle and attack art for actor %d" % actor_id)
            return
    for name in ["沈长风", "老镖头", "顾清霜"]:
        var portrait: Texture2D = Catalog.portrait(name)
        if portrait == null or portrait.get_width() < 512:
            _fail("portrait unavailable: " + name)
            return
    for scene_id in ["mountain", "snow", "rainy_bridge"]:
        var landscape: Texture2D = Catalog.scenery(scene_id)
        if landscape == null or landscape.get_width() < 1024:
            _fail("landscape unavailable: " + scene_id)
            return

    var standalone: Node = load("res://battle_hd2d.tscn").instantiate()
    root.add_child(standalone)
    await process_frame
    if standalone.get("illustrated_map") == null or standalone.get("illustrated_map").picture.texture == null:
        _fail("standalone battle does not render its full 2D painted terrain")
        return
    standalone.queue_free()
    await process_frame

    var session = root.get_node_or_null("GameSession")
    if session == null:
        _fail("GameSession autoload unavailable")
        return
    session.start_new_game()
    StoryFixture.finish_prologue(session)
    if not session.begin_encounter():
        _fail("prologue encounter did not start")
        return
    var battle: Node = load("res://battle_hd2d.tscn").instantiate()
    root.add_child(battle)
    await process_frame
    var battle_map = battle.get("illustrated_map")
    if battle_map == null or battle_map.picture.texture == null:
        _fail("rainy story scene does not display the full 2D bridge background")
        return
    for actor_id in [0, 1, 2, 3, 4, 5]:
        var sprite: Sprite2D = battle_map.actors[actor_id].get_node_or_null("ActionSprite") as Sprite2D
        if sprite == null or sprite.texture != Catalog.sheet_for_actor(actor_id, actor_id > 3):
            _fail("story actor %d is not displaying the supplied atlas" % actor_id)
            return
        if sprite.hframes != 6 or sprite.vframes != 4:
            _fail("animation frame layout changed for actor %d" % actor_id)
            return
    if battle.get("model").state.seed != session.encounter_seed():
        _fail("presentation changed authoritative encounter seed")
        return
    if OS.get_cmdline_user_args().has("--capture"):
        if DisplayServer.get_name() == "headless":
            _fail("--capture requires a graphical display")
            return
        await RenderingServer.frame_post_draw
        var path := "res://captures/hd2d-validation/05-story-art.png"
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
        var screenshot: Image = root.get_viewport().get_texture().get_image()
        if screenshot == null or screenshot.is_empty() or screenshot.save_png(path) != OK:
            _fail("story battle screenshot could not be saved")
            return
        print("HD2D_CAPTURE ", ProjectSettings.globalize_path(path))
    print("HD2D_ART_PASS 6 pose sheets, 3 portraits, 3 scenery assets, 2D bridge and 6 actors")
    quit(0)
