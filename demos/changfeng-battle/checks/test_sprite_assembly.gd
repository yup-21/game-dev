extends SceneTree
## Run: godot --headless --path demos/changfeng-battle --script res://checks/test_sprite_assembly.gd
const Assembly = preload("res://addons/wuxia_art_importer/sprite_assembly.gd")
const Service = preload("res://addons/wuxia_art_importer/art_import_service.gd")
var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _source(color_offset: int, offset_grid: bool = false) -> Dictionary:
    var image := Image.create(210 if offset_grid else 200, 208 if offset_grid else 200,
        false, Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    var source := {"columns": 5, "rows": 5, "cell_width": 40, "cell_height": 40,
        "origin_x": 2 if offset_grid else 0, "origin_y": 1 if offset_grid else 0,
        "gap_x": 1 if offset_grid else 0, "gap_y": 1 if offset_grid else 0,
        "offsets": {4: Vector2i(1, 0)} if offset_grid else {}}
    for index in range(25):
        var rectangle := Assembly.cell_rect(source, index)
        image.fill_rect(Rect2i(rectangle.position + Vector2i(12, 12), Vector2i(8, 8)),
            Color(float(color_offset + index + 1) / 70.0, 0.3, 0.7, 1.0))
    source["texture"] = ImageTexture.create_from_image(image)
    return source


func _initialize() -> void:
    var original_candidate: WuxiaArtCandidateDefinition = Service.candidate_for_source(
        Service.production_root().path_join("candidates/characters/shen_changfeng/sprite-v04/sprite_shen_changfeng_core_8x4_source_v04.png"))
    check(original_candidate != null and original_candidate.columns == 0,
        "candidate fixture starts with an undeclared CxR grid")
    if original_candidate != null:
        var size := original_candidate.source_pixel_size
        var calibrated := Service._stage_candidate_grid(original_candidate, {"columns": 5,
            "rows": 5, "cell_width": size.x / 5, "cell_height": size.y / 5,
            "origin_x": 0, "origin_y": 0, "gap_x": 0, "gap_y": 0, "offsets": {}})
        check(calibrated.columns == 5 and calibrated.rows == 5 and \
            calibrated.validate_source().is_empty(),
            "undeclared candidate grid accepts explicitly calibrated visual geometry")
        check(original_candidate.columns == 0,
            "calibrating a candidate does not mutate its original Resource before confirmation")
        var cropped_candidate := Service._stage_candidate_grid(original_candidate, {
            "columns": 5, "rows": 5, "cell_width": size.x / 5,
            "cell_height": size.y / 5, "origin_x": 0, "origin_y": 0,
            "gap_x": 0, "gap_y": 0, "offsets": {},
            "rects": {0: Rect2i(1, 2, 20, 20)},
            "canvas_offsets": {0: Vector2i(3, -1)},
            "scales": {0: 0.75}, "anchors": {0: Vector2(12, 17)},
            "masks": {0: PackedVector2Array([Vector2(2, 3), Vector2(18, 3), Vector2(12, 17)])}})
        check(cropped_candidate.validate_source().is_empty() and
            cropped_candidate.grid_cell_rects[0] == Rect2i(1, 2, 20, 20) and
            cropped_candidate.grid_canvas_offsets[0] == Vector2i(3, -1) and
            cropped_candidate.grid_cutout_polygons[0].size() == 3 and
            cropped_candidate.grid_frame_scales[0] == 0.75 and
            cropped_candidate.grid_frame_anchors[0] == Vector2(12, 17) and
            original_candidate.grid_frame_scales.is_empty(),
            "candidate stages crop, mask, scale and foot point without modifying the original")
        var candidate_path := "user://sprite_assembly_candidate_roundtrip.tres"
        var candidate_saved := ResourceSaver.save(cropped_candidate, candidate_path)
        var restored_candidate := ResourceLoader.load(candidate_path, "",
            ResourceLoader.CACHE_MODE_IGNORE) as WuxiaArtCandidateDefinition
        check(candidate_saved == OK and restored_candidate != null and
            restored_candidate.grid_frame_scales.get(0) == 0.75 and
            restored_candidate.grid_frame_anchors.get(0) == Vector2(12, 17),
            "candidate .tres roundtrip retains the frame transform")
    var sources := [_source(0), _source(25, true)]
    var mappings := {"idle": "0:0-1", "walk": "0:2-3", "run": "0:4",
        "attack1": "0:5", "attack2": "0:6", "attack3": "0:7", "attack4": "0:8",
        "skill": "0:9", "evade": "1:3,1:0", "guard": "1:1", "hit": "1:2", "defeat": "1:4"}
    var metadata := {"walk": {"loop": true, "fps": 8.0, "durations": "0.10,0.15"},
        "defeat": {"loop": false, "fps": 9.0}}
    var result: Dictionary = Assembly.build(sources, mappings, metadata)
    check(str(result.get("error", "")).is_empty(), "multi-sheet build: " + str(result.get("error", "")))
    if str(result.get("error", "")).is_empty():
        check(int(result["count"]) == 15, "total authored frames")
        check(result["texture"].get_size() == Vector2(200, 120), "packed atlas layout")
        check(result["clips"]["evade"]["frames"] == PackedInt32Array([10, 11]),
            "noncontinuous reverse mapping")
        check(result["clips"]["walk"]["durations"] == PackedFloat32Array([0.10, 0.15]),
            "per-frame duration preservation")
        var template := WuxiaActorAnimationProfile.new()
        var profile: WuxiaActorAnimationProfile = Service._composed_profile(template,
            result["texture"], result, {"feet_offset": Vector2(0, -100)})
        check(profile.valid_profile() and profile.clips.size() == 12 and
            profile.action_fallbacks.is_empty(), "native twelve-action profile")
        check(profile.clip_for("defeat").loop == false and
            profile.clip_for("walk").loop, "defeat terminal / walk loop")
        var output: Image = result["texture"].get_image()
        check(output.get_pixel(12, 12).a > 0.9 and output.get_pixel(4, 4).a == 0.0,
            "pixels preserved with transparent 8px+ margin")
        var normalized := Assembly.build(sources, mappings, metadata, Vector2i(328, 256))
        check(str(normalized.get("error", "")).is_empty(),
            "common proportional normalization: " + str(normalized.get("error", "")))
        if str(normalized.get("error", "")).is_empty():
            check(normalized["texture"].get_size() == Vector2(1640, 768) and
                absf(float(normalized["scale_factor"]) - 6.4) < 0.001,
                "uniform scale and transparent padding to normal-size cell")
        var native: SpriteFrames = Service.native_frames_from_assembly(result,
            result["texture"])
        check(native.has_animation("attack4") and native.get_frame_count("walk") == 2 and
            native.get_animation_loop("walk") and not native.get_animation_loop("defeat") and
            absf(native.get_frame_duration("walk", 0) - 0.8) < 0.001 and
            absf(native.get_frame_duration("walk", 1) - 1.2) < 0.001,
            "native SpriteFrames preserves each action, loop, order and relative durations")
        var native_profile := WuxiaActorAnimationProfile.new()
        native_profile.native_frames = native
        check(native_profile.valid_profile(), "native SpriteFrames is accepted by Profile")
        var native_path := "user://sprite_assembly_native_roundtrip.tres"
        var saved := ResourceSaver.save(native, native_path)
        var restored: SpriteFrames = ResourceLoader.load(native_path, "SpriteFrames",
            ResourceLoader.CACHE_MODE_IGNORE) as SpriteFrames
        check(saved == OK and restored != null and
            restored.get_frame_count("evade") == 2 and
            absf(restored.get_frame_duration("walk", 1) - 1.2) < 0.001,
            "native SpriteFrames .tres roundtrip retains authored frame timing")

    var invalid: Dictionary = Assembly.parse_mapping("2:0", 2)
    check(not str(invalid["error"]).is_empty(), "invalid source reference rejected")
    var missing := mappings.duplicate(true)
    missing.erase("attack2")
    check(str(Assembly.build(sources, missing, metadata).get("error", "")).contains("attack2"),
        "missing action rejected; no fallback")
    var edge_source: Dictionary = _source(0)
    var edge_image: Image = (edge_source["texture"] as Texture2D).get_image()
    edge_image.set_pixel(1, 1, Color.WHITE)
    edge_source["texture"] = ImageTexture.create_from_image(edge_image)
    var edge_result := Assembly.build([edge_source, sources[1]], mappings, metadata)
    check(str(edge_result.get("error", "")).contains("8px"), "edge contamination rejected")
    var invalid_duration := metadata.duplicate(true)
    invalid_duration["walk"] = {"durations": "0.2"}
    check(str(Assembly.build(sources, mappings, invalid_duration).get("error", "")).contains("时长"),
        "mismatched frame durations rejected")
    var shifted := sources.duplicate(true)
    shifted[1] = sources[1].duplicate(true)
    shifted[1]["cell_height"] = 39
    var variable_cells := Assembly.build(shifted, mappings, metadata)
    check(str(variable_cells.get("error", "")).is_empty() and
        variable_cells.get("source_cell") == Vector2i(40, 40) and
        absf(float(variable_cells.get("scale_factor", 0.0)) - 1.0) < 0.001,
        "mixed source cell dimensions use one scale, without per-frame stretching")
    var independently_cropped: Dictionary = sources[0].duplicate(true)
    independently_cropped["rects"] = {0: Rect2i(2, 2, 36, 36)}
    var cropped: Dictionary = Assembly.build([independently_cropped, sources[1]], mappings, metadata)
    check(str(cropped.get("error", "")).is_empty() and
        Assembly.cell_rect(independently_cropped, 0) == Rect2i(2, 2, 36, 36),
        "per-frame rectangle overrides the source grid")
    var contaminated: Dictionary = sources[0].duplicate(true)
    var dirty_image: Image = (contaminated["texture"] as Texture2D).get_image()
    dirty_image.set_pixel(35, 12, Color.RED)
    contaminated["texture"] = ImageTexture.create_from_image(dirty_image)
    check(str(Assembly.build([contaminated, sources[1]], mappings, metadata)
        .get("error", "")).contains("8px"), "adjacent frame residue rejected without mask")
    contaminated["masks"] = {0: PackedVector2Array([
        Vector2(9, 9), Vector2(30, 9), Vector2(30, 30), Vector2(9, 30)])}
    var masked := Assembly.build([contaminated, sources[1]], mappings, metadata)
    check(str(masked.get("error", "")).is_empty(),
        "hand-drawn polygon removes adjacent frame residue before margin validation")
    if str(masked.get("error", "")).is_empty():
        var image: Image = (masked["texture"] as Texture2D).get_image()
        check(image.get_pixel(35, 12).a == 0 and image.get_pixel(16, 16).a > 0.9,
            "polygon mask clears outside pixels and preserves the character")
    var invalid_polygon := Assembly.mask_frame(dirty_image.get_region(Rect2i(0, 0, 40, 40)),
        Rect2i(0, 0, 40, 40), PackedVector2Array([
            Vector2(0, 0), Vector2(45, 0), Vector2(0, 40)]))
    check(not str(invalid_polygon["error"]).is_empty(),
        "polygon points outside the crop are rejected")

    var transformed := [_source(0), _source(25, true)]
    transformed[0]["scales"] = {0: 0.5, 1: 0.75}
    transformed[0]["anchors"] = {0: Vector2(20, 30), 1: Vector2(60, 30)}
    var target := Vector2i(80, 80)
    var aligned := Assembly.build(transformed, mappings, metadata, target)
    check(str(aligned.get("error", "")).is_empty(),
        "independent scaled frames fit shared canvas: " + str(aligned.get("error", "")))
    if str(aligned.get("error", "")).is_empty():
        var atlas: Image = aligned["texture"].get_image()
        for i in range(2):
            var preview := Assembly.preview_frame(transformed, 0, i, target)
            check(str(preview.get("error", "")).is_empty() and
                preview["texture"].get_image().get_data() ==
                    atlas.get_region(Rect2i(Vector2i(i * 80, 0), target)).get_data(),
                "frame %d preview and Atlas output match exactly" % i)
        check(atlas.get_region(Rect2i(0, 0, 80, 80)).get_used_rect() == Rect2i(32, 46, 8, 8),
            "first frame projects picked foot point to common output foot point")
    transformed[0]["scales"][0] = 1.0
    transformed[0]["anchors"][0] = Vector2(20, 22)
    var padded := Assembly.build(transformed, mappings, metadata, target)
    check(str(padded.get("error", "")).is_empty(),
        "alignment can discard transparent padding beyond the canvas: " + str(padded.get("error", "")))
    if str(padded.get("error", "")).is_empty():
        var padded_atlas: Image = padded["texture"].get_image()
        var padded_preview := Assembly.preview_frame(transformed, 0, 0, target)
        check(str(padded_preview.get("error", "")).is_empty() and
            padded_preview["texture"].get_image().get_data() ==
                padded_atlas.get_region(Rect2i(Vector2i.ZERO, target)).get_data(),
            "padded frame preview and Atlas output match exactly")
    transformed[0]["anchors"][0] = Vector2(-1, 30)
    check(str(Assembly.build(transformed, mappings, metadata, target).get("error", "")).contains("脚点"),
        "out-of-crop foot point is rejected")
    transformed[0]["anchors"][0] = Vector2(20, 30)
    transformed[0]["scales"][0] = 8.0
    var overflow := str(Assembly.build(transformed, mappings, metadata, target).get("error", ""))
    check(overflow.contains("超出输出画布"), "scaled frame overflow is rejected: " + overflow)

    if not failures.is_empty():
        for message in failures:
            push_error(message)
        quit(1)
        return
    print("SPRITE_ASSEMBLY_PASS: multigraph actions, offsets, margin, timings, native Resource")
    quit(0)
