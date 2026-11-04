extends SceneTree
## PJ-04 art, native collisions, point markers and real PJ-03 roundtrip.
const Bake = preload("res://scripts/map_bake.gd")
const Scale = preload("res://scripts/combat_scale.gd")
const ZoneConnection = preload("res://scripts/map_zone_connection.gd")
const HOUSE := "res://data/maps/pingjiang_shen_house.tres"
const MARKET := "res://data/maps/pingjiang_riverside_market.tres"
const SCENE := "res://scenes/pingjiang_shen_house_qa.tscn"
var failures := 0

func check(condition: bool, note: String) -> void:
    if not condition:
        failures += 1
        push_error("PJ04: " + note)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var map := load(HOUSE) as WuxiaMapDefinition
    var neighbor := load(MARKET) as WuxiaMapDefinition
    check(map != null and neighbor != null, "PJ-04 and PJ-03 native maps load")
    if map == null or neighbor == null:
        quit(1)
        return
    check(map.content_id == "pingjiang_shen_house" and map.viewport_size == Vector2i(1600, 1000)
        and map.primary_axis == "horizontal" and map.pixels_per_unit == Scale.PIXELS_PER_UNIT,
        "single-screen native map is scaled 1:1")
    check(map.background != null and map.scene_art != null
        and map.scene_art.valid_for(map.viewport_size), "layered art resource loads")
    if map.scene_art != null:
        var art := map.scene_art
        check(art.background != art.ground and art.ground != art.foreground,
            "three independently imported textures")
        for texture in [art.background, art.ground, art.foreground]:
            check(texture != null and Vector2i(texture.get_size()) == Vector2i(1600, 1000),
                "all layers use the same 1600x1000 origin")
        if art.ground != null and art.foreground != null:
            check(art.ground.get_image().get_pixel(400, 200).a < 0.01
                and art.ground.get_image().get_pixel(800, 700).a > 0.99,
                "ground is transparent over buildings, opaque on the courtyard")
            check(art.foreground.get_image().get_pixel(800, 700).a < 0.01
                and art.foreground.get_image().get_pixel(1500, 900).a > 0.99,
                "foreground masks camera-near bushes and rocks only")
    check(not map.to_record().is_empty(), "native resource contract validates")
    var house = Bake.new(HOUSE)
    var market = Bake.new(MARKET)
    check(house.error.is_empty() and market.error.is_empty(),
        "native polygon bake: house=%s; market=%s" % [house.error, market.error])
    if not house.error.is_empty() or not market.error.is_empty():
        quit(1)
        return
    var radius := Scale.footprint_radius_pixels()
    check(radius == 24.0 and Scale.actor_height_pixels() == 200.0,
        "runtime actor ruler and footprint remain unchanged")
    for position in [Vector2(845, 338), Vector2(845, 450), Vector2(850, 565),
            Vector2(800, 740), Vector2(450, 760), Vector2(1200, 770),
            Vector2(335, 583), Vector2(578, 582), Vector2(1138, 595)]:
        check(house.is_walkable_point(position, radius), "walkable 24px feet at %s" % position)
    for position in [Vector2(300, 390), Vector2(1100, 320), Vector2(420, 517),
            Vector2(1060, 520), Vector2(1168, 527), Vector2(1490, 573),
            Vector2(30, 290), Vector2(800, 985)]:
        check(not house.is_walkable_point(position, radius),
            "building, steps, posts, well or outside is blocked: %s" % position)
    check(not house.segment_blocked(Vector2(845, 350), Vector2(845, 815), radius),
        "north stone approach joins the courtyard without a wall barrier")
    check(house.segment_blocked(Vector2(480, 720), Vector2(420, 510), radius),
        "porch steps remain a solid obstacle")
    for marker_id in ["north", "from_north", "house_door", "sword_case",
            "practice_posts", "hidden_compartment", "save_point", "well"]:
        check(house.markers.has(marker_id), "authored marker: " + marker_id)
    var outgoing: Dictionary = ZoneConnection.resolve_exit(house, "north", market, radius)
    var returning: Dictionary = ZoneConnection.resolve_exit(market, "south", house, radius)
    check(outgoing.get("target_zone_id", "") == "pingjiang_riverside_market"
        and outgoing.get("target_entry_id", "") == "from_south"
        and outgoing.get("spawn", Vector2.INF) == Vector2(2400, 810),
        "PJ-04 north resolves to PJ-03 south spawn")
    check(returning.get("target_zone_id", "") == "pingjiang_shen_house"
        and returning.get("target_entry_id", "") == "from_north"
        and returning.get("spawn", Vector2.INF) == Vector2(850, 565),
        "PJ-03 south resolves to PJ-04 safe north spawn")
    check(not house.is_walkable_point(Vector2(845, 240), radius)
        and house.markers["north"].get("target_entry_id", "") != "north",
        "no passage through back wall or self-targeting exit")

    var packed := load(SCENE) as PackedScene
    check(packed != null, "independent PJ-04 QA scene loads")
    if packed != null:
        var visual := packed.instantiate() as Node2D
        root.add_child(visual)
        await process_frame
        var stage := visual.get("stage") as Node2D
        var player := visual.get("player") as Node2D
        check(stage != null and player != null and visual.get("actor_sprite") != null,
            "layered world and original actor atlas instantiate")
        if stage != null and player != null:
            check(str(visual.get("current_region_id")) == "pingjiang_shen_house"
                and stage.get_node_or_null("pingjiang_shen_house") != null,
                "QA starts with only PJ-04 mounted")
            check(not bool(visual.call("_activate_exit", "north")),
                "remote north door cannot activate")
            player.position = Vector2(845, 338)
            check(bool(visual.call("_activate_exit", "north")),
                "press E at north gateway loads the real PJ-03 map")
            check(str(visual.get("current_region_id")) == "pingjiang_riverside_market"
                and player.position == Vector2(2400, 810)
                and stage.get_node_or_null("pingjiang_shen_house") == null,
                "PJ-03 scene mounted alone with safe entry")
            check(not bool(visual.call("_activate_exit", "south")),
                "arrival does not immediately bounce back")
            player.position = Vector2(2400, 895)
            check(bool(visual.call("_activate_exit", "south")),
                "PJ-03 south exit returns to PJ-04")
            check(str(visual.get("current_region_id")) == "pingjiang_shen_house"
                and player.position == Vector2(850, 565)
                and int(visual.get("crossing_count")) == 2
                and stage.get_node_or_null("pingjiang_riverside_market") == null,
                "bidirectional crossing leaves one map active")
        visual.queue_free()
        await process_frame
    print("PJ-04 SHEN HOUSE PASS failures=%d" % failures)
    quit(1 if failures else 0)
