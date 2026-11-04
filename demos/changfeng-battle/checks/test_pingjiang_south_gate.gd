extends SceneTree
## PJ-01 release gate: native art, polygon/obstacle collision, vertical camera,
## explicit bidirectional north AND south zone transitions, no QA fallback.
const Scale = preload("res://scripts/combat_scale.gd")
const Bake = preload("res://scripts/map_bake.gd")
const ZoneConnection = preload("res://scripts/map_zone_connection.gd")
const Shift = preload("res://scripts/world_viewport_offset.gd")
const SOUTH_GATE := "res://data/maps/pingjiang_south_gate.tres"
const CROSSROADS := "res://data/maps/pingjiang_crossroads.tres"
const OUTER_ROAD := "res://data/maps/pingjiang_outer_road.tres"
var failures := 0

func check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("PINGJIANG_PJ01: " + reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var resources: Array[WuxiaMapDefinition] = []
    var bakes: Array = []
    for path in [SOUTH_GATE, CROSSROADS, OUTER_ROAD]:
        var map := load(path) as WuxiaMapDefinition
        check(map != null, "native map exists: " + path)
        if map == null:
            quit(1)
            return
        resources.append(map)
        check(not map.to_record().is_empty(), "valid native map schema: " + path)
        check(map.scene_art != null and map.scene_art.valid_for(map.viewport_size),
            "background/ground/optional foreground share exact world canvas: " + path)
        check(map.background == map.scene_art.background
            and map.pixels_per_unit == 80.0 and map.image_scale == 1.0
            and map.image_rotation_degrees == 0.0,
            "one untransformed 80px/unit art grid: " + path)
        var bake = Bake.new(path)
        check(bake.error.is_empty(), "native polygon bakes: " + path + " " + bake.error)
        if not bake.error.is_empty():
            quit(1)
            return
        bakes.append(bake)

    var gate = bakes[0]
    var crossing = bakes[1]
    var outside = bakes[2]
    var radius: float = Scale.footprint_radius_pixels()
    check(resources[0].viewport_size == Vector2i(1600, 2000)
        and resources[0].primary_axis == "vertical"
        and resources[1].viewport_size == Vector2i(1600, 1000)
        and resources[1].primary_axis == "mixed"
        and resources[2].viewport_size == Vector2i(1600, 1000),
        "native vertical PJ-01 and mixed crossroads maintain actual art dimensions")
    check(resources[0].scene_art.foreground != null
        and resources[1].scene_art.foreground != null
        and resources[0].obstacles.size() == 4,
        "gate arch/parapets use real foreground and native obstacle polygons")
    check(Scale.actor_height_pixels() == 200.0 and radius == 24.0,
        "actor physical body/footprint remains at established scale")
    for p in [Vector2(800, 105), Vector2(800, 320), Vector2(800, 800),
        Vector2(800, 1200), Vector2(800, 1700), Vector2(800, 1905)]:
        check(gate.is_walkable_point(p, radius), "gate main stone road walkable " + str(p))
    for p in [Vector2(350, 1300), Vector2(1240, 1250), Vector2(660, 875),
        Vector2(945, 1330), Vector2(645, 1330), Vector2(945, 875)]:
        check(not gate.is_walkable_point(p, radius),
            "water/wall/gate pier/bridge railing must be blocked " + str(p))
    check(gate.segment_blocked(Vector2(800, 1250), Vector2(945, 1250), radius)
        and not gate.segment_blocked(Vector2(800, 1700), Vector2(800, 500), radius),
        "free movement respects railing, but centreline remains continuous")
    check(crossing.is_walkable_point(Vector2(800, 730), radius)
        and crossing.is_walkable_point(Vector2(1500, 700), radius)
        and not crossing.is_walkable_point(Vector2(1500, 200), radius)
        and outside.is_walkable_point(Vector2(800, 275), radius)
        and not outside.is_walkable_point(Vector2(1200, 500), radius),
        "crossroads/outer-road authored walkable bounds match painted paths")
    check(Shift.world_offset(Vector2(800, 105), Vector2(1600, 2000)) == Vector2.ZERO
        and Shift.world_offset(Vector2(800, 1100), Vector2(1600, 2000)) == Vector2(0, -600)
        and Shift.world_offset(Vector2(800, 1905), Vector2(1600, 2000)) == Vector2(0, -1000),
        "PJ-01 2000px vertical camera follows Y, clamps 0..-1000")

    for route in [
        [gate, "to_north", crossing, "from_south", Vector2(800, 730)],
        [crossing, "to_south", gate, "from_north", Vector2(800, 320)],
        [gate, "to_south", outside, "from_north", Vector2(800, 275)],
        [outside, "to_north", gate, "from_south", Vector2(800, 1710)]]:
        var resolution: Dictionary = ZoneConnection.resolve_exit(route[0], route[1], route[2], radius)
        check(resolution.get("target_zone_id", "") == route[2].id
            and resolution.get("target_entry_id", "") == route[3]
            and resolution.get("spawn", Vector2.INF) == route[4],
            "explicit reciprocal connector and safe spawn " + str(route[1]))
    check(ZoneConnection.resolve_exit(gate, "to_north", outside, radius).is_empty()
        and ZoneConnection.resolve_exit(gate, "player_start", crossing, radius).is_empty(),
        "wrong destination and non-exit are never accepted")

    var manifest := load("res://data/content_manifest.tres") as WuxiaContentManifest
    check(manifest != null, "content manifest loads")
    if manifest != null:
        var registered: Dictionary = {}
        for resource in manifest.maps:
            registered[resource.content_id] = true
        check(registered.has("pingjiang_south_gate") and registered.has("pingjiang_crossroads")
            and registered.has("pingjiang_outer_road"), "formal maps are manifest-registered")

    var packed := load("res://scenes/pingjiang_south_gate.tscn") as PackedScene
    check(packed != null, "PJ-01 formal playable entry loads")
    if packed != null:
        var scene := packed.instantiate() as Node2D
        root.add_child(scene)
        await process_frame
        var player: Node2D = scene.get("player")
        var stage: Node2D = scene.get("stage")
        check(scene.get("production_map_mode") and scene.get("actor_sprite") != null,
            "formal entry uses actual actor atlas, never a placeholder silhouette")
        check(player != null and stage != null and scene.get("current_region_id") == gate.id,
            "initial map loads with an actor and a camera")
        if player != null and stage != null:
            check(stage.get_node_or_null(gate.id) != null
                and stage.get_node_or_null(crossing.id) == null
                and player.position == Vector2(800, 1700)
                and stage.position == Vector2(0, -1000),
                "PJ-01 starts at south bridge with no adjacent map mounted")
            var active_map: Node2D = stage.get_node(gate.id)
            check(active_map.get_node_or_null("Background") != null
                and active_map.get_node_or_null("Ground") != null
                and active_map.get_node_or_null("Foreground") != null,
                "actual three-layer art nodes are loaded")
            check(not scene.call("_activate_exit", "to_north"),
                "E cannot jump across the whole map")
            player.position = Vector2(800, 105)
            check(bool(scene.call("_activate_exit", "to_north")),
                "north E transition enters actual PJ-02 scene")
            check(scene.get("current_region_id") == crossing.id
                and player.position == Vector2(800, 730)
                and stage.get_node_or_null(gate.id) == null
                and stage.get_node_or_null(crossing.id) != null,
                "north transition releases PJ-01 and resets local coordinates")
            check(not scene.call("_activate_exit", "to_south"),
                "arrival spawn is outside the reverse connector radius")
            player.position = Vector2(800, 925)
            check(bool(scene.call("_activate_exit", "to_south")),
                "PJ-02 returns south to PJ-01")
            check(scene.get("current_region_id") == gate.id
                and player.position == Vector2(800, 320), "north-return uses safe inner spawn")
            player.position = Vector2(800, 1905)
            check(bool(scene.call("_activate_exit", "to_south")),
                "PJ-01 south E enters the actual outer-road scene")
            check(scene.get("current_region_id") == outside.id
                and player.position == Vector2(800, 275), "south entry uses its own map origin")
            player.position = Vector2(800, 95)
            check(bool(scene.call("_activate_exit", "to_north")),
                "outer road returns north to PJ-01")
            check(scene.get("current_region_id") == gate.id
                and player.position == Vector2(800, 1710)
                and int(scene.get("crossing_count")) == 4
                and stage.position == Vector2(0, -1000),
                "four crossings work and final vertical camera recovers")
        scene.queue_free()
        await process_frame
    print("PINGJIANG_PJ01_PASS failures=%d" % failures)
    quit(1 if failures else 0)
