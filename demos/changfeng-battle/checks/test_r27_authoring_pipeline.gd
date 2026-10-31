extends SceneTree
## R27: Inspector marker cards, map save/load, asset provenance and editor plugin.
const Native = preload("res://scripts/content/content_registry.gd")
const MapBake = preload("res://scripts/map_bake.gd")
const Assets = preload("res://scripts/asset_registry.gd")
const Art = preload("res://scripts/hd2d_art_catalog.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("R27 AUTHORING FAIL: " + label)

func _run() -> void:
    var native = Native.new()
    check(native.load_error.is_empty(), "manifest validates: " + native.load_error)
    var authored: Resource = load("res://data/maps/r24_fog_pass_map.tres")
    check(authored is WuxiaMapDefinition and authored.markers.size() == 3,
        "native map includes three editor-placed markers")
    var map = MapBake.new("res://data/maps/r24_fog_pass_map.tres")
    check(map.error.is_empty() and map.markers.size() == 3
        and map.marker_position("r27_hero_start") == Vector2(650,450)
        and map.markers_of_kind("spawn").size() == 2,
        "runtime resolves authored spawns by stable ID and kind")
    check(map.marker_position("not_registered") == Vector2.INF,
        "missing marker never silently snaps to origin")
    var duplicate := WuxiaMapMarkerDefinition.new()
    duplicate.marker_id = "r27_hero_start"
    duplicate.position = Vector2(1000,500)
    authored.markers.append(duplicate)
    check(authored.to_record().is_empty(), "duplicate markers fail editor validation")
    authored.markers.remove_at(authored.markers.size()-1)
    var roundtrip_path: String = "user://r27_map_roundtrip.tres"
    check(ResourceSaver.save(authored,roundtrip_path) == OK,
        "map obstacles, art and markers save in one native Resource")
    var restored: Resource = load(roundtrip_path)
    check(restored is WuxiaMapDefinition and restored.markers.size() == 3
        and restored.markers[0].marker_id == "r27_hero_start",
        "marker identity and world-space positions survive serialization")
    var bad := WuxiaMapMarkerDefinition.new()
    bad.marker_id = "r27_inside_wall"
    bad.position = Vector2(800,450)
    restored.markers.append(bad)
    var blocked_path: String = "user://r27_blocked_marker.tres"
    check(ResourceSaver.save(restored,blocked_path) == OK,
        "valid Inspector card can be staged as draft")
    check(not MapBake.new(blocked_path).error.is_empty(),
        "map load rejects markers overlapping collision polygons")
    var assets = Assets.new()
    check(assets.load_error.is_empty() and assets.definitions.size() >= 16,
        "original character art bindings join native registry: " + assets.load_error)
    for pair in [["gu_qingshuang","portrait"],["gu_qingshuang","pose_sheet"],
        ["green_wanderer","pose_sheet"],["black_blade","pose_sheet"],
        ["night_assassin","pose_sheet"],["escort_elder","portrait"],
        ["escort_elder","static_pose"],["river_messenger","pose_sheet"],
        ["pursuer_captain","portrait"]]:
        var record: Dictionary = assets.record_for_character(pair[0],pair[1])
        check(not record.is_empty() and record.get("rights","") == "owner_review_required"
            and record.get("status","") == "candidate"
            and assets.texture_for_character(pair[0],pair[1]) != null,
            "art has Resource binding, import and pending rights: " + str(pair))
    check(Art.sheet_for_character("green_wanderer") != null,
        "illustrated actor factory uses manifest-linked pose sheet")
    var config := ConfigFile.new()
    check(config.load("res://addons/wuxia_map_editor/plugin.cfg") == OK
        and config.get_value("plugin","script","") == "plugin.gd",
        "editor plugin path is relative and Godot-loadable")
    check(ResourceLoader.exists("res://addons/wuxia_map_editor/map_painter_canvas.gd","Script")
        and ResourceLoader.exists("res://addons/wuxia_map_editor/map_painter_dock.gd","Script"),
        "map painter with obstacle and marker modes ships in export")
    print("R27_AUTHORING_PIPELINE_PASS failures=",failures)
    quit(0 if failures == 0 else 1)
