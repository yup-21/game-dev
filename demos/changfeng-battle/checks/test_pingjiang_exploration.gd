extends SceneTree
## Four native areas: collision-safe continuous walking, six real transitions,
## safe arrivals, atomic failure, camera bounds and original QA entries.
const Bake = preload("res://scripts/map_bake.gd")
const Scale = preload("res://scripts/combat_scale.gd")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")
const ViewportShift = preload("res://scripts/world_viewport_offset.gd")
var failures := 0

func check(ok: bool, note: String) -> void:
    if not ok:
        failures += 1
        push_error("PINGJIANG_EXPLORATION: " + note)

func _initialize() -> void:
    call_deferred("_run")

# Walk via the real input/process path, not by teleporting to each exit.
func walk(scene: Node2D, points: Array) -> void:
    for destination in points:
        check(scene.bake.is_walkable_point(destination, 24.0), "walkable waypoint %s" % destination)
        scene.goal = destination
        for step in range(2000):
            scene._process(1.0 / 60.0)
            check(scene.bake.is_walkable_point(scene.player.position, 24.0), "24px feet stay on ground")
            if scene.player.position.distance_to(destination) <= 3.0:
                break
        check(scene.player.position.distance_to(destination) <= 3.0,
            "can reach waypoint %s from real movement" % destination)

func check_camera_bounds(scene: Node2D) -> void:
    var region_size: Vector2 = scene.regions[scene.current_region_id]["size"]
    var visible_size: Vector2 = ViewportShift.VIEWPORT_SIZE / scene.camera_zoom
    var world_top_left: Vector2 = -scene.stage.position / scene.camera_zoom
    check(world_top_left.x >= -0.01 and world_top_left.y >= -0.01
        and world_top_left.x + visible_size.x <= region_size.x + 0.01
        and world_top_left.y + visible_size.y <= region_size.y + 0.01,
        "zoomed camera remains within %s world bounds" % scene.current_region_id)

func capture(scene: Node2D, label: String) -> void:
    var folder := OS.get_environment("PINGJIANG_CAPTURE_DIR")
    if folder.is_empty():
        return
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    check(not image.is_empty(), "rendered frame " + label)
    DirAccess.make_dir_recursive_absolute(folder)
    check(image.save_png(folder.path_join(label + ".png")) == OK, "save screenshot " + label)

func _run() -> void:
    var cross = Bake.new("res://data/maps/pingjiang_crossroads.tres")
    check(cross.error.is_empty(), "PJ-02 native map validates: " + cross.error)
    if not cross.error.is_empty():
        quit(1)
        return
    for point in [Vector2(780, 220), Vector2(780, 400), Vector2(800, 680),
            Vector2(80, 680), Vector2(1520, 680), Vector2(800, 930)]:
        check(cross.is_walkable_point(point, 24.0), "four-direction ground %s" % point)
    for point in [Vector2(300, 350), Vector2(1300, 350), Vector2(200, 900), Vector2(1400, 900)]:
        check(not cross.is_walkable_point(point, 24.0), "buildings excluded %s" % point)
    var map := load("res://data/maps/pingjiang_crossroads.tres") as WuxiaMapDefinition
    check(map.primary_axis == "mixed" and map.scene_art.valid_for(Vector2i(1600, 1000)),
        "PJ-02 mixed-axis three-layer resource")
    for layer in [map.scene_art.background, map.scene_art.ground, map.scene_art.foreground]:
        check(layer != null and layer.get_image().get_format() == Image.FORMAT_RGBA8,
            "same-origin real RGBA artwork")
    var scene := load("res://scenes/pingjiang_exploration.tscn").instantiate() as Node2D
    root.add_child(scene)
    await process_frame
    scene.set_process(false)
    check(scene.current_region_id == "pingjiang_south_gate_qa", "starts at PJ-01 south")
    check(is_equal_approx(scene.camera_zoom, 1.375)
        and is_equal_approx(scene.actor_display_scale, 0.85)
        and scene.stage.scale.is_equal_approx(Vector2(1.375, 1.375)),
        "four-area scene alone defaults to 170px actor and 1.375x camera")
    var sprite: Sprite2D = scene.actor_sprite
    check(sprite != null, "four-area explorer uses the native actor Atlas")
    if sprite != null:
        var frame_bounds: Rect2i = VisualScale._opaque_bounds(sprite.texture,
            sprite.hframes, sprite.vframes, sprite.frame)
        check(absf(float(frame_bounds.size.y) * sprite.scale.y
            - 170.0) < 1.0,
            "visible actor height is 170px in world space")
    check(scene.enable_view_controls and scene.view_settings_panel != null
        and scene.actor_height_slider != null and scene.camera_zoom_slider != null
        and scene.view_summary != null,
        "F4 view adjustment panel is available only in four-area exploration")
    if scene.view_settings_panel != null:
        var toggle := InputEventKey.new()
        toggle.keycode = KEY_F4
        toggle.pressed = true
        scene._unhandled_input(toggle)
        check(not scene.view_settings_panel.visible, "F4 hides adjustment panel")
        scene._unhandled_input(toggle)
        check(scene.view_settings_panel.visible, "F4 restores adjustment panel")
    if scene.actor_height_slider != null and scene.camera_zoom_slider != null:
        scene.actor_height_slider.value = 180.0
        scene.camera_zoom_slider.value = 1.5
        check(is_equal_approx(scene.actor_display_scale, 0.9)
            and is_equal_approx(scene.camera_zoom, 1.5)
            and scene.stage.scale.is_equal_approx(Vector2(1.5, 1.5)),
            "sliders live-update both actor and map camera")
        check(scene.view_summary.text.contains("270px"),
            "view panel shows effective on-screen actor size after zoom")
        if sprite != null:
            var changed_bounds: Rect2i = VisualScale._opaque_bounds(sprite.texture,
                sprite.hframes, sprite.vframes, sprite.frame)
            check(absf(float(changed_bounds.size.y) * sprite.scale.y - 180.0) < 1.0,
                "changing slider height reuses native atlas without cumulative scaling")
        check_camera_bounds(scene)
        scene._reset_view_settings()
        check(is_equal_approx(scene.camera_zoom, 1.375)
            and is_equal_approx(scene.actor_display_scale, 0.85)
            and is_equal_approx(scene.actor_height_slider.value, 170.0),
            "reset restores 170px and 1.375x defaults")
    check_camera_bounds(scene)
    await capture(scene, "01_south_gate_south")
    walk(scene, [Vector2(800, 1000), Vector2(800, 80)])
    check_camera_bounds(scene)
    await capture(scene, "02_south_gate_north")
    check(scene._activate_exit("north"), "PJ-01 north -> PJ-02 south")
    check(scene.current_region_id == "pingjiang_crossroads", "real PJ-02 mounted")
    check_camera_bounds(scene)
    check(scene._nearby_exit().is_empty(), "PJ-02 safe arrival outside trigger")
    # The future north/east routes cannot silently load a test placeholder.
    walk(scene, [Vector2(800, 680), Vector2(780, 220)])
    var prior = scene.region_node
    check(not scene._activate_exit("north") and scene.region_node == prior,
        "unbuilt north neighbour leaves active world intact")
    walk(scene, [Vector2(780, 680), Vector2(1520, 680)])
    check(not scene._activate_exit("east") and scene.region_node == prior,
        "unbuilt east neighbour leaves active world intact")
    walk(scene, [Vector2(800, 680)])
    # Simulate a screen click after the camera has panned and scaled the stage.
    var clicked_world := Vector2(800, 680)
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    click.position = ViewportShift.world_to_screen(clicked_world,
        scene.stage.position, scene.camera_zoom)
    scene._unhandled_input(click)
    check(scene.last_world_click.distance_to(clicked_world) < 0.01
        and scene.goal.distance_to(clicked_world) < 0.01,
        "zoomed mouse click resolves to original map/world coordinates")
    scene.goal = Vector2.INF
    await capture(scene, "03_crossroads")
    walk(scene, [Vector2(80, 680)])
    check(scene._activate_exit("west"), "PJ-02 west -> PJ-03 east")
    check(scene.current_region_id == "pingjiang_riverside_market" and scene._nearby_exit().is_empty(),
        "PJ-03 safe east arrival")
    check_camera_bounds(scene)
    await capture(scene, "04_market_east")
    walk(scene, [Vector2(2400, 715), Vector2(2400, 895)])
    await capture(scene, "05_market_south")
    check(scene._activate_exit("south"), "PJ-03 south -> PJ-04 north")
    check(scene.current_region_id == "pingjiang_shen_house" and scene._nearby_exit().is_empty(),
        "PJ-04 safe north arrival")
    check_camera_bounds(scene)
    walk(scene, [Vector2(850, 740)])
    await capture(scene, "06_shen_house")
    walk(scene, [Vector2(845, 338)])
    check(scene._activate_exit("north"), "PJ-04 -> PJ-03")
    check(scene._nearby_exit().is_empty(), "PJ-03 safe south arrival")
    walk(scene, [Vector2(2400, 715), Vector2(4720, 715)])
    check(scene._activate_exit("east"), "PJ-03 -> PJ-02")
    check(scene._nearby_exit().is_empty(), "PJ-02 safe west arrival")
    walk(scene, [Vector2(800, 680), Vector2(800, 930)])
    check(scene._activate_exit("south"), "PJ-02 -> PJ-01")
    check(scene.current_region_id == "pingjiang_south_gate_qa" and scene._nearby_exit().is_empty()
        and scene.crossing_count == 6, "six transitions finish at safe PJ-01 north spawn")
    for child in scene.stage.get_children():
        if child != scene.player:
            check(child == scene.region_node, "only one area mounted")
    check_camera_bounds(scene)
    check(is_zero_approx(scene.stage.position.y),
        "PJ-01 north camera clamps at world top after zoom")
    scene.queue_free()
    await process_frame
    print("PINGJIANG_FOUR_AREA_PASS failures=%d" % failures)
    quit(1 if failures else 0)
