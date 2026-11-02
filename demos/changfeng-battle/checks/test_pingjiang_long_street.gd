extends SceneTree
## Real native zone exits: independent map loads, reciprocal entry spawns,
## horizontal follow, 1600x4000 vertical follow and Demo menu routing.
const Scale = preload("res://scripts/combat_scale.gd")
const Bake = preload("res://scripts/map_bake.gd")
const Shift = preload("res://scripts/world_viewport_offset.gd")
const ZoneConnection = preload("res://scripts/map_zone_connection.gd")
const A_PATH := "res://data/maps/pingjiang_long_street_qa.tres"
const B_PATH := "res://data/maps/pingjiang_east_market_qa.tres"
const C_PATH := "res://data/maps/pingjiang_north_lane_qa.tres"
const A_ID := "pingjiang_long_street_qa"
const B_ID := "pingjiang_east_market_qa"
const C_ID := "pingjiang_north_lane_qa"
var failures := 0

func check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("PINGJIANG_ZONES: " + reason)

func _initialize() -> void:
    call_deferred("_run")

func _check_route(source, exit_id: String, target, entry_id: String,
        expected_spawn: Vector2, radius: float) -> void:
    var route: Dictionary = ZoneConnection.resolve_exit(source, exit_id, target, radius)
    check(not route.is_empty() and str(route.get("target_zone_id", "")) == target.id
        and str(route.get("target_entry_id", "")) == entry_id
        and route.get("spawn", Vector2.INF) == expected_spawn,
        "zone exit %s/%s resolves only to %s/%s" % [
            source.id, exit_id, target.id, entry_id])

func _run() -> void:
    var a := load(A_PATH) as WuxiaMapDefinition
    var b := load(B_PATH) as WuxiaMapDefinition
    var c := load(C_PATH) as WuxiaMapDefinition
    check(a != null and b != null and c != null,
        "three independently authored native map Resources are importable")
    if a == null or b == null or c == null:
        quit(1)
        return
    check(a.viewport_size == Vector2i(4800, 1000)
        and b.viewport_size == Vector2i(3200, 1000)
        and c.viewport_size == Vector2i(1600, 4000),
        "horizontal regions and vertical Y=4000 region have their own actual art sizes")
    check(a.primary_axis == "horizontal" and b.primary_axis == "horizontal"
        and c.primary_axis == "vertical",
        "vertical region is an actual Y-axis map, not a rotated horizontal image")
    for map in [a, b, c]:
        check(not map.to_record().is_empty(), "every map passes native .tres content validation")
        check(map.background != null and Vector2i(map.background.get_size()) == map.viewport_size,
            "background is native sized without 1600x1000 stretching")
        check(map.scene_art != null and map.scene_art.valid_for(map.viewport_size),
            "three image layers have the same native origin and scale")
        check(is_equal_approx(map.pixels_per_unit, Scale.PIXELS_PER_UNIT),
            "all three zones retain 80px/u")
    var ba = Bake.new(A_PATH)
    var bb = Bake.new(B_PATH)
    var bc = Bake.new(C_PATH)
    check(ba.error.is_empty() and bb.error.is_empty() and bc.error.is_empty()
        and ba.polygon_mode and bb.polygon_mode and bc.polygon_mode,
        "all three map collision polygons bake independently")
    if not ba.error.is_empty() or not bb.error.is_empty() or not bc.error.is_empty():
        quit(1)
        return
    var radius := Scale.footprint_radius_pixels()
    check(radius == 24.0 and Scale.actor_height_pixels() == 200.0,
        "map switching does not alter 200px actor/24px footprint contract")
    check(ba.is_walkable_point(Vector2(200, 790), radius)
        and ba.is_walkable_point(Vector2(2400, 790), radius)
        and bb.is_walkable_point(Vector2(1600, 790), radius),
        "both horizontal map polygons accept movement with a real footprint")
    check(bc.is_walkable_point(Vector2(800, 200), radius)
        and bc.is_walkable_point(Vector2(800, 2100), radius)
        and bc.is_walkable_point(Vector2(800, 3800), radius),
        "vertical map has one traversable corridor across its full Y range")
    check(not bc.is_walkable_point(Vector2(420, 2100), radius)
        and not bc.is_walkable_point(Vector2(1190, 2100), radius),
        "vertical map blocks flanking buildings without shrinking actor")
    _check_route(ba, "to_east", bb, "from_west", Vector2(400, 790), radius)
    _check_route(bb, "to_west", ba, "from_east", Vector2(4380, 790), radius)
    _check_route(bb, "to_north", bc, "from_south", Vector2(800, 3500), radius)
    _check_route(bc, "to_south", bb, "from_north", Vector2(1320, 835), radius)
    check(ZoneConnection.resolve_exit(ba, "street_mid", bb, radius).is_empty()
        and ZoneConnection.resolve_exit(ba, "to_east", bc, radius).is_empty(),
        "ordinary map markers and incorrect target maps cannot change regions")
    check(Shift.world_offset(Vector2(2400, 790), Vector2(4800, 1000))
        == Vector2(-1600, 0)
        and Shift.world_offset(Vector2(4650, 790), Vector2(4800, 1000))
        == Vector2(-3200, 0),
        "main street camera is clamped to its own 4800px width, not a stitched world")
    check(Shift.world_offset(Vector2(800, 3500), Vector2(1600, 4000))
        == Vector2(0, -3000)
        and Shift.world_offset(Vector2(800, 2100), Vector2(1600, 4000))
        == Vector2(0, -1600)
        and Shift.world_offset(Vector2(800, 200), Vector2(1600, 4000))
        == Vector2.ZERO,
        "vertical 4000px camera scrolls Y and clamps at both ends without X drift")
    var offset := Vector2(0, -1600)
    check(Shift.screen_to_world(Vector2(800, 500), offset) == Vector2(800, 2100)
        and Shift.world_to_screen(Vector2(800, 2100), offset) == Vector2(800, 500),
        "mouse hit conversion is invertible during vertical scrolling")
    var menu_code := FileAccess.get_file_as_string("res://scripts/opening_flow.gd")
    check(menu_code.contains("pingjiang_qa") and menu_code.contains("pingjiang_vertical_qa"),
        "Demo title has independent P horizontal and V vertical QA entries")
    var packed := load("res://scenes/pingjiang_scroll_qa.tscn") as PackedScene
    check(packed != null, "horizontal test entry can instantiate")
    if packed != null:
        var visual: Node2D = packed.instantiate()
        root.add_child(visual)
        await process_frame
        var stage: Node2D = visual.get("stage")
        var player: Node2D = visual.get("player")
        var sprite: Sprite2D = visual.get("actor_sprite")
        check(stage != null and player != null and sprite != null,
            "real actor Sprite2D instantiates in live horizontal QA scene")
        if stage != null and player != null:
            check(str(visual.get("active_zone_id")) == A_ID
                and stage.get_node_or_null("Region_" + A_ID) != null
                and stage.get_node_or_null("Region_" + B_ID) == null,
                "only main-road map art is initially loaded (not stitched)")
            player.position = Vector2(2400, 790)
            visual.call("_update_camera_and_status")
            check(stage.position == Vector2(-1600, 0),
                "main-road 4800px camera still follows actor")
            player.position = Vector2(4590, 790)
            visual.set("goal", Vector2(4730, 790))
            visual.call("_process", 0.20)
            check(str(visual.get("active_zone_id")) == B_ID
                and player.position == Vector2(400, 790)
                and int(visual.get("transition_count")) == 1
                and stage.get_node_or_null("Region_" + A_ID) == null
                and stage.get_node_or_null("Region_" + B_ID) != null
                and stage.position == Vector2.ZERO,
                "walking into east portal unloads A and loads B at named spawn/camera")
            visual.set("transition_cooldown", 0.0)
            player.position = Vector2(255, 790)
            visual.set("goal", Vector2(90, 790))
            visual.call("_process", 0.20)
            check(str(visual.get("active_zone_id")) == A_ID
                and player.position == Vector2(4380, 790)
                and int(visual.get("transition_count")) == 2,
                "walking into west portal returns from B to A via reciprocal spawn")
            visual.set("transition_cooldown", 0.0)
            player.position = Vector2(4600, 790)
            visual.set("goal", Vector2(4730, 790))
            visual.call("_process", 0.15)
            visual.set("transition_cooldown", 0.0)
            check(str(visual.get("active_zone_id")) == B_ID,
                "re-enter east market using a real connection")
            player.position = Vector2(1305, 775)
            visual.set("goal", Vector2(1305, 670))
            visual.call("_process", 0.12)
            check(str(visual.get("active_zone_id")) == C_ID
                and player.position == Vector2(800, 3500)
                and stage.get_node_or_null("Region_" + B_ID) == null
                and stage.get_node_or_null("Region_" + C_ID) != null
                and stage.position == Vector2(0, -3000),
                "east market north doorway loads independent vertical map at Y entry")
            player.position = Vector2(800, 2150)
            visual.call("_update_camera_and_status")
            check(stage.position == Vector2(0, -1650),
                "actual live camera follows Y through vertical mid-map")
            player.position = Vector2(800, 200)
            visual.call("_update_camera_and_status")
            check(stage.position == Vector2.ZERO,
                "actual vertical camera clamps at north end")
            visual.set("transition_cooldown", 0.0)
            player.position = Vector2(800, 3740)
            visual.set("goal", Vector2(800, 3920))
            visual.call("_process", 0.18)
            check(str(visual.get("active_zone_id")) == B_ID
                and player.position == Vector2(1320, 835),
                "vertical south exit returns to the east market named entrance")
            check(visual.has_method("_return_to_menu"),
                "Esc can return from any map to Demo title")
        visual.queue_free()
        await process_frame
    var vertical_packed := load("res://scenes/pingjiang_vertical_qa.tscn") as PackedScene
    check(vertical_packed != null, "direct vertical menu destination is loadable")
    if vertical_packed != null:
        var vertical: Node2D = vertical_packed.instantiate()
        root.add_child(vertical)
        await process_frame
        check(str(vertical.get("active_zone_id")) == C_ID
            and vertical.get("stage").position == Vector2(0, -3000),
            "V menu entry begins at the south end of an actual 1600x4000 map")
        vertical.queue_free()
        await process_frame
    print("PINGJIANG_ZONES_PASS failures=%d" % failures)
    quit(1 if failures > 0 else 0)
