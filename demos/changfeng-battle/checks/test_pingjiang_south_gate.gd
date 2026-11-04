extends SceneTree
## PJ-01 geometry, layer alignment, Y-only camera and reciprocal connector QA.
const Scale = preload("res://scripts/combat_scale.gd")
const Bake = preload("res://scripts/map_bake.gd")
const ZoneConnection = preload("res://scripts/map_zone_connection.gd")
const Shift = preload("res://scripts/world_viewport_offset.gd")
const P1 = "res://data/maps/pingjiang_south_gate_qa.tres"
const NORTH = "res://data/maps/pingjiang_crossroads_connector_qa.tres"
const SOUTH = "res://data/maps/pingjiang_wild_road_connector_qa.tres"
var failures := 0

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("PJ01_LAYERED: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var map := load(P1) as WuxiaMapDefinition
    var north := load(NORTH) as WuxiaMapDefinition
    var south := load(SOUTH) as WuxiaMapDefinition
    check(map != null and north != null and south != null, "all independent native maps load")
    if map == null or north == null or south == null:
        quit(1)
        return
    check(map.viewport_size == Vector2i(1600, 2000) and map.primary_axis == "vertical"
        and map.image_scale == 1.0 and map.image_rotation_degrees == 0.0,
        "PJ-01 is a real 1600x2000 orthographic Y-world")
    check(not map.to_record().is_empty() and not north.to_record().is_empty()
        and not south.to_record().is_empty(), "all map records are valid")
    var art: WuxiaSceneArtProfile = map.scene_art
    check(art != null and art.valid_for(map.viewport_size), "three exact origin-matched layers")
    if art != null:
        check(art.background != null and art.ground != null and art.foreground != null,
            "all authored layer slots are bound")
        if art.ground != null and art.foreground != null:
            check(art.ground.get_image().get_pixel(800, 1500).a > 0.99
                and art.ground.get_image().get_pixel(200, 1500).a < 0.01
                and art.foreground.get_image().get_pixel(800, 1200).a < 0.01
                and art.foreground.get_image().get_pixel(800, 740).a > 0.99,
                "road alpha and independently raised gate overlap are real")
    var b = Bake.new(P1)
    var n = Bake.new(NORTH)
    var s = Bake.new(SOUTH)
    check(b.error.is_empty() and n.error.is_empty() and s.error.is_empty(),
        "polygon bake and neighbor map resources load")
    if not b.error.is_empty() or not n.error.is_empty() or not s.error.is_empty():
        quit(1)
        return
    var radius := Scale.footprint_radius_pixels()
    check(radius == 24.0 and Scale.actor_height_pixels() == 200.0
        and b.pixels_per_unit == 80.0, "fixed actor/world scale")
    check(b.walkable_outline.size() == 4 and b.polygons.size() == 2,
        "explicit 360px passage and separate moat blockers")
    for y in [80.0, 450.0, 850.0, 1200.0, 1600.0, 1920.0]:
        check(b.is_walkable_point(Vector2(800, y), radius)
            and b.is_walkable_point(Vector2(665, y), radius)
            and not b.is_walkable_point(Vector2(610, y), radius)
            and not b.is_walkable_point(Vector2(990, y), radius),
            "full 360px passage / excluded buildings and water at Y=%d" % int(y))
    check(not b.is_walkable_point(Vector2(300, 1220), radius)
        and not b.is_walkable_point(Vector2(1300, 1300), radius),
        "moat and river dock are impassable")
    var pairs: Array = [
        [b, "north", n, "from_south", Vector2(800, 750)],
        [n, "to_south", b, "from_north", Vector2(800, 250)],
        [b, "south", s, "from_north", Vector2(800, 250)],
        [s, "to_north", b, "from_south", Vector2(800, 1750)]]
    for pair in pairs:
        var route: Dictionary = ZoneConnection.resolve_exit(pair[0], pair[1], pair[2], radius)
        check(route.get("target_entry_id", "") == pair[3]
            and route.get("spawn", Vector2.INF) == pair[4],
            "explicit reciprocal route: " + str(pair[1]))
    check(ZoneConnection.resolve_exit(b, "north", s, radius).is_empty(),
        "mismatched adjacent zone cannot silently fall back")
    check(Shift.world_offset(Vector2(800, 250), Vector2(1600, 2000)) == Vector2.ZERO
        and Shift.world_offset(Vector2(800, 1000), Vector2(1600, 2000)) == Vector2(0, -500)
        and Shift.world_offset(Vector2(800, 1750), Vector2(1600, 2000)) == Vector2(0, -1000),
        "1600x1000 viewport clamps only vertical camera")

    var scene := load("res://scenes/pingjiang_south_gate_qa.tscn") as PackedScene
    check(scene != null, "G menu QA scene resource loads")
    if scene != null:
        var visual: Node2D = scene.instantiate()
        root.add_child(visual)
        await process_frame
        var player: Node2D = visual.get("player")
        var stage: Node2D = visual.get("stage")
        check(player != null and stage != null and visual.get("actor_sprite") != null,
            "real 200px protagonist and scene mount")
        if player != null and stage != null:
            check(str(visual.get("current_region_id")) == b.id
                and player.position == Vector2(800, 1750)
                and stage.position == Vector2(0, -1000), "starts near south bridge")
            player.position = Vector2(800, 1000)
            visual.call("_update_camera_and_status")
            check(stage.position == Vector2(0, -500), "midpoint scroll does not zoom")
            check(not bool(visual.call("_activate_exit", "north")), "distant north exit rejects E")
            player.position = Vector2(800, 80)
            check(bool(visual.call("_activate_exit", "north"))
                and str(visual.get("current_region_id")) == n.id
                and player.position == Vector2(800, 750), "north transfers to PJ02 QA connector")
            player.position = Vector2(800, 920)
            check(bool(visual.call("_activate_exit", "to_south"))
                and str(visual.get("current_region_id")) == b.id
                and player.position == Vector2(800, 250), "north reciprocal return")
            player.position = Vector2(800, 1920)
            check(bool(visual.call("_activate_exit", "south"))
                and str(visual.get("current_region_id")) == s.id
                and player.position == Vector2(800, 250), "south transfers to road QA connector")
            player.position = Vector2(800, 80)
            check(bool(visual.call("_activate_exit", "to_north"))
                and str(visual.get("current_region_id")) == b.id
                and player.position == Vector2(800, 1750)
                and int(visual.get("crossing_count")) == 4,
                "south reciprocal return with old zone unloaded")
        visual.queue_free()
        await process_frame
    var menu := FileAccess.get_file_as_string("res://scripts/opening_flow.gd")
    check(menu.contains("KEY_G") and menu.contains("pingjiang_south_gate_qa"),
        "G keyboard and menu button entry are exposed")
    print("PJ01_LAYERED_PASS failures=%d" % failures)
    quit(1 if failures else 0)
