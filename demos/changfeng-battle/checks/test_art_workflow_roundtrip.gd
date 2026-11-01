extends SceneTree
## CI-only write/rollback smoke test. Run on a disposable checkout, never on live artwork.
const Export = preload("res://addons/wuxia_art_importer/art_export_service.gd")
const Transaction = preload("res://addons/wuxia_art_importer/art_transaction_service.gd")

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
    print("ART_WORKFLOW_ROUNDTRIP_OK")
    quit(0)


func _fail(message: String) -> void:
    push_error(message)
    quit(1)
