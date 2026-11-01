extends SceneTree
## CI-only write/rollback smoke test. Run on a disposable checkout, never on live artwork.
const Export = preload("res://addons/wuxia_art_importer/art_export_service.gd")
const Transaction = preload("res://addons/wuxia_art_importer/art_transaction_service.gd")
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
    # Exercise the REAL candidate portrait and layered scene on the disposable
    # CI checkout. Prove that stale in-memory map art is overwritten, and that
    # the transaction restores the exact authored .tres bytes afterwards.
    var bridge_path := "res://data/maps/rainy_bridge.tres"
    var bridge_before: String = FileAccess.get_sha256(bridge_path)
    var source_root: String = Importer.production_root().path_join("candidates/2026-11-01")
    var portrait_plan: Dictionary = Importer.plan("portrait",
        source_root.path_join("shen_changfeng/portrait_shen_changfeng_fullbody_v01.png"),
        character_path, {})
    var scene_root: String = source_root.path_join("rainy_bridge")
    var scene_plan: Dictionary = Importer.plan("scene",
        scene_root.path_join("scene_rainy_bridge_background_v01.png"),
        bridge_path, {
            "ground": scene_root.path_join("scene_rainy_bridge_ground_v01.png"),
            "foreground": scene_root.path_join("scene_rainy_bridge_foreground_v01.png"),
            "weather": scene_root.path_join("scene_rainy_bridge_weather_v01.png")
        })
    if not str(portrait_plan.get("error", "")).is_empty() or not str(scene_plan.get("error", "")).is_empty():
        _fail("Real art plans failed: " + str(portrait_plan.get("error", "")) + " / " +
            str(scene_plan.get("error", "")))
        return
    var real_plans: Array[Dictionary] = [portrait_plan, scene_plan]
    var import_start: Dictionary = Transaction.begin(real_plans)
    if not str(import_start.get("error", "")).is_empty():
        _fail("Real art transaction begin failed: " + str(import_start["error"]))
        return
    var real_log: String = str(import_start["journal"])
    for plan_data in real_plans:
        var copy_problem: String = Importer.copy_images(plan_data["files"])
        if not copy_problem.is_empty():
            _fail("Real candidate copy failed: " + copy_problem)
            return
    var map_card: WuxiaGridMapDefinition = ResourceLoader.load(bridge_path)
    map_card.background = load("res://assets/concepts/2026-10-30/scenes/rainy_broken_bridge_battle_v1.jpg")
    map_card.rotation_degrees = -6.0
    map_card.image_scale = 1.1
    for plan_data in real_plans:
        var bind_problem: String = Importer.save_bindings(plan_data)
        if not bind_problem.is_empty():
            _fail("Real candidate binding failed: " + bind_problem)
            return
    var expected_background: Texture2D = load(str(scene_plan["next_binding"]))
    if map_card.background != expected_background or map_card.scene_art == null or \
            map_card.scene_art.background != expected_background or \
            map_card.rotation_degrees != 0.0 or map_card.image_scale != 1.0:
        _fail("Scene importer left an old background or outdated calibration")
        return
    var shen_card: WuxiaCharacterDefinition = ResourceLoader.load(character_path)
    if shen_card.portrait == null or shen_card.portrait.resource_path != str(portrait_plan["next_binding"]):
        _fail("Portrait importer did not bind the native character card")
        return
    var real_commit: String = Transaction.commit(real_log)
    if not real_commit.is_empty():
        _fail("Real candidate transaction commit failed: " + real_commit)
        return
    restored = Transaction.rollback(real_log)
    if not restored.is_empty() or FileAccess.get_sha256(character_path) != original_hash or \
            FileAccess.get_sha256(bridge_path) != bridge_before:
        _fail("Real candidate rollback did not restore exact native Resources: " + restored)
        return
    print("ART_WORKFLOW_ROUNDTRIP_OK")
    quit(0)


func _fail(message: String) -> void:
    push_error(message)
    quit(1)
