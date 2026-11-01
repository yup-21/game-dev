extends SceneTree
## R23: freeform map Resource, continuous obstacle collision and editor files.
const Native = preload("res://scripts/content/content_registry.gd")
const MapBake = preload("res://scripts/map_bake.gd")
const Spatial = preload("res://scripts/battle_spatial_service.gd")
const MapDef = preload("res://scripts/content/map_definition.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("R23_MAP_FAIL: " + label)

func _run() -> void:
    const PATH = "res://data/maps/r23_free_brush_map.tres"
    var native = Native.new()
    check(native.load_error.is_empty() and native.entries("map").has("r23_free_brush_map"),
        "native freehand map registered by stable ID")
    var map: Resource = ResourceLoader.load(PATH)
    check(map is MapDef and not map.to_record().is_empty(),
        "Inspector map definition produces checked polygon records")
    var authored := WuxiaMapDefinition.new()
    authored.content_id = "r23_roundtrip"
    authored.background = map.background
    authored.area_bounds = map.area_bounds
    var painted := WuxiaMapPolygonDefinition.new()
    painted.terrain_kind = "rock"
    painted.vertices = PackedVector2Array([Vector2(300,250),Vector2(400,250),
        Vector2(400,350),Vector2(300,350)])
    authored.obstacles.append(painted)
    var roundtrip_path: String = "user://r23_roundtrip.tres"
    check(ResourceSaver.save(authored,roundtrip_path) == OK,
        "Inspector-authored map can be saved as a native Resource")
    var reloaded: Resource = ResourceLoader.load(roundtrip_path)
    check(reloaded is WuxiaMapDefinition and reloaded.obstacles.size() == 1
        and reloaded.obstacles[0].vertices.size() == 4,
        "polygon vertices survive a .tres save/reload roundtrip")
    var bake = MapBake.new(PATH)
    check(bake.error.is_empty() and bake.polygon_mode and bake.polygons.size() == 1,
        "MapBake consumes native polygons without any authored grid rows")
    check(bake.terrain.size() == 150 and bake.width == 15 and bake.height == 10,
        "legacy GRID compatibility index remains available")
    var start := Vector2(650,300)
    var target := Vector2(950,300)
    var blocked := Vector2(800,300)
    check(bake.is_walkable_point(start,8.0) and bake.is_walkable_point(target,8.0)
        and not bake.is_walkable_point(blocked,8.0),
        "continuous points use polygon collision independent from cell centre")
    check(bake.segment_blocked(start,target,8.0)
        and bake.cell_at_screen(blocked,true) == Vector2i(-1,-1),
        "thin authored obstruction blocks a crossing and occupied point")
    var spatial = Spatial.new(PATH)
    check(spatial.bake.error.is_empty()
        and spatial.is_valid_position(start,8.0) and spatial.is_valid_position(target,8.0)
        and not spatial.is_valid_position(blocked,8.0),
        "FREE spatial service uses the exact authored polygon mask")
    check(not spatial.clear_segment(start,target,8.0),
        "FREE straight segment cannot tunnel through a painted polygon")
    var path: PackedVector2Array = spatial.find_path(start,target,8.0)
    check(path.size() > 2 and spatial.path_length(path) > start.distance_to(target),
        "FREE visibility graph detours around polygon corners")
    var sound_path: bool = true
    for i in range(path.size()-1):
        if not spatial.clear_segment(path[i],path[i+1],8.0):
            sound_path = false
    check(sound_path, "detour segments are continuously collision-free")
    var legacy = MapBake.new()
    check(legacy.error.is_empty() and not legacy.polygon_mode and legacy.terrain.size() == 150,
        "original authored bridge JSON remains unchanged and valid")
    check(ResourceLoader.exists("res://addons/wuxia_map_editor/plugin.gd","Script")
        and ResourceLoader.exists("res://addons/wuxia_map_editor/map_painter_canvas.gd","Script"),
        "editor painter scripts are bundled for Inspector use")
    print("R23_NATIVE_MAPS_PASS failures=",failures)
    quit(0 if failures == 0 else 1)
