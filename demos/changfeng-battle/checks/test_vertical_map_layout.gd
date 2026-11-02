extends SceneTree
## A tall road uses normal 2D world coordinates, no PNG rotation or actor zoom.
const Scale = preload("res://scripts/combat_scale.gd")
const MapBake = preload("res://scripts/map_bake.gd")
const Spatial = preload("res://scripts/battle_spatial_service.gd")
const PATH = "res://checks/fixtures/maps/qa_vertical_street.tres"
var failures := 0

func check(ok: bool, name: String) -> void:
    if not ok:
        failures += 1
        push_error("VERTICAL_MAP: " + name)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var resource := load(PATH) as WuxiaMapDefinition
    check(resource != null and resource.primary_axis == "vertical", "native vertical map resource")
    if resource == null:
        quit(1)
        return
    var native: Dictionary = resource.to_record()
    check(not native.is_empty() and str(native.get("primary_axis", "")) == "vertical",
        "vertical primary_axis roundtrips into record")
    check(is_equal_approx(float(native.get("pixels_per_unit", 0)), Scale.PIXELS_PER_UNIT),
        "vertical and horizontal maps use identical pixels per unit")
    var bake = MapBake.new(PATH)
    check(bake.error.is_empty() and bake.primary_axis == "vertical",
        "MapBake loads vertical polygon without rotating texture")
    check(bake.polygon_mode and bake.width == 15 and bake.height == 10,
        "existing GRID sampling compatibility remains")
    check(bake.markers.has("north_gate") and bake.markers.has("south_gate"),
        "north and south exit metadata retained")
    if bake.markers.has("north_gate") and bake.markers.has("south_gate"):
        check(str(bake.markers["north_gate"].get("exit_side", "")) == "north"
            and str(bake.markers["north_gate"].get("target_zone_id", "")) == "town_north_street"
            and str(bake.markers["south_gate"].get("exit_side", "")) == "south",
            "four-direction exit metadata survives bake")
    var north := Vector2(800, 160)
    var south := Vector2(800, 840)
    var radius: float = Scale.footprint_radius_pixels()
    check(bake.is_walkable_point(north, radius) and bake.is_walkable_point(south, radius)
        and not bake.is_walkable_point(Vector2(400, 520), radius),
        "walkable geometry follows the vertical corridor, not the painted backdrop")
    var space = Spatial.new(PATH)
    check(space.is_valid_position(north, radius) and space.is_valid_position(south, radius),
        "both vertical endpoints can hold a full-size actor")
    check(space.clear_segment(north, south, radius),
        "unobstructed north-south travel respects one radius")
    var route: PackedVector2Array = space.find_path(north, south, radius)
    check(route.size() == 2 and route[0] == north and route[-1] == south,
        "vertical road finds a direct FREE path")
    check(absf(space.path_length(route) - 680.0) < 0.01
        and absf(Scale.to_units(space.path_length(route)) - 8.5) < 0.01,
        "north-south travel costs the same world units as east-west")
    var mixed := resource.duplicate(true) as WuxiaMapDefinition
    mixed.primary_axis = "mixed"
    check(not mixed.to_record().is_empty(), "mixed/crossroad orientation accepted")
    mixed.primary_axis = "diagonal"
    check(mixed.to_record().is_empty(), "unsupported orientation rejected")
    var marker := WuxiaMapMarkerDefinition.new()
    marker.marker_id = "exit_for_test"
    marker.marker_kind = "zone_exit"
    marker.exit_side = "north"
    marker.target_zone_id = "next_zone"
    marker.target_entry_id = "south_gate"
    check(not marker.to_record().is_empty(), "typed north zone link accepted")
    marker.exit_side = "none"
    check(marker.to_record().is_empty(), "zone exit without a side rejected")
    marker.exit_side = "south"
    marker.target_entry_id = ""
    check(marker.to_record().is_empty(), "zone exit without a target entry rejected")
    var grid = load("res://checks/fixtures/maps/qa_open_arena.tres") as WuxiaGridMapDefinition
    check(grid != null and grid.primary_axis == "horizontal",
        "existing grid maps retain default horizontal orientation")
    print("VERTICAL_MAP_PASS failures=%d" % failures)
    quit(1 if failures else 0)
