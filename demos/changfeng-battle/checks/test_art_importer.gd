extends SceneTree
## P1 offline import contract. No file is copied or modified by this test.
const Importer = preload("res://addons/wuxia_art_importer/art_import_service.gd")
const Dock = preload("res://addons/wuxia_art_importer/art_import_dock.gd")
const Transaction = preload("res://addons/wuxia_art_importer/art_transaction_service.gd")
const Assets = preload("res://scripts/asset_registry.gd")

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
    var source: String = production_dir.path_join("in-use/placeholders/characters/default.svg")
    var image: Dictionary = Importer.inspect(source)
    if not str(image.get("error", "")).is_empty() or int(image["width"]) <= 0:
        _fail("SVG preview failed: " + str(image.get("error", "")))
        return
    if not Importer.destination(source).begins_with("res://assets/imported/"):
        _fail("Source destination has incorrect root")
        return
    var candidate_actor: String = production_dir.path_join(
        "candidates/characters/shen_changfeng/baseline/portrait_shen_changfeng_fullbody_v01.png")
    if Importer.destination(candidate_actor, "portrait") != \
            "res://assets/imported/characters/shen_changfeng/portraits/portrait.png":
        _fail("Candidate portrait was not grouped by character and type")
        return
    var candidate_sprite: String = production_dir.path_join(
        "candidates/characters/shen_changfeng/baseline/sprite_shen_changfeng_atlas_normalized_v02.png")
    if Importer.destination(candidate_sprite, "atlas") != \
            "res://assets/imported/characters/shen_changfeng/sprites/atlas_normalized_v02.png":
        _fail("Candidate atlas was not grouped with the character sprites")
        return
    var candidate_scene: String = production_dir.path_join(
        "candidates/scenes/rainy_bridge/baseline/scene_rainy_bridge_ground_v01.png")
    if Importer.destination(candidate_scene, "scene") != \
            "res://assets/imported/scenes/rainy_bridge/ground.png":
        _fail("Candidate scene layer retained a production batch directory")
        return
    if not Importer.destination(candidate_actor).is_empty():
        _fail("Candidate image was accepted without an import type")
        return
    var organized := production_dir.path_join("in-use/characters/black_blade")
    var folder_plan: Dictionary = Importer.plan_character_folder(organized,
        "res://data/native/characters/black_blade.tres", {})
    if not str(folder_plan.get("error", "")).is_empty() or folder_plan["files"].size() != 2 or \
            not folder_plan["files"].has("portrait") or not folder_plan["files"].has("atlas"):
        _fail("Organized character folder failed to build a two-asset plan: " + str(folder_plan.get("error", "")))
        return
    if not str(Importer.plan("character_folder", organized,
            "res://data/native/characters/black_blade.tres", {}).get("error", "")).is_empty():
        _fail("Generic importer plan did not dispatch character folders")
        return
    var imported: Dictionary = Importer.plan_character_folder(
        "res://assets/imported/characters/black_blade",
        "res://data/native/characters/black_blade.tres", {})
    if not str(imported.get("error", "")).is_empty() or \
            str(imported["files"]["atlas"]["path"]) != str(imported["files"]["atlas"]["destination"]):
        _fail("Already-organized imported character folder was not accepted directly")
        return
    var filesystem_imported: Dictionary = Importer.plan_character_folder(
        ProjectSettings.globalize_path("res://assets/imported/characters/black_blade"),
        "res://data/native/characters/black_blade.tres", {})
    if not str(filesystem_imported.get("error", "")).is_empty() or filesystem_imported["files"].size() != 2:
        _fail("Filesystem picker path did not resolve an already-imported character")
        return
    var sample := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    sample.fill(Color(0, 0, 0, 0))
    sample.set_pixel(10, 10, Color.WHITE)
    var valid_sample := ImageTexture.create_from_image(sample)
    if not Importer.candidate_frame_geometry_error(valid_sample, 1, 1, PackedInt32Array([0])).is_empty():
        _fail("Contained single candidate frame was rejected")
        return
    sample.set_pixel(0, 0, Color.WHITE)
    if Importer.candidate_frame_geometry_error(ImageTexture.create_from_image(sample),
            1, 1, PackedInt32Array([0])).is_empty():
        _fail("Candidate source frame touching its border was accepted")
        return
    if str(Importer.plan_character_folder(organized,
            "res://data/native/characters/shen_changfeng.tres", {}).get("error", "")).is_empty():
        _fail("Cross-character folder import was allowed")
        return
    var existing_portrait: Dictionary = Importer.plan("portrait",
        organized.path_join("portraits/portrait.png"),
        "res://data/native/characters/black_blade.tres", {})
    if Transaction.validate([folder_plan, existing_portrait]).is_empty():
        _fail("Folder import mixed with a second binding to the same Resource")
        return
    var wrong_owner: Dictionary = Importer.plan("portrait", candidate_actor,
        "res://data/native/characters/black_blade.tres", {})
    if not str(wrong_owner.get("error", "")).contains("角色 ID"):
        _fail("Cross-character candidate was accepted")
        return
    var atlas: Dictionary = Importer.plan("atlas", source, "res://data/native/characters/shen_changfeng.tres",
        {"columns": 6, "rows": 4, "feet_offset": Vector2(0, -102), "faces_left": false,
        "reuse_existing_clips": true})
    if not str(atlas.get("error", "")).is_empty():
        _fail("Valid atlas plan rejected: " + str(atlas.get("error", "")))
        return
    var unbound: Dictionary = Importer.plan("atlas", source,
        "res://data/native/characters/shen_changfeng.tres", {"columns": 6, "rows": 4})
    if not str(unbound.get("error", "")).contains("自由装配"):
        _fail("New sheet silently inherited the old Profile frame sequence")
        return
    var invalid_clip: Dictionary = Importer.plan("atlas", source,
        "res://data/native/characters/shen_changfeng.tres", {
            "columns": 6, "rows": 4,
            "clip_profile_path": "res://data/art_previews/not_a_profile.tres"})
    if str(invalid_clip.get("error", "")).is_empty():
        _fail("Missing custom clip profile was accepted")
        return
    var vfx_plan: Dictionary = Importer.plan("vfx", source, "",
        {"asset_id": "art.vfx_probe_test", "event_kind": "TEST_VFX",
         "columns": 6, "rows": 4, "frame_indices": PackedInt32Array([0, 1, 2])})
    if not str(vfx_plan.get("error", "")).is_empty() or vfx_plan.get("frame_indices", PackedInt32Array()).size() != 3:
        _fail("Valid transparent VFX atlas rejected: " + str(vfx_plan.get("error", "")))
        return
    var invalid_vfx: Dictionary = Importer.plan("vfx", source, "",
        {"asset_id": "art.bad_vfx", "columns": 6, "rows": 4,
         "frame_indices": PackedInt32Array([999])})
    if str(invalid_vfx.get("error", "")).is_empty():
        _fail("Out-of-range VFX animation index accepted")
        return
    var vfx_source: String = production_dir.path_join(
        "in-use/vfx/shen_changfeng/martial-forms/atlas.svg")
    var vfx_owner: Dictionary = Importer.plan("vfx", vfx_source, "", {
        "asset_id": "art.vfx_owner_probe", "event_kind": "ATTACK_DECLARED"})
    if not str(vfx_owner.get("error", "")).is_empty() or str(vfx_owner.get(
            "owner_character_id", "")) != "shen_changfeng" or not str(vfx_owner.get(
            "next_binding", "")).ends_with("/vfx/shen_changfeng/martial-forms/atlas.svg"):
        _fail("VFX owner or canonical filename was not inferred: " + str(vfx_owner.get("error", "")))
        return
    if not Importer._new_asset_card("vfx") is WuxiaVFXDefinition or \
            Importer._new_asset_card("ui_atlas") is WuxiaVFXDefinition:
        _fail("Importer creates the wrong native VFX/UI Resource type")
        return
    var live_vfx: WuxiaVFXDefinition = load(
        "res://data/native/assets/shen_sword_thrust.tres") as WuxiaVFXDefinition
    if live_vfx == null or live_vfx.owner_character_id != "shen_changfeng" or \
            not live_vfx.resource.resource_path.ends_with("/vfx/shen_changfeng/martial-forms/atlas.svg"):
        _fail("Shen martial VFX Resource was not migrated to the typed canonical binding")
        return
    var asset_registry = Assets.new()
    if not asset_registry.load_error.is_empty():
        _fail("Character-owned multi-skill VFX rejected: " + asset_registry.load_error)
        return
    var extra_vfx: Dictionary = asset_registry.record("shen_sword_thrust")
    extra_vfx["id"] = "art.vfx_second_skill_probe"
    extra_vfx["event_kind"] = ""
    if not asset_registry._register(extra_vfx):
        _fail("Multiple VFX for one actor were treated as duplicate character art")
        return
    var opaque_jpg: String = production_dir.path_join("in-use/scenes/mountain_herbal_workshop/background.jpg")
    var opaque_vfx: Dictionary = Importer.plan("vfx", opaque_jpg, "",
        {"asset_id": "art.opaque_vfx", "event_kind": "ATTACK_DECLARED"})
    if str(opaque_vfx.get("error", "")).is_empty():
        _fail("Opaque JPEG accepted as production VFX")
        return
    var ui_source: String = production_dir.path_join("in-use/ui/cards/probe.svg")
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
    if dock.source_list.item_count < 39 or dock.kind.item_count != 6:
        _fail("Editor dock failed to enumerate candidate sources")
        return
    dock.kind.select(1)
    dock._mode_changed()
    if dock.action_select.item_count != 12:
        _fail("New Atlas editor still displays nine historical actions")
        return
    dock.compose_enabled.button_pressed = true
    dock._mode_changed()
    var composed_source := ""
    for index in range(dock.source_list.item_count):
        var path := str(dock.source_list.get_item_metadata(index))
        if path.ends_with("/in-use/characters/black_blade/sprites/atlas.png"):
            dock.source_list.select(index)
            composed_source = path
            break
    if composed_source.is_empty():
        _fail("Cannot find a source for the visual grid editor")
        return
    dock._add_composition_source()
    if dock.compose_sources.size() != 1 or dock.preview.mode != "grid":
        _fail("Composer did not add a source and show the grid")
        return
    dock._on_grid_cell_clicked(3)
    if dock.compose_mapping.text != "0:3":
        _fail("Clicking grid did not assign a frame to the selected action")
        return
    dock.compose_numbers["local_x"].value = 2
    if dock.compose_sources[0]["offsets"].get(3, Vector2i.ZERO) != Vector2i(2, 0):
        _fail("Per-cell grid adjustment was not retained")
        return
    dock.compose_grid.button_pressed = false
    dock._refresh_preview()
    if dock.preview.mode != "slice":
        _fail("Action preview is not using the authored source-frame mapping")
        return
    dock.kind.select(5)
    dock._mode_changed()
    if not dock.folder_row.visible or dock.source_list.visible:
        _fail("Whole-character folder UI did not switch to directory selection")
        return
    dock._folder_changed(organized)
    if dock._target() != "res://data/native/characters/black_blade.tres":
        _fail("Whole-character folder did not auto-select the matching character Resource")
        return
    dock.kind.select(2)
    dock._mode_changed()
    var chapter_found := false
    for index in range(dock.targets.item_count):
        if str(dock.targets.get_item_metadata(index)) == "res://data/native/chapters/rain_escort_prologue.tres":
            chapter_found = true
            break
    if not chapter_found:
        _fail("Chapter story scenes are missing from the scene import selector")
        return
    dock.queue_free()
    var bridge_dir: String = production_dir.path_join("candidates/scenes/rainy_bridge/baseline")
    var bridge_plan: Dictionary = Importer.plan("scene",
        bridge_dir.path_join("scene_rainy_bridge_background_v01.png"),
        "res://data/maps/rainy_bridge.tres", {
            "ground": bridge_dir.path_join("scene_rainy_bridge_ground_v01.png"),
            "foreground": bridge_dir.path_join("scene_rainy_bridge_foreground_v01.png"),
            "weather": bridge_dir.path_join("scene_rainy_bridge_weather_v01.png"),
            "story_preview": bridge_dir.path_join("scene_rainy_bridge_composite_preview_v01.png")
        })
    var bridge_card: WuxiaMapDefinition = load("res://data/maps/rainy_bridge.tres")
    if not str(bridge_plan.get("error", "")).is_empty() or bridge_plan["files"].size() != 5 or \
            str(bridge_plan.get("current_binding", "")) != bridge_card.background.resource_path:
        _fail("Scene import must preflight the current map background and composite preview")
        return
    var wrong_scene: Dictionary = Importer.plan("scene",
        bridge_dir.path_join("scene_rainy_bridge_background_v01.png"),
        "res://data/maps/pingjiang_long_street_qa.tres", {})
    if not str(wrong_scene.get("error", "")).contains("场景素材 ID"):
        _fail("Cross-scene candidate was accepted")
        return
    var bad := Importer.plan("portrait", source, "res://data/maps/rainy_bridge.tres", {})
    if str(bad.get("error", "")).is_empty():
        _fail("Portrait import accepted map Resource")
        return
    bad = Importer.plan("scene", source, "res://data/maps/rainy_bridge.tres", {})
    if str(bad.get("error", "")).is_empty():
        _fail("Missing scene ground was accepted")
        return
    bad = Importer.plan("scene", source, "res://data/native/chapters/rain_escort_prologue.tres", {})
    if str(bad.get("error", "")).contains("目标不是有效的地图或章节"):
        _fail("Chapter definition was not recognized as a scene target")
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
