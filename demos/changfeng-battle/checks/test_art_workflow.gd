extends SceneTree
## P2 read-only export/batch contract, checked against P0 static index.
const Importer = preload("res://addons/wuxia_art_importer/art_import_service.gd")
const Export = preload("res://addons/wuxia_art_importer/art_export_service.gd")
const Transaction = preload("res://addons/wuxia_art_importer/art_transaction_service.gd")
const Dock = preload("res://addons/wuxia_art_importer/art_import_dock.gd")


func _initialize() -> void:
    var index_path: String = Export.production_root().path_join("inventory/asset-index.json")
    var index_data = JSON.parse_string(FileAccess.get_file_as_string(index_path))
    if not index_data is Dictionary:
        _fail("P0 inventory is unreadable")
        return
    var expected: Dictionary = {}
    for item in index_data["assets"]:
        if item["usage_state"] == "in_use":
            expected[str(item["res_path"])] = str(item["sha256"])
    var everything: Dictionary = Export.plan("all")
    if not str(everything.get("error", "")).is_empty():
        _fail("All export preflight: " + str(everything["error"]))
        return
    var actual: Dictionary = {}
    for item in everything["entries"]:
        actual[str(item["source"])] = str(item["sha256"])
        if FileAccess.get_sha256(str(item["destination"])) != str(item["sha256"]):
            _fail("P0 source and production copy differ: " + str(item["source"]))
            return
    if expected != actual:
        _fail("Export scan differs from P0 inventory (%s versus %s)" % [
            str(actual.size()), str(expected.size())])
        return
    if int(everything["replaces"]) != 0 or not bool(everything["can_apply"]):
        _fail("Identical P0 files were marked for overwrite")
        return
    var character: Dictionary = Export.plan(
        "character", "res://data/native/characters/shen_changfeng.tres")
    if not str(character.get("error", "")).is_empty() or character["entries"].size() < 3:
        _fail("Character dependency export is incomplete")
        return
    var scene: Dictionary = Export.plan("scene", "res://data/maps/rainy_bridge.tres")
    if not str(scene.get("error", "")).is_empty() or scene["entries"].is_empty():
        _fail("Map dependency export is incomplete: " + str(scene.get("error", "")))
        return
    var specific: Dictionary = Export.plan(
        "resource", "res://data/native/characters/shen_changfeng.tres")
    if specific["entries"].size() != character["entries"].size():
        _fail("Explicit Resource dependency export differs")
        return
    if str(Export.plan("character", "res://data/maps/rainy_bridge.tres").get("error", "")).is_empty():
        _fail("Map was accepted as character")
        return
    if str(Export.plan("resource", "res://../outside.tres").get("error", "")).is_empty():
        _fail("Escaping res:// was accepted")
        return
    var source: String = Importer.production_root().path_join("in-use/fallback/default_actor_6x4.svg")
    var atlas: Dictionary = Importer.plan("atlas", source,
        "res://data/native/characters/shen_changfeng.tres",
        {"columns": 6, "rows": 4, "versioned_replace": true})
    var ui: Dictionary = Importer.plan("ui_atlas", source, "", {"asset_id": "art.p2_probe"})
    var plans: Array[Dictionary] = [atlas, ui]
    if not Transaction.validate(plans).is_empty():
        _fail("Valid batch rejected: " + Transaction.validate(plans))
        return
    var duplicates: Array[Dictionary] = [ui, ui]
    if Transaction.validate(duplicates).is_empty():
        _fail("Repeated target allowed into batch")
        return
    var dock := Dock.new()
    root.add_child(dock)
    await process_frame
    if dock.export_kind == null or dock.export_kind.item_count != 4:
        _fail("Export scope controls did not initialize")
        return
    if dock.queue_list == null or dock.queue_review_button == null:
        _fail("Batch queue controls did not initialize")
        return
    dock.queue_free()
    print("ART_WORKFLOW_CONTRACT_OK: %s active images" % str(actual.size()))
    quit(0)


func _fail(message: String) -> void:
    push_error(message)
    quit(1)
