extends SceneTree
## Native map QA: load only one active zone and transfer through zone_exit markers.
const Scale = preload("res://scripts/combat_scale.gd")
const Bake = preload("res://scripts/map_bake.gd")
const ZoneConnection = preload("res://scripts/map_zone_connection.gd")
const Shift = preload("res://scripts/world_viewport_offset.gd")
const Spatial = preload("res://scripts/battle_spatial_service.gd")
const WEST := "res://data/maps/pingjiang_long_street_qa.tres"
const EAST := "res://data/maps/pingjiang_east_market_qa.tres"
const VERTICAL := "res://data/maps/pingjiang_north_lane_qa.tres"
var failures := 0

func check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("PINGJIANG_SCROLL: " + reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var west := load(WEST) as WuxiaMapDefinition
    var east := load(EAST) as WuxiaMapDefinition
    var north := load(VERTICAL) as WuxiaMapDefinition
    check(west != null and east != null and north != null, "three independent native maps exist")
    if west == null or east == null or north == null:
        quit(1)
        return
    check(west.viewport_size == Vector2i(4800, 1000)
        and east.viewport_size == Vector2i(3200, 1000)
        and north.viewport_size == Vector2i(1600, 4000), "local map canvases are exact")
    check(west.primary_axis == "horizontal" and east.primary_axis == "horizontal"
        and north.primary_axis == "vertical", "map orientations are explicit")
    for map in [west, east, north]:
        check(not map.to_record().is_empty(), "native map contract: " + map.content_id)
        check(map.background != null and Vector2i(map.background.get_size()) == map.viewport_size,
            "background is authored at true world size")
        check(map.scene_art != null and map.scene_art.valid_for(map.viewport_size),
            "all three scene art layers share a real world-sized canvas")
    var wb = Bake.new(WEST)
    var eb = Bake.new(EAST)
    var nb = Bake.new(VERTICAL)
    check(wb.error.is_empty() and eb.error.is_empty() and nb.error.is_empty(),
        "three map polygons bake")
    if not wb.error.is_empty() or not eb.error.is_empty() or not nb.error.is_empty():
        quit(1)
        return
    var radius := Scale.footprint_radius_pixels()
    check(radius == 24.0 and Scale.actor_height_pixels() == 200.0
        and wb.pixels_per_unit == Scale.PIXELS_PER_UNIT
        and eb.pixels_per_unit == Scale.PIXELS_PER_UNIT
        and nb.pixels_per_unit == Scale.PIXELS_PER_UNIT, "world scale remains unified")
    check(wb.is_walkable_point(Vector2(200, 790), radius)
        and wb.is_walkable_point(Vector2(4600, 790), radius)
        and eb.is_walkable_point(Vector2(200, 790), radius)
        and eb.is_walkable_point(Vector2(3000, 790), radius)
        and nb.is_walkable_point(Vector2(800, 100), radius)
        and nb.is_walkable_point(Vector2(800, 2000), radius)
        and nb.is_walkable_point(Vector2(800, 3900), radius), "street end points are walkable")
    check(not wb.is_walkable_point(Vector2(2400, 580), radius)
        and not eb.is_walkable_point(Vector2(1500, 975), radius)
        and not nb.is_walkable_point(Vector2(400, 2000), radius),
        "building fronts and outside-road points are blocked")
    check(Spatial.new(WEST).clear_segment(Vector2(200, 790), Vector2(4600, 790), radius)
        and Spatial.new(EAST).clear_segment(Vector2(200, 790), Vector2(3000, 790), radius)
        and Spatial.new(VERTICAL).clear_segment(Vector2(800, 100), Vector2(800, 3900), radius),
        "FREE movement spans each independent map")
    var west_gate: Dictionary = wb.markers.get("street_end", {})
    var east_gate: Dictionary = eb.markers.get("east_entry", {})
    var north_gate: Dictionary = eb.markers.get("to_north", {})
    var south_gate: Dictionary = nb.markers.get("to_south", {})
    check(west_gate.get("kind", "") == "zone_exit"
        and west_gate.get("exit_side", "") == "east"
        and west_gate.get("target_zone_id", "") == east.content_id
        and west_gate.get("target_entry_id", "") == "from_west"
        and east_gate.get("kind", "") == "zone_exit"
        and east_gate.get("exit_side", "") == "west"
        and east_gate.get("target_zone_id", "") == west.content_id
        and east_gate.get("target_entry_id", "") == "from_east",
        "reciprocal horizontal exits use separate entry spawn markers")
    check(north_gate.get("kind", "") == "zone_exit"
        and north_gate.get("exit_side", "") == "north"
        and north_gate.get("target_zone_id", "") == north.content_id
        and north_gate.get("target_entry_id", "") == "from_south"
        and south_gate.get("kind", "") == "zone_exit"
        and south_gate.get("exit_side", "") == "south"
        and south_gate.get("target_zone_id", "") == east.content_id
        and south_gate.get("target_entry_id", "") == "from_north",
        "east market north gate and vertical south gate form a returnable route")
    for route in [
        [wb, "street_end", eb, "from_west", Vector2(400, 790)],
        [eb, "east_entry", wb, "from_east", Vector2(4380, 790)],
        [eb, "to_north", nb, "from_south", Vector2(800, 3500)],
        [nb, "to_south", eb, "from_north", Vector2(1320, 845)]]:
        var resolved: Dictionary = ZoneConnection.resolve_exit(route[0], route[1], route[2], radius)
        check(resolved.get("target_zone_id", "") == route[2].id
            and resolved.get("target_entry_id", "") == route[3]
            and resolved.get("spawn", Vector2.INF) == route[4],
            "native exit resolves to a walkable spawn: " + str(route[1]))
    check(ZoneConnection.resolve_exit(wb, "street_mid", eb, radius).is_empty()
        and ZoneConnection.resolve_exit(wb, "street_end", nb, radius).is_empty(),
        "non-exit markers and mismatched target zones reject routing")
    check(nb.markers.has("south_start") and nb.markers.has("lane_middle"),
        "vertical map keeps its original direct-menu spawn and local anchors")
    check(Shift.world_offset(Vector2(4600, 790), Vector2(4800, 1000)) == Vector2(-3200, 0)
        and Shift.world_offset(Vector2(200, 790), Vector2(3200, 1000)) == Vector2.ZERO,
        "horizontal camera resets at the new map, not a stitched world seam")
    check(Shift.world_offset(Vector2(800, 100), Vector2(1600, 4000)) == Vector2.ZERO
        and Shift.world_offset(Vector2(800, 2000), Vector2(1600, 4000)) == Vector2(0, -1500)
        and Shift.world_offset(Vector2(800, 3900), Vector2(1600, 4000)) == Vector2(0, -3000),
        "4000px vertical camera scrolls and clamps in Y")
    check(Shift.screen_to_world(Vector2(800, 500), Vector2(0, -1500)) == Vector2(800, 2000),
        "vertical camera screen-to-world pointer transform is correct")
    var title := FileAccess.get_file_as_string("res://scripts/opening_flow.gd")
    check(title.contains("\"pingjiang_qa\"") and title.contains("\"pingjiang_vertical_qa\"")
        and title.contains("res://scenes/pingjiang_scroll_qa.tscn")
        and title.contains("res://scenes/pingjiang_vertical_qa.tscn"),
        "isolated P and V menu shortcuts exist")

    var horizontal_packed := load("res://scenes/pingjiang_scroll_qa.tscn") as PackedScene
    check(horizontal_packed != null, "horizontal QA scene loads")
    if horizontal_packed != null:
        var visual: Node2D = horizontal_packed.instantiate() as Node2D
        root.add_child(visual)
        await process_frame
        var stage: Node2D = visual.get("stage")
        var player: Node2D = visual.get("player")
        check(stage != null and player != null and visual.get("actor_sprite") != null,
            "first map and actor atlas instantiate")
        if stage != null and player != null:
            check(stage.get_node_or_null(west.content_id) != null
                and stage.get_node_or_null(east.content_id) == null,
                "only current west map is mounted")
            check(not bool(visual.call("_activate_exit", "street_end")),
                "cannot activate distant exit")
            player.position = Vector2(4600, 790)
            visual.call("_update_camera_and_status")
            check(stage.position == Vector2(-3200, 0), "west camera clamps at local edge")
            check(bool(visual.call("_activate_exit", "street_end")), "E connector loads east")
            check(str(visual.get("current_region_id")) == east.content_id
                and int(visual.get("crossing_count")) == 1
                and player.position == Vector2(400, 790),
                "east map uses a dedicated spawn separate from its exit")
            check(stage.get_node_or_null(west.content_id) == null
                and stage.get_node_or_null(east.content_id) != null
                and stage.position == Vector2.ZERO,
                "old zone is unloaded and camera origin resets")
            player.position = Vector2(1600, 790)
            visual.call("_update_camera_and_status")
            check(stage.position == Vector2(-800, 0), "east local camera follows")
            var click := InputEventMouseButton.new()
            click.position = Vector2(800, 790)
            click.button_index = MOUSE_BUTTON_LEFT
            click.pressed = true
            visual.call("_unhandled_input", click)
            check(visual.get("last_world_click") == Vector2(1600, 790),
                "second map uses local mouse inverse")
            check(not bool(visual.call("_activate_exit", "east_entry")),
                "remote exit remains inaccessible")
            player.position = Vector2(200, 790)
            check(bool(visual.call("_activate_exit", "east_entry")),
                "east-to-west return via target marker succeeds")
            check(str(visual.get("current_region_id")) == west.content_id
                and int(visual.get("crossing_count")) == 2
                and player.position == Vector2(4380, 790),
                "return uses dedicated west-map spawn and transition count")
            check(stage.get_node_or_null(east.content_id) == null
                and stage.get_node_or_null(west.content_id) != null,
                "return again has exactly one mounted map")
        visual.queue_free()
        await process_frame

    var vertical_packed := load("res://scenes/pingjiang_vertical_qa.tscn") as PackedScene
    check(vertical_packed != null, "vertical QA scene loads")
    if vertical_packed != null:
        var visual_v: Node2D = vertical_packed.instantiate() as Node2D
        root.add_child(visual_v)
        await process_frame
        var stage_v: Node2D = visual_v.get("stage")
        var player_v: Node2D = visual_v.get("player")
        check(stage_v != null and player_v != null
            and str(visual_v.get("current_region_id")) == north.content_id,
            "vertical scene starts on its own native map")
        if stage_v != null and player_v != null:
            check(player_v.position == Vector2(800, 3700)
                and stage_v.position == Vector2(0, -3000),
                "south spawn shows the end of the Y=4000 map")
            player_v.position = Vector2(800, 2000)
            visual_v.call("_update_camera_and_status")
            check(stage_v.position == Vector2(0, -1500), "Y scrolling follows to middle")
            var click_v := InputEventMouseButton.new()
            click_v.position = Vector2(800, 500)
            click_v.button_index = MOUSE_BUTTON_LEFT
            click_v.pressed = true
            visual_v.call("_unhandled_input", click_v)
            check(visual_v.get("last_world_click") == Vector2(800, 2000),
                "vertical pointer maps back to Y=2000")
            player_v.position = Vector2(800, 100)
            visual_v.call("_update_camera_and_status")
            check(stage_v.position == Vector2.ZERO, "north camera clamps at zero")
            player_v.position = Vector2(800, 3860)
            check(bool(visual_v.call("_activate_exit", "to_south")),
                "vertical south exit loads east-market map on E interaction")
            check(str(visual_v.get("current_region_id")) == east.content_id
                and player_v.position == Vector2(1320, 845)
                and stage_v.get_node_or_null(north.content_id) == null
                and stage_v.get_node_or_null(east.content_id) != null,
                "vertical map unloads and enters east through a distinct north entry")
            check(not bool(visual_v.call("_activate_exit", "to_north")),
                "target spawn does not immediately activate the nearby north exit")
            player_v.position = Vector2(1305, 700)
            check(bool(visual_v.call("_activate_exit", "to_north")),
                "east north gate returns to the vertical street")
            check(str(visual_v.get("current_region_id")) == north.content_id
                and player_v.position == Vector2(800, 3500)
                and int(visual_v.get("crossing_count")) == 2
                and stage_v.position == Vector2(0, -3000),
                "vertical entry is named, walkable and camera-clamped correctly")
        visual_v.queue_free()
        await process_frame
    print("PINGJIANG_SCROLL_PASS failures=%d" % failures)
    quit(1 if failures > 0 else 0)
