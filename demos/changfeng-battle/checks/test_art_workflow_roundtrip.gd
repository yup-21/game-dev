extends SceneTree
## CI-only write/rollback smoke test. Run on a disposable checkout, never on live artwork.
const Export = preload("res://addons/wuxia_art_importer/art_export_service.gd")
const Transaction = preload("res://addons/wuxia_art_importer/art_transaction_service.gd")
const Factory = preload("res://scripts/character_factory.gd")
const Importer = preload("res://addons/wuxia_art_importer/art_import_service.gd")

func _initialize() -> void:
    var character_path := "res://data/native/characters/shen_changfeng.tres"
    var original_hash: String = FileAccess.get_sha256(character_path)
    var planned: Dictionary = Export.plan("resource", character_path)
    if not str(planned.get("error", "")).is_empty():
        _fail("Export plan failed: " + str(planned["error"]))
        return
    var new_metadata: Array[String] = []
    for item in planned["entries"]:
        if bool(item["resource_metadata"]) and str(item["action"]) == "create":
            new_metadata.append(str(item["destination"]))
    if new_metadata.is_empty():
        _fail("No new .tres metadata to exercise export rollback")
        return
    var result: Dictionary = Export.export(planned)
    if not str(result.get("error", "")).is_empty():
        _fail("Export failed: " + str(result["error"]))
        return
    var journal: String = str(result["journal"])
    for path in new_metadata:
        if not FileAccess.file_exists(path):
            _fail("Export did not create Resource metadata: " + path)
            return
    var restored: String = Export.rollback(journal)
    if not restored.is_empty():
        _fail("Export rollback failed: " + restored)
        return
    for path in new_metadata:
        if FileAccess.file_exists(path):
            _fail("Export rollback left a created Resource metadata file: " + path)
            return
    if Export.rollback(journal).is_empty():
        _fail("Export rollback was incorrectly allowed twice")
        return

    # Existing content file is backed up and restored without changing its bytes.
    var dummy: Dictionary = {"error": "", "target": character_path,
        "mode": "portrait", "files": {}}
    var plans: Array[Dictionary] = [dummy]
    var started: Dictionary = Transaction.begin(plans)
    if not str(started.get("error", "")).is_empty():
        _fail("Import transaction begin failed: " + str(started["error"]))
        return
    var import_log: String = str(started["journal"])
    var saved: String = Transaction.commit(import_log)
    if not saved.is_empty():
        _fail("Import transaction commit failed: " + saved)
        return
    restored = Transaction.rollback(import_log)
    if not restored.is_empty():
        _fail("Import transaction rollback failed: " + restored)
        return
    if FileAccess.get_sha256(character_path) != original_hash:
        _fail("Import transaction rollback changed original Resource bytes")
        return
    if Transaction.rollback(import_log).is_empty():
        _fail("Import transaction rollback was incorrectly allowed twice")
        return
    # Exercise the actual five-item pilot import on a disposable CI checkout:
    # two portraits, two native action atlases, one layered scene + story preview.
    var before_paths := [
        "res://data/native/characters/shen_changfeng.tres",
        "res://data/native/characters/pursuer_captain.tres",
        "res://data/native/animations/shen_changfeng.tres",
        "res://data/native/animations/pursuer_captain.tres",
        "res://data/maps/rainy_bridge.tres",
        "res://data/native/scene_art/rainy_bridge.tres",
    ]
    var before_hashes: Dictionary = {}
    for path in before_paths:
        before_hashes[path] = FileAccess.get_sha256(path)
    # Retain a live factory with intentionally stale display data across import.
    var live_factory = Factory.new()
    live_factory.registry.profiles["shen_changfeng"]["art"]["portrait"] = \
        "res://assets/imported/characters/escort_elder/portraits/portrait_escort_elder_fullbody_v01.png"
    var batch: Array[Dictionary] = []
    var production: String = Importer.production_root().path_join("candidates")
    for actor_id in ["shen_changfeng", "pursuer_captain"]:
        var folder: String = production.path_join("characters/" + actor_id + "/baseline")
        var target: String = "res://data/native/characters/%s.tres" % actor_id
        batch.append(Importer.plan("portrait",
            folder.path_join("portrait_%s_fullbody_v01.png" % actor_id), target, {}))
        batch.append(Importer.plan("atlas",
            folder.path_join("sprite_%s_atlas_normalized_v02.png" % actor_id), target, {
                "columns": 6, "rows": 4, "feet_offset": Vector2(0, -102),
                "clip_profile_path": "res://data/art_previews/%s_pilot_clip_profile.tres" % actor_id,
            }))
    var bridge: String = production.path_join("scenes/rainy_bridge/baseline")
    batch.append(Importer.plan("scene",
        bridge.path_join("scene_rainy_bridge_background_v01.png"),
        "res://data/maps/rainy_bridge.tres", {
            "ground": bridge.path_join("scene_rainy_bridge_ground_v01.png"),
            "foreground": bridge.path_join("scene_rainy_bridge_foreground_v01.png"),
            "weather": bridge.path_join("scene_rainy_bridge_weather_v01.png"),
            "story_preview": bridge.path_join("scene_rainy_bridge_composite_preview_v01.png"),
        }))
    for planned_import in batch:
        if not str(planned_import.get("error", "")).is_empty():
            _fail("Pilot full import plan failed: " + str(planned_import["error"]))
            return
    var full_import: Dictionary = Transaction.begin(batch)
    if not str(full_import.get("error", "")).is_empty():
        _fail("Pilot full import transaction failed: " + str(full_import["error"]))
        return
    var full_log: String = str(full_import["journal"])
    var live_map: WuxiaMapDefinition = ResourceLoader.load("res://data/maps/rainy_bridge.tres")
    live_map.background = load("res://assets/imported/scenes/rainy_bridge/legacy/rainy_bridge_battle.webp")
    live_map.image_rotation_degrees = -6.0
    live_map.image_scale = 1.1
    for planned_import in batch:
        var copied: String = Importer.copy_images(planned_import["files"])
        if not copied.is_empty():
            Transaction.rollback(full_log, true)
            _fail("Pilot image copy failed: " + copied)
            return
        var bound: String = Importer.save_bindings(planned_import)
        if not bound.is_empty():
            Transaction.rollback(full_log, true)
            _fail("Pilot native Resource binding failed: " + bound)
            return
    var full_saved: String = Transaction.commit(full_log)
    if not full_saved.is_empty():
        Transaction.rollback(full_log, true)
        _fail("Pilot full import commit failed: " + full_saved)
        return
    var imported_map: WuxiaMapDefinition = load("res://data/maps/rainy_bridge.tres")
    if imported_map.background != imported_map.scene_art.background or imported_map.scene_art.story_preview == null or \
            imported_map.image_rotation_degrees != 0.0 or imported_map.image_scale != 1.0:
        _fail("Full import left old map, transformation or story art active")
        return
    var live_hero: WuxiaCharacterDefinition = ResourceLoader.load(character_path)
    if live_factory.presentation_assets("shen_changfeng").get("portrait") != live_hero.portrait:
        _fail("Full import left a live CharacterFactory with historical art")
        return
    var full_restored: String = Transaction.rollback(full_log)
    if not full_restored.is_empty():
        _fail("Pilot full import rollback failed: " + full_restored)
        return
    for path in before_paths:
        if FileAccess.get_sha256(path) != str(before_hashes[path]):
            _fail("Pilot full import rollback changed original bytes: " + path)
            return

    print("ART_WORKFLOW_ROUNDTRIP_OK")
    quit(0)


func _fail(message: String) -> void:
    push_error(message)
    quit(1)
