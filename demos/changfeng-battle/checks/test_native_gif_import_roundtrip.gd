extends SceneTree
## Runs only in a disposable integration fixture created by the Python check.
const Service = preload("res://addons/wuxia_art_importer/native_gif_import.gd")
const Transaction = preload("res://addons/wuxia_art_importer/art_transaction_service.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error("GIF_IMPORT_ROUNDTRIP: " + message)

func _run() -> void:
    var id := OS.get_environment("WUXIA_GIF_TEST_ID")
    if not id.begins_with("native_gif_test_"):
        push_error("Fixture actor ID must have native_gif_test_ prefix")
        quit(1)
        return
    var path := "res://data/native/characters/" + id + ".tres"
    check(not FileAccess.file_exists(path), "fixture must never overwrite a real character")
    if FileAccess.file_exists(path):
        quit(1)
        return
    var card := WuxiaCharacterDefinition.new()
    card.content_id = id
    card.display_name = "GIF transaction fixture"
    check(ResourceSaver.save(card, path) == OK, "fixture Resource saved")
    var original_text: String = FileAccess.get_file_as_string(path)
    var folder: String = ProjectSettings.globalize_path("res://").path_join("../../art-production").simplify_path().path_join(
        "candidates/characters/" + id + "/actions")
    var mapping := "idle=" + folder.path_join("idle.gif") + "\n" + \
        "attack1=" + folder.path_join("attack1.gif")
    var registered := Service.register_candidates(path, mapping)
    check(str(registered.get("error", "")).is_empty() and int(registered.get("created", 0)) == 2,
        "candidate .tres registrations use the GIF dimensions and action names")
    var planned := Service.plan(path, mapping)
    check(str(planned.get("error", "")).is_empty(), "preflight decodes GIFs")
    if str(planned.get("error", "")).is_empty():
        var result := Service.apply(planned)
        check(str(result.get("error", "")).is_empty(), "native .tres transaction commits: " + \
            str(result.get("error", "")))
        if str(result.get("error", "")).is_empty():
            var imported := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as WuxiaCharacterDefinition
            check(imported.animation_profile != null and imported.animation_profile.native_frames != null,
                "character .tres now points to SpriteFrames")
            if imported.animation_profile != null and imported.animation_profile.native_frames != null:
                check(imported.animation_profile.native_frames.get_frame_count("idle") == 2,
                    "actual two-frame native animation was imported")
            var rollback := Transaction.rollback(str(result["journal"]))
            check(rollback.is_empty(), "transaction can restore previous character")
            var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as WuxiaCharacterDefinition
            check(original_text == FileAccess.get_file_as_string(path) and restored.animation_profile == null,
                "rollback restores original empty character animation binding")
            print("GIF_TEST_JOURNAL=", str(result["journal"]))
    print("NATIVE_GIF_IMPORT_ROUNDTRIP failures=", failures)
    quit(1 if failures > 0 else 0)
