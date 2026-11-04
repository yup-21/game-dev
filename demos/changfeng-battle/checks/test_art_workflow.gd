extends SceneTree
## P2 read-only export/batch contract, checked against P0 static index.
const Importer = preload("res://addons/wuxia_art_importer/art_import_service.gd")
const Export = preload("res://addons/wuxia_art_importer/art_export_service.gd")
const Transaction = preload("res://addons/wuxia_art_importer/art_transaction_service.gd")
const Dock = preload("res://addons/wuxia_art_importer/art_import_dock.gd")
const ArtBinding = preload("res://scripts/content/art_resource_binding.gd")


func _initialize() -> void:
    # Native resources are the inventory. Validate the live exporter directly;
    # there is no second JSON source of truth.
    var everything: Dictionary = Export.plan("all")
    if not str(everything.get("error", "")).is_empty():
        _fail("All export preflight: " + str(everything["error"]))
        return
    var count := 0
    for item in everything["entries"]:
        count += 1
        if FileAccess.get_sha256(str(item["destination"])) != str(item["sha256"]):
            _fail("Current Resource and production mirror differ: " + str(item["source"]))
            return
    if count < 20 or int(everything["replaces"]) != 0 or not bool(everything["can_apply"]):
        _fail("Current art dependency export differs or requires overwrite")
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
    var chapter_scene: Dictionary = Export.plan(
        "scene", "res://data/native/chapters/rain_escort_prologue.tres")
    if not str(chapter_scene.get("error", "")).is_empty() or chapter_scene["entries"].is_empty():
        _fail("Story chapter dependency export is incomplete: " + str(chapter_scene.get("error", "")))
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
    # Convention-only art is live even without an explicit .tres texture literal.
    var manual := WuxiaCharacterDefinition.new()
    manual.content_id = "shen_changfeng"
    manual.battle_actor_id = 0
    var manual_path := "res://assets/imported/characters/black_blade/portraits/portrait.png"
    manual.portrait = ResourceLoader.load(manual_path) as Texture2D
    if manual.portrait == null or not ArtBinding.apply(manual).is_empty():
        _fail("Explicit portrait and convention-based sprite failed to resolve")
        return
    var resolved_paths: Array[String] = Export.native_image_paths(manual)
    if not resolved_paths.has(manual_path) or not resolved_paths.has(
            "res://assets/imported/characters/shen_changfeng/sprites/atlas.png") or resolved_paths.has(
            "res://assets/imported/characters/shen_changfeng/portraits/portrait.png"):
        _fail("Exporter ignored the manual override or missed default sprite")
        return
    var standalone := WuxiaActorAnimationProfile.new()
    var clip := WuxiaActorAnimationClip.new()
    clip.atlas = manual.sprite_sheet
    standalone.clips.append(clip)
    if not Export.native_image_paths(standalone).has(manual.sprite_sheet.resource_path):
        _fail("Independent Clip atlas was not exported")
        return
    if not Export.destination("res://assets/legacy/obsolete.png").is_empty():
        _fail("Exporter accepted non-imported path")
        return
    var source: String = Importer.production_root().path_join("in-use/placeholders/characters/default.svg")
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
    print("ART_WORKFLOW_CONTRACT_OK: %s active images" % str(count))
    quit(0)


func _fail(message: String) -> void:
    push_error(message)
    quit(1)
