extends SceneTree
## Candidate Resources are native/editor-only, and must never auto-register as
## current art. The source can live outside the Godot project directory.
const ROOT := "res://data/art_candidates"
const Service = preload("res://addons/wuxia_art_importer/art_import_service.gd")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")
var count := 0
var failures: Array[String] = []


func _initialize() -> void:
    _scan(ROOT)
    var unmeasured := WuxiaArtCandidateDefinition.new()
    unmeasured.asset_kind = "sprite"
    unmeasured.reference_visible_height_px = 100.0
    if absf(unmeasured.display_scale() - 2.0) > 0.001:
        failures.append("200px actor height did not normalize reference silhouette")
    var sprite := Sprite2D.new()
    sprite.texture = ImageTexture.create_from_image(Image.create(32, 32, false, Image.FORMAT_RGBA8))
    if not VisualScale.fit(sprite, Vector2.ONE * 2.0, 200.0, Vector2.ZERO, 0, false) \
            or not sprite.scale.is_equal_approx(Vector2.ONE * 2.0):
        failures.append("Explicit Resource actor scale was overridden by automatic fitting")
    sprite.free()
    var invalid_sheet: String = ProjectSettings.globalize_path("res://").path_join(
        "../../art-production/candidates/characters/shen_changfeng/sprite-v04/sprite_shen_changfeng_core_8x4_source_v04.png").simplify_path()
    var blocked: Dictionary = Service.plan("atlas", invalid_sheet,
        "res://data/native/characters/shen_changfeng.tres", {"columns": 8, "rows": 4})
    if not str(blocked.get("error", "")).contains("C×R"):
        failures.append("Undeclared candidate grid was accepted for runtime import")
    if count < 1:
        failures.append("No candidate Resources found")
    if not failures.is_empty():
        for failure in failures:
            push_error(failure)
        quit(1)
        return
    print("PASS: %d candidate Resource sources and dimensions" % count)
    quit(0)


func _scan(directory: String) -> void:
    var dir := DirAccess.open(directory)
    if dir == null:
        failures.append("Missing candidate Resource directory: " + directory)
        return
    for filename in DirAccess.get_files_at(directory):
        if not filename.ends_with(".tres"):
            continue
        var path := directory.path_join(filename)
        var resource: Resource = ResourceLoader.load(path)
        if not resource is WuxiaArtCandidateDefinition:
            failures.append("Not an art candidate Resource: " + path)
            continue
        count += 1
        var candidate := resource as WuxiaArtCandidateDefinition
        var error: String = candidate.validate_source()
        if not error.is_empty():
            failures.append(error)
        if Service.candidate_for_source(candidate.source_absolute_path()) != candidate:
            failures.append("Importer cannot resolve candidate Resource: " + path)
        if candidate.asset_kind == "sprite" and candidate.reference_visible_height_px == 0.0 \
                and candidate.display_scale_override == 0.0 and candidate.display_scale() != 0.0:
            failures.append("Unmeasured candidate was assigned a guessed display scale: " + path)
    for child in DirAccess.get_directories_at(directory):
        _scan(directory.path_join(child))
