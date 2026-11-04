extends SceneTree
const Bake = preload("res://scripts/map_bake.gd")
const Scale = preload("res://scripts/combat_scale.gd")
const MAP := "res://data/maps/pingjiang_riverside_market.tres"
const SCENE := "res://scenes/pingjiang_riverside_market_qa.tscn"
var failures := 0

func check(condition: bool, note: String) -> void:
    if not condition:
        failures += 1
        push_error("PJ03: " + note)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var native_map := load(MAP) as WuxiaMapDefinition
    check(native_map != null, "map Resource exists")
    if native_map == null:
        quit(1)
        return
    check(native_map.viewport_size == Vector2i(4800, 1000), "world canvas 4800x1000")
    check(native_map.pixels_per_unit == Scale.PIXELS_PER_UNIT, "world pixels per unit")
    check(native_map.scene_art != null and native_map.scene_art.valid_for(native_map.viewport_size),
        "three full-sized native art layers")
    var art := native_map.scene_art
    if art != null:
        check(art.background != art.ground and art.ground != art.foreground,
            "distinct textures rather than one flattened image")
        for texture in [art.background, art.ground, art.foreground]:
            check(texture != null and Vector2i(texture.get_size()) == Vector2i(4800, 1000),
                "all canvas sizes match")
    check(not native_map.to_record().is_empty(), "native map validates")
    var bake = Bake.new(MAP)
    check(bake.error.is_empty(), "map bakes: " + bake.error)
    if bake.error.is_empty():
        for x in [80.0, 800.0, 1599.0, 1601.0, 2400.0, 3199.0, 3201.0, 4720.0]:
            check(bake.is_walkable_point(Vector2(x, 715), 24.0),
                "continuous unbroken 24px-footprint corridor at x=" + str(x))
        check(not bake.is_walkable_point(Vector2(2100, 550), 24.0),
            "storefront is blocked")
        check(not bake.is_walkable_point(Vector2(2400, 980), 24.0),
            "outside southern walkway is blocked")
        for exit_id in ["east", "west", "south"]:
            check(str(bake.markers.get(exit_id, {}).get("kind", "")) == "zone_exit",
                "explicit exit metadata: " + exit_id)
    check(not bake.is_walkable_point(Vector2(1500, 890), 24.0), "foreground building footprint blocked")
    check(bake.is_walkable_point(Vector2(2400, 865), 24.0), "southern alley accessible")
    var scene := load(SCENE) as PackedScene
    check(scene != null, "QA scene loads")
    if scene != null:
        var instance := scene.instantiate()
        root.add_child(instance)
        await process_frame
        check(str(instance.get("current_region_id")) == "pingjiang_riverside_market",
            "PJ-03 loads its own map, not generic scroll QA")
        var stage := instance.get("stage") as Node2D
        check(stage != null and stage.get_node_or_null("pingjiang_riverside_market") != null,
            "scene renders the current region")
        instance.queue_free()
    print("PJ-03 layered map checks: ", "PASS" if failures == 0 else str(failures) + " failures")
    quit(0 if failures == 0 else 1)
