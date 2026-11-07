extends SceneTree
## Disposable two-phase test; driven by tools/test_native_sheet_import_roundtrip.py.
const Service = preload("res://addons/wuxia_art_importer/art_import_service.gd")
const Transaction = preload("res://addons/wuxia_art_importer/art_transaction_service.gd")

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error("NATIVE_SHEET_ROUNDTRIP: " + message)


func _initialize() -> void:
    call_deferred("_run")


func _fields(source_path: String) -> Dictionary:
    var actions := {"idle": "0:0", "walk": "0:1-2", "run": "0:3",
        "attack1": "0:4", "attack2": "0:5", "attack3": "0:6",
        "attack4": "0:7", "skill": "0:8", "evade": "0:9",
        "guard": "0:10", "hit": "0:11", "defeat": "0:12"}
    return {"composition_native": true, "composition_tall": false,
        "composition_sources": [{"path": source_path, "columns": 5, "rows": 5,
            "cell_width": 40, "cell_height": 40, "origin_x": 0, "origin_y": 0,
            "gap_x": 0, "gap_y": 0, "offsets": {},
            "rects": {0: Rect2i(2, 2, 36, 36)},
            "canvas_offsets": {0: Vector2i(1, 0)},
            "masks": {0: PackedVector2Array([
                Vector2(9, 9), Vector2(30, 9), Vector2(30, 30), Vector2(9, 30)])}}],
        "composition_actions": actions,
        "composition_metadata": {"walk": {"fps": 10.0,
            "loop": true, "durations": "0.12,0.18"}},
        "feet_offset": Vector2(0, -102), "versioned_replace": false}


func _run() -> void:
    var actor_id := OS.get_environment("WUXIA_SHEET_TEST_ID")
    var phase := OS.get_environment("WUXIA_SHEET_TEST_PHASE")
    if not actor_id.begins_with("native_sheet_test_") or phase not in ["prepare", "apply"]:
        push_error("Run via disposable native sheet test harness")
        quit(1)
        return
    var card_path := "res://data/native/characters/" + actor_id + ".tres"
    var relative := "characters/" + actor_id + "/sheets/test"
    var source_path := Service.production_root().path_join("candidates/" + relative + ".png")
    var candidate_path := "res://data/art_candidates/" + relative + ".tres"
    if phase == "prepare":
        check(not FileAccess.file_exists(card_path) and
            not FileAccess.file_exists(candidate_path), "fixture paths must be unused")
        if failures.is_empty():
            var card := WuxiaCharacterDefinition.new()
            card.content_id = actor_id
            card.display_name = "Disposable native sheet fixture"
            check(ResourceSaver.save(card, card_path) == OK, "save temporary actor")
            var candidate := WuxiaArtCandidateDefinition.new()
            candidate.asset_kind = "sprite"
            candidate.owner_id = actor_id
            candidate.source_path = "art-production/candidates/" + relative + ".png"
            candidate.source_pixel_size = Vector2i(200, 200)
            check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
                candidate_path).get_base_dir()) == OK, "create candidate directory")
            check(candidate.validate_source().is_empty(), "temporary candidate is valid")
            check(ResourceSaver.save(candidate, candidate_path) == OK, "save temporary candidate")
    var before_card := FileAccess.get_file_as_string(card_path)
    var before_candidate := FileAccess.get_file_as_string(candidate_path)
    var plan: Dictionary = Service.plan_composition(card_path, _fields(source_path))
    check(str(plan.get("error", "")).is_empty(),
        "plan native assembly: " + str(plan.get("error", "")))
    if failures.is_empty():
        check(plan.has("native_frames_path") and plan["candidate_updates"].size() == 1,
            "plan native frames and candidate crop metadata")
    if failures.is_empty() and phase == "prepare":
        check(Service.copy_images(plan["files"]).is_empty(), "stage versioned PNG for Godot import")
        print("SHEET_TEST_FRAMES=", str(plan["native_frames_path"]))
        print("SHEET_TEST_ATLAS=", str(plan["files"]["primary"]["destination"]))
    elif failures.is_empty():
        var plans: Array[Dictionary] = [plan]
        var transaction := Transaction.begin(plans)
        check(str(transaction.get("error", "")).is_empty(), "begin transaction")
        if failures.is_empty():
            var log_path := str(transaction["journal"])
            print("SHEET_TEST_JOURNAL=", log_path)
            check(Service.copy_images(plan["files"]).is_empty(), "verify generated PNG hash")
            var binding_error: String = Service.save_bindings(plan)
            check(binding_error.is_empty(), "save native bindings: " + binding_error)
            if failures.is_empty():
                check(Transaction.commit(log_path).is_empty(), "commit transaction")
                var frames_path := str(plan["native_frames_path"])
                var profile_path := str(plan["profile_path"])
                var texture_path := str(plan["files"]["primary"]["destination"])
                var frame_text := FileAccess.get_file_as_string(frames_path)
                var profile_text := FileAccess.get_file_as_string(profile_path)
                check(frame_text.contains(texture_path),
                    "SpriteFrames.tres keeps an external PNG reference")
                check(profile_text.contains(frames_path),
                    "animation Profile references external SpriteFrames.tres")
                var restored := ResourceLoader.load(card_path, "",
                    ResourceLoader.CACHE_MODE_REPLACE) as WuxiaCharacterDefinition
                check(restored != null and restored.animation_profile != null and
                    restored.animation_profile.native_frames != null,
                    "character resolves native SpriteFrames after reload")
                if restored != null and restored.animation_profile != null and \
                        restored.animation_profile.native_frames != null:
                    var native := restored.animation_profile.native_frames
                    check(native.get_animation_names().size() == 12 and
                        native.get_frame_count("walk") == 2 and
                        absf(native.get_frame_duration("walk", 1) - 1.8) < 0.001,
                        "native twelve actions and exact per-frame duration")
                var staged := ResourceLoader.load(candidate_path, "",
                    ResourceLoader.CACHE_MODE_REPLACE) as WuxiaArtCandidateDefinition
                check(staged != null and staged.grid_cell_rects.has(0) and
                    staged.grid_cutout_polygons.has(0),
                    "source cutout geometry persisted into candidate .tres")
                var rollback_error := Transaction.rollback(log_path)
                check(rollback_error.is_empty(), "transaction rollback: " + rollback_error)
                check(FileAccess.get_file_as_string(card_path) == before_card and
                    FileAccess.get_file_as_string(candidate_path) == before_candidate,
                    "rollback restores actor and candidate without altering source")
                print("SHEET_TEST_ROLLBACK=", rollback_error.is_empty())
            else:
                check(Transaction.rollback(log_path, true).is_empty(),
                    "failed transaction restores fixture resources")
    print("NATIVE_SHEET_ROUNDTRIP failures=", failures.size(), " phase=", phase)
    quit(1 if not failures.is_empty() else 0)
