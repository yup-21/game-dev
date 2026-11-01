extends SceneTree
## P1 offline import contract. No file is copied or modified by this test.
const Importer = preload("res://addons/wuxia_art_importer/art_import_service.gd")

func _initialize() -> void:
    var root: String = Importer.production_root()
    if not root.ends_with("/art-production"):
        _fail("Production root escaped repository layout")
        return
    if Importer.inspect(ProjectSettings.globalize_path("res://project.godot")).get("error", "") == "":
        _fail("Non-production source was accepted")
        return
    var sources: Array[String] = Importer.collect_sources()
    if sources.size() < 39:
        _fail("P0 in-use artwork is absent")
        return
    var source := root.path_join("in-use/fallback/default_actor_6x4.svg")
    var image: Dictionary = Importer.inspect(source)
    if not str(image.get("error", "")).is_empty() or int(image["width"]) <= 0:
        _fail("SVG preview failed: " + str(image.get("error", "")))
        return
    if not Importer.destination(source).begins_with("res://assets/imported/in-use/"):
        _fail("Source destination has incorrect root")
        return
    var bad := Importer.plan("portrait", source, "res://data/maps/rainy_bridge.tres", {})
    if str(bad.get("error", "")).is_empty():
        _fail("Portrait import accepted map Resource")
        return
    bad = Importer.plan("scene", source, "res://data/maps/rainy_bridge.tres", {})
    if str(bad.get("error", "")).is_empty():
        _fail("Missing scene ground was accepted")
        return
    bad = Importer.plan("ui_atlas", source, "", {"asset_id": "../../bad"})
    if str(bad.get("error", "")).is_empty():
        _fail("Invalid asset ID was accepted")
        return
    print("ART_IMPORTER_CONTRACT_OK")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
