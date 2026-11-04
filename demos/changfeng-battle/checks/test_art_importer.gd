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
    var source: String = production_dir.path_join("in-use/placeholders/characters/default_actor_6x4.svg")
    var image: Dictionary = Importer.inspect(source)
    if not str(image.get("error", "")).is_empty() or int(image["width"]) <= 0:
        _fail("SVG preview failed: " + str(image.get("error", "")))
        return
    if not Importer.destination(source).begins_with("res://assets/imported/in-use/"):
        _fail("Source destination has incorrect root")
        return
    var candidate_actor: String = production_dir.path_join(
        "candidates/characters/shen_changfeng/baseline/portrait_shen_changfeng_fullbody_v01.png")
    if Importer.destination(candidate_actor, "portrait") != \
            "res://assets/imported/candidates/characters/shen_changfeng/portraits/portrait_shen_changfeng_fullbody_v01.png":
        _fail("Candidate portrait was not grouped by character and type")
        return
    var candidate_sprite: String = production_dir.path_join(
        "candidates/characters/shen_changfeng/baseline/sprite_shen_changfeng_atlas_normalized_v02.png")
    if Importer.destination(candidate_sprite, "atlas") != \
            "res://assets/imported/candidates/characters/shen_changfeng/sprites/sprite_shen_changfeng_atlas_normalized_v02.png":
        _fail("Candidate atlas was not grouped with the character sprites")
        return
    var candidate_scene: String = production_dir.path_join(
        "candidates/scenes/rainy_bridge/baseline/scene_rainy_bridge_ground_v01.png")
    if Importer.destination(candidate_scene, "scene") != \
            "res://assets/imported/candidates/scenes/rainy_bridge/scene_rainy_bridge_ground_v01.png":
        _fail("Candidate scene layer retained a production batch directory")
        return
    if not Importer.destination(candidate_actor).is_empty():
        _fail("Candidate image was accepted without an import type")
        return
    var atlas: Dictionary = Importer.plan("atlas", source, "res://data/native/characters/shen_changfeng.tres",
        {"columns": 6, "rows": 4, "feet_offset": Vector2(0, -102), "faces_left": false})
    if not str(atlas.get("error", "")).is_empty():
        _fail("Valid atlas plan rejected: " + str(atlas.get("error", "")))
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
    var opaque_jpg: String = production_dir.path_join("in-use/scenes/mountain_herbal_workshop/mountain_herbal_workshop_day.jpg")
    var opaque_vfx: Dictionary = Importer.plan("vfx", opaque_jpg, "",
        {"asset_id": "art.opaque_vfx", "event_kind": "ATTACK_DECLARED"})
    if str(opaque_vfx.get("error", "")).is_empty():
        _fail("Opaque JPEG accepted as production VFX")
        return
    var ui_source: String = production_dir.path_join("in-use/ui/cards/card_probe.svg")
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
