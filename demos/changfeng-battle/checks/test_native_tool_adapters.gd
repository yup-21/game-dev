extends SceneTree
## Native editor-tool contracts without modifying the user's .tscn/.tres files.
const SceneBinding = preload("res://addons/wuxia_art_importer/native_scene_binding.gd")
const ImportTransaction = preload("res://addons/wuxia_art_importer/art_transaction_service.gd")
const Export = preload("res://addons/wuxia_art_importer/art_export_service.gd")
const MapDock = preload("res://addons/wuxia_map_editor/map_painter_dock.gd")
const MapRoot = preload("res://checks/fixtures/native_tool_map_fixture.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _check(value: bool, message: String) -> void:
    if not value:
        failures.append(message)


func _run() -> void:
    var source := load("res://data/maps/rainy_bridge.tres") as WuxiaMapDefinition
    _check(source != null, "Native scene fixture needs a real WuxiaMapDefinition")
    if source == null:
        quit(1)
        return
    var root: Node2D = MapRoot.new()
    root.name = "NativeRegion"
    root.set("source_map", source)
    var ground := Sprite2D.new()
    ground.name = "Ground"
    ground.position = Vector2(19, 37)
    root.add_child(ground)
    var background := Sprite2D.new()
    background.name = "Background"
    background.position = Vector2(91, 143)
    root.add_child(background)
    var collider := CollisionPolygon2D.new()
    collider.name = "ManualGeometry"
    collider.polygon = PackedVector2Array([Vector2(0, 0), Vector2(24, 0), Vector2(0, 24)])
    root.add_child(collider)
    var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.1, 0.3, 0.5, 1))
    var texture := ImageTexture.create_from_image(image)
    var original_shape := collider.polygon.duplicate()
    _check(MapDock.is_native_map(root), "Map dock must recognize an editable native scene root")
    _check(SceneBinding.bind_layers(root, source, {
        "background": texture, "ground": texture}).is_empty(),
        "Explicit native Sprite2D layers must bind without rebuilding the scene")
    _check(background.texture == texture and ground.texture == texture,
        "Map textures must reach the native Sprite2D nodes")
    _check(background.position == Vector2(91, 143) and ground.position == Vector2(19, 37) and
        collider.polygon == original_shape,
        "Native scene binding must preserve manual offsets and collisions")
    _check(not SceneBinding.bind_layers(root, source, {"weather": texture}).is_empty(),
        "Importer must require an explicitly authored optional Sprite2D node")
    var wrong := load("res://data/maps/pingjiang_long_street_qa.tres") as WuxiaMapDefinition
    _check(not SceneBinding.bind_layers(root, wrong, {"ground": texture}).is_empty(),
        "Importer must reject a scene bound to a different map")
    var existing_scene := "res://scenes/actors/story_role.tscn"
    var journal_plan: Dictionary = {"error": "", "mode": "scene", "target": source.resource_path,
        "files": {}, "native_scene_path": existing_scene,
        "native_scene_sha256": FileAccess.get_sha256(existing_scene)}
    _check(ImportTransaction.validate([journal_plan]).is_empty() and
        ImportTransaction._resource_paths([journal_plan]).has(existing_scene),
        "Opt-in .tscn must join the same backup journal as .tres")
    journal_plan["native_scene_sha256"] = "obsolete"
    _check(not ImportTransaction.validate([journal_plan]).is_empty(),
        "Transaction must reject a scene modified since preflight")
    _check(Export.native_map_scenes(source.resource_path) is Array,
        "Exporter must inspect reverse native scene dependencies")
    self.root.add_child(root)
    var dock: Control = MapDock.new()
    root.add_child(dock)
    dock.call("edit_map", root)
    _check(dock.get("native_region") == root and dock.get("map_resource") == source,
        "Native map dock must switch to scene-readonly mode")
    dock.call("_start_walkable")
    _check(not bool(dock.get("canvas").get("active")),
        "Legacy polygon painter must not mutate native scene geometry")
    dock.call("_save")
    _check(".tscn" in str(dock.get("status").text),
        "Saving a native map must direct authors to the Godot scene editor")
    root.free()
    for failure in failures:
        push_error("NATIVE_TOOL_ADAPTER: " + failure)
    print("NATIVE_TOOL_ADAPTER_%s failures=%d" % [
        "PASS" if failures.is_empty() else "FAIL", failures.size()])
    quit(1 if not failures.is_empty() else 0)
