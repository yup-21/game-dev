extends SceneTree
## Integration: two REAL layered native maps, a world-space seam, menu entry and camera tracking.
const Scale = preload("res://scripts/combat_scale.gd")
const Bake = preload("res://scripts/map_bake.gd")
const Shift = preload("res://scripts/world_viewport_offset.gd")
const Spatial = preload("res://scripts/battle_spatial_service.gd")
const MAP_PATH := "res://data/maps/pingjiang_long_street_qa.tres"
const EAST_PATH := "res://data/maps/pingjiang_east_market_qa.tres"
const SEAM_X := 4800.0
const WORLD_SIZE := Vector2(8000, 1000)
var failures := 0

func check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("PINGJIANG_SCROLL: " + reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var west := load(MAP_PATH) as WuxiaMapDefinition
    var east := load(EAST_PATH) as WuxiaMapDefinition
    check(west != null and east != null, "both independent region Resources are importable")
    if west == null or east == null:
        quit(1)
        return
    check(west.content_id != east.content_id, "stitched areas have separate native map identities")
    check(west.viewport_size == Vector2i(4800, 1000)
        and east.viewport_size == Vector2i(3200, 1000),
        "three-screen main road joins a two-screen east market, making five screens")
    for map in [west, east]:
        check(map.primary_axis == "horizontal" and map.to_record().size() > 0,
            "each region passes native horizontal map validation")
        check(map.background != null and Vector2i(map.background.get_size()) == map.viewport_size,
            "each background is native-sized, not a stretched single viewport")
        check(map.scene_art != null and map.scene_art.valid_for(map.viewport_size),
            "each independent three-layer profile matches its map dimensions")
    var west_bake = Bake.new(MAP_PATH)
    var east_bake = Bake.new(EAST_PATH)
    check(west_bake.error.is_empty() and west_bake.polygon_mode
        and east_bake.error.is_empty() and east_bake.polygon_mode,
        "both adjacent map polygons bake successfully")
    if not west_bake.error.is_empty() or not east_bake.error.is_empty():
        quit(1)
        return
    check(is_equal_approx(west_bake.pixels_per_unit, Scale.PIXELS_PER_UNIT)
        and is_equal_approx(east_bake.pixels_per_unit, Scale.PIXELS_PER_UNIT),
        "80px game-unit scale remains identical across regions")
    var radius := Scale.footprint_radius_pixels()
    var left := Vector2(200, 790)
    var center := Vector2(2400, 790)
    var west_end := Vector2(4600, 790)
    var east_begin := Vector2(200, 790)
    var east_middle := Vector2(1600, 790)
    var east_end := Vector2(3000, 790)
    check(west_bake.is_walkable_point(left, radius)
        and west_bake.is_walkable_point(center, radius)
        and west_bake.is_walkable_point(west_end, radius),
        "three samples in the original main road stay walkable")
    check(east_bake.is_walkable_point(east_begin, radius)
        and east_bake.is_walkable_point(east_middle, radius)
        and east_bake.is_walkable_point(east_end, radius),
        "the second map has its own continuous walkable road")
    check(not west_bake.is_walkable_point(Vector2(2400, 580), radius)
        and not east_bake.is_walkable_point(Vector2(1500, 975), radius),
        "both area polygons reject buildings and outside-road points")
    var west_space = Spatial.new(MAP_PATH)
    var east_space = Spatial.new(EAST_PATH)
    check(west_space.is_valid_position(left, radius)
        and west_space.clear_segment(left, west_end, radius)
        and east_space.is_valid_position(east_begin, radius)
        and east_space.clear_segment(east_begin, east_end, radius),
        "each region permits continuous FREE navigation over its street segment")
    check(west_bake.markers.has("player_start") and west_bake.markers.has("street_end")
        and east_bake.markers.has("east_entry") and east_bake.markers.has("east_exit"),
        "each region retains separate placement markers")
    check(Shift.world_offset(left, WORLD_SIZE) == Vector2.ZERO
        and Shift.world_offset(center, WORLD_SIZE) == Vector2(-1600, 0)
        and Shift.world_offset(Vector2(4900, 790), WORLD_SIZE) == Vector2(-4100, 0)
        and Shift.world_offset(Vector2(7800, 790), WORLD_SIZE) == Vector2(-6400, 0),
        "five-screen camera follows across the seam and clamps only at world edges")
    var screen := Vector2(800, 790)
    var camera_offset := Shift.world_offset(Vector2(4900, 790), WORLD_SIZE)
    check(Shift.screen_to_world(screen, camera_offset) == Vector2(4900, 790)
        and Shift.world_to_screen(Vector2(4900, 790), camera_offset) == screen,
        "pointer coordinates remain invertible in the neighboring map")
    check(Scale.actor_height_pixels() == 200.0 and radius == 24.0,
        "actor visual/footprint scale is unchanged across regions")
    var title_script := FileAccess.get_file_as_string("res://scripts/opening_flow.gd")
    check(title_script.contains("\"pingjiang_qa\"")
        and title_script.contains("res://scenes/pingjiang_scroll_qa.tscn"),
        "title menu retains a dedicated isolated Pingjiang test entry")
    # Instantiate the playable scene and drive the same methods used by input.
    var packed := load("res://scenes/pingjiang_scroll_qa.tscn") as PackedScene
    check(packed != null, "menu destination is a loadable playable PackedScene")
    if packed != null:
        var visual: Node2D = packed.instantiate() as Node2D
        root.add_child(visual)
        await process_frame
        var stage: Node2D = visual.get("stage")
        var player: Node2D = visual.get("player")
        var sprite: Sprite2D = visual.get("actor_sprite")
        check(stage != null and player != null and sprite != null,
            "both layered map regions instantiate with Shen Changfeng's real sprite")
        if stage != null and player != null:
            check(stage.get_node_or_null("pingjiang_long_street_qa") != null
                and stage.get_node_or_null("pingjiang_east_market_qa") != null,
                "two independently sized art regions are mounted beside one another")
            check(stage.position == Vector2.ZERO, "camera begins at western clamp")
            check(visual.call("_region_index_at_x", SEAM_X - 1.0) == 0
                and visual.call("_region_index_at_x", SEAM_X) == 1,
                "seam changes the active area at exactly world X=4800")
            check(visual.call("_walkable_world_point", Vector2(4790, 790), radius)
                and visual.call("_walkable_world_point", Vector2(4800, 790), radius)
                and visual.call("_walkable_world_point", Vector2(4810, 790), radius),
                "footprint passes from western polygon through shared seam into east")
            check(not visual.call("_walkable_world_point", Vector2(4800, 580), radius)
                and not visual.call("_walkable_world_point", Vector2(4800, 975), radius),
                "seam bypass cannot be used to leave the road")
            player.position = center
            visual.call("_update_camera_and_status")
            check(stage.position == Vector2(-1600, 0),
                "real scrolling scene follows the player into main-road center")
            player.position = Vector2(4770, 790)
            visual.set("goal", Vector2(5150, 790))
            visual.call("_process", 0.15)
            check(player.position.x > SEAM_X
                and int(visual.get("current_region_index")) == 1
                and int(visual.get("crossing_count")) == 1,
                "walking movement crosses east and increments transition count")
            check(stage.position.x < -4000.0,
                "camera keeps moving continuously during the crossing")
            visual.set("goal", Vector2(4530, 790))
            visual.call("_process", 0.15)
            check(player.position.x < SEAM_X
                and int(visual.get("current_region_index")) == 0
                and int(visual.get("crossing_count")) == 2,
                "walking back west returns to the previous region without teleport")
            player.position = Vector2(7800, 790)
            visual.call("_update_camera_and_status")
            check(stage.position == Vector2(-6400, 0),
                "real scene clamps camera after reaching the end of east market")
            check(visual.has_method("_return_to_menu"),
                "Esc navigation back to demo title is available")
        visual.queue_free()
        await process_frame
    print("PINGJIANG_SCROLL_PASS failures=%d" % failures)
    quit(1 if failures > 0 else 0)
