extends SceneTree
## Initial migration from existing Resources. Intentionally refuses to overwrite
## a native .tscn after artists have begun adjusting it in the Godot 2D editor.
const CONFIG := [
    ["pingjiang_south_gate_qa", "pj01_south_gate"],
    ["pingjiang_crossroads", "pj02_crossroads"],
    ["pingjiang_riverside_market", "pj03_riverside_market"],
    ["pingjiang_shen_house", "pj04_shen_house"],
]
const TARGET_DIR := "res://scenes/pingjiang_regions"

func _initialize() -> void:
    call_deferred("_generate")

func _owned(parent: Node, node: Node, scene_root: Node) -> void:
    parent.add_child(node)
    node.owner = scene_root

func _generate() -> void:
    var failed := false
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TARGET_DIR))
    for spec in CONFIG:
        var path: String = TARGET_DIR.path_join(str(spec[1]) + ".tscn")
        if ResourceLoader.exists(path) or FileAccess.file_exists(path):
            push_error("Refusing to overwrite an editable native scene: " + path)
            failed = true
            continue
        var source := load("res://data/maps/%s.tres" % spec[0]) as WuxiaMapDefinition
        if source == null or source.scene_art == null or source.to_record().is_empty():
            push_error("Invalid source map: " + str(spec[0]))
            failed = true
            continue
        var root := WuxiaNativeMapRegion.new()
        root.name = str(spec[0])
        root.source_map = source
        var art := source.scene_art
        for desc in [["Background", art.background, -100],
                ["Ground", art.ground, -90], ["Foreground", art.foreground, 110]]:
            if desc[1] == null:
                continue
            var sprite := Sprite2D.new()
            sprite.name = str(desc[0])
            sprite.texture = desc[1]
            sprite.centered = false
            sprite.z_index = int(desc[2])
            _owned(root, sprite, root)
        var walkable := Area2D.new()
        walkable.name = "WalkableArea"
        walkable.collision_layer = 0
        walkable.collision_mask = 0
        walkable.monitoring = false
        walkable.monitorable = false
        _owned(root, walkable, root)
        var outline := CollisionPolygon2D.new()
        outline.name = "Boundary"
        outline.polygon = source.walkable_outline
        outline.disabled = true
        _owned(walkable, outline, root)
        var blockers := Node2D.new()
        blockers.name = "Obstacles"
        _owned(root, blockers, root)
        for i in range(source.obstacles.size()):
            var obstacle := source.obstacles[i] as WuxiaMapPolygonDefinition
            var body := WuxiaNativeMapObstacle.new()
            body.name = "Obstacle_%02d" % (i + 1)
            body.terrain_kind = obstacle.terrain_kind
            _owned(blockers, body, root)
            var polygon := CollisionPolygon2D.new()
            polygon.name = "CollisionPolygon2D"
            polygon.polygon = obstacle.vertices
            _owned(body, polygon, root)
        var anchors := Node2D.new()
        anchors.name = "Markers"
        _owned(root, anchors, root)
        var exits := Node2D.new()
        exits.name = "Exits"
        _owned(root, exits, root)
        for entry in source.markers:
            var marker := entry as WuxiaMapMarkerDefinition
            if marker.marker_kind == "zone_exit":
                var area := WuxiaNativeMapExit.new()
                area.name = marker.marker_id
                area.position = marker.position
                area.exit_side = marker.exit_side
                area.target_zone_id = marker.target_zone_id
                area.target_entry_id = marker.target_entry_id
                area.collision_layer = 0
                area.collision_mask = 0
                area.monitoring = false
                area.monitorable = false
                _owned(exits, area, root)
                var radius := CollisionShape2D.new()
                radius.name = "Radius"
                var circle := CircleShape2D.new()
                circle.radius = marker.radius
                radius.shape = circle
                _owned(area, radius, root)
            else:
                var node := WuxiaNativeMapMarker.new()
                node.name = marker.marker_id
                node.position = marker.position
                node.marker_kind = marker.marker_kind
                node.radius = marker.radius
                _owned(anchors, node, root)
        var snapshot := root.build_definition()
        if snapshot == null or snapshot.to_record() != source.to_record():
            push_error("Native geometry differs from existing Resource: " + str(spec[0]))
            failed = true
            root.free()
            continue
        var scene := PackedScene.new()
        if scene.pack(root) != OK or ResourceSaver.save(scene, path) != OK:
            push_error("Unable to write native scene: " + path)
            failed = true
        else:
            print("Native scene created: " + path)
        root.free()
    quit(1 if failed else 0)
