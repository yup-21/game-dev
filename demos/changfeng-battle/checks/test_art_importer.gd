extends SceneTree
## P1 offline import contract. No file is copied or modified by this test.
const Importer = preload("res://addons/wuxia_art_importer/art_import_service.gd")
const Dock = preload("res://addons/wuxia_art_importer/art_import_dock.gd")

func _initialize() -> void:
    var production_dir: String = Importer.production_root()
    if not production_dir.ends_with("/art-production"):
        _fail("Production root escaped repository layout")
        return
    if Importer.inspect(ProjectSettings.globalize_path("res://project.godot")).get("error", "") == "":
        _fail("Non-production source was accepted")
        return
    var sources: Array[String] = Importer.collect_sources()
    if sources.size() < 39:
        _fail("P0 in-use artwork is absent")
        return
    var source: String = production_dir.path_join("in-use/fallback/default_actor_6x4.svg")
    var image: Dictionary = Importer.inspect(source)
    if not str(image.get("error", "")).is_empty() or int(image["width"]) <= 0:
        _fail("SVG preview failed: " + str(image.get("error", "")))
        return
    if not Importer.destination(source).begins_with("res://assets/imported/in-use/"):
        _fail("Source destination has incorrect root")
        return
    var atlas: Dictionary = Importer.plan("atlas", source, "res://data/native/characters/shen_changfeng.tres",
        {"columns": 6, "rows": 4, "feet_offset": Vector2(0, -102), "faces_left": false})
    if not str(atlas.get("error", "")).is_empty():
        _fail("Valid atlas plan rejected: " + str(atlas.get("error", "")))
        return
    # The first pilot has a different nine-action frame order from the fallback.
    # Preflight must honor an explicit native clip profile without writing runtime data.
    var pilot_source: String = production_dir.path_join(
        "candidates/2026-11-01/shen_changfeng/sprite_shen_changfeng_atlas_normalized_v02.png")
    var pilot_clip: String = "res://data/art_previews/shen_changfeng_pilot_clip_profile.tres"
    var pilot: Dictionary = Importer.plan("atlas", pilot_source,
        "res://data/native/characters/shen_changfeng.tres",
        {"columns": 6, "rows": 4, "feet_offset": Vector2(0, -102),
         "faces_left": false, "clip_profile_path": pilot_clip})
    if not str(pilot.get("error", "")).is_empty() or str(pilot.get("clip_profile_path", "")) != pilot_clip:
        _fail("Pilot custom clip profile was not honored: " + str(pilot.get("error", "")))
        return
    var invalid_clip: Dictionary = Importer.plan("atlas", pilot_source,
        "res://data/native/characters/shen_changfeng.tres",
        {"columns": 6, "rows": 4, "clip_profile_path": "res://data/art_previews/missing.tres"})
    if str(invalid_clip.get("error", "")).is_empty():
        _fail("Missing custom clip profile was accepted")
        return
    var ui_source: String = production_dir.path_join("in-use/ui/original/card_probe.svg")
    var ui: Dictionary = Importer.plan("ui_atlas", ui_source, "", {"asset_id": "art.ui_test"})
    if not str(ui.get("error", "")).is_empty():
        _fail("Valid UI registration plan rejected: " + str(ui.get("error", "")))
        return
    var dock := Dock.new()
    root.add_child(dock)
    await process_frame
    if dock.source_list == null or dock.kind == null:
        _fail("Editor dock did not initialize")
        return
    if dock.source_list.item_count < 39 or dock.kind.item_count != 5:
        _fail("Editor dock failed to enumerate candidate sources")
        return
    dock.queue_free()
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
