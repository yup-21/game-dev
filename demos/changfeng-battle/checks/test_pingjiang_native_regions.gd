extends SceneTree
## Native editor scenes are faithful to their original Resources, and gameplay
## reads changed node geometry without waiting for a Resource export.
const Bake = preload("res://scripts/map_bake.gd")
const CASES := [
    ["pj01_south_gate", "pingjiang_south_gate_qa", Vector2i(1600, 2000)],
    ["pj02_crossroads", "pingjiang_crossroads", Vector2i(1600, 1000)],
    ["pj03_riverside_market", "pingjiang_riverside_market", Vector2i(4800, 1000)],
    ["pj04_shen_house", "pingjiang_shen_house", Vector2i(1600, 1000)],
]
var failures := 0

func check(value: bool, label: String) -> void:
    if not value:
        failures += 1
        push_error("PINGJIANG_NATIVE: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for spec in CASES:
        var path := "res://scenes/pingjiang_regions/%s.tscn" % spec[0]
        var packed := load(path) as PackedScene
        check(packed != null, "editable scene exists: " + path)
        if packed == null:
            continue
        var scene := packed.instantiate() as WuxiaNativeMapRegion
        var original := load("res://data/maps/%s.tres" % spec[1]) as WuxiaMapDefinition
        check(scene != null and original != null, "native scene and Resource load: " + str(spec[1]))
        if scene == null or original == null:
            continue
        var snapshot := scene.build_definition()
        check(snapshot != null and snapshot.to_record() == original.to_record(),
            "native scene and .tres geometry/markers agree: " + str(spec[1]))
        for layer in ["Background", "Ground", "Foreground"]:
            var sprite := scene.get_node_or_null(layer) as Sprite2D
            check(sprite != null and sprite.texture != null and not sprite.centered
                and Vector2i(sprite.texture.get_size()) == spec[2],
                "editable full-size, same-origin " + layer + " in " + str(spec[1]))
        check(scene.get_node_or_null("WalkableArea/Boundary") is CollisionPolygon2D,
            "editable native walkable polygon in " + str(spec[1]))
        for exit_node in scene.get_node("Exits").get_children():
            check(exit_node is Area2D and exit_node.get_node_or_null("Radius") is CollisionShape2D,
                "editable Area2D exit " + str(exit_node.name))
        var baked = Bake.new("res://data/maps/%s.tres" % spec[1], snapshot)
        check(baked.error.is_empty(), "native geometry bakes: " + str(spec[1]))
        scene.free()

    var crossroads := load("res://scenes/pingjiang_regions/pj02_crossroads.tscn").instantiate() as WuxiaNativeMapRegion
    var moved := crossroads.get_node("Markers/from_south") as Marker2D
    var old_pos := moved.position
    moved.position += Vector2(12, 0)
    var changed = Bake.new("res://data/maps/pingjiang_crossroads.tres", crossroads.build_definition())
    check(changed.error.is_empty() and changed.marker_position("from_south") == old_pos + Vector2(12, 0),
        "moving Marker2D updates runtime spawn independently of the old .tres")
    moved.position = old_pos
    var boundary := crossroads.get_node("WalkableArea/Boundary") as CollisionPolygon2D
    boundary.position = Vector2(5, 0)
    var shifted := crossroads.build_definition()
    check(shifted != null and shifted.walkable_outline[0] == Vector2(685, 180),
        "native CollisionPolygon2D transform updates runtime outline")
    crossroads.free()

    # F6 on an individual map must launch that region with a player, not a
    # static image-only preview or the PJ-01 default entry.
    var standalone: WuxiaNativeMapRegion = (load("res://scenes/pingjiang_regions/pj02_crossroads.tscn") as PackedScene).instantiate() as WuxiaNativeMapRegion
    root.add_child(standalone)
    current_scene = standalone
    await process_frame
    await process_frame
    check(current_scene != standalone and current_scene != null
        and str(current_scene.get("current_region_id")) == "pingjiang_crossroads",
        "F6 on PJ-02 enters playable exploration in PJ-02")
    if current_scene != null:
        current_scene.queue_free()
        current_scene = null
    await process_frame
    print("PINGJIANG_NATIVE_PASS failures=%d" % failures)
    quit(1 if failures else 0)
