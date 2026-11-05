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
    check(str(Assembly.build(shifted, mappings, metadata).get("error", "")).contains("尺寸"),
        "mixed cell dimensions rejected instead of per-cell stretching")

    if not failures.is_empty():
        for message in failures:
            push_error(message)
        quit(1)
        return
    print("SPRITE_ASSEMBLY_PASS: multigraph actions, offsets, margin, timings, native Resource")
    quit(0)
