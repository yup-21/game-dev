extends SceneTree
## Validate one REAL 4800x1000 native layered fixture, not only synthetic offsets.
const Scale = preload("res://scripts/combat_scale.gd")
const Bake = preload("res://scripts/map_bake.gd")
const Shift = preload("res://scripts/world_viewport_offset.gd")
const Spatial = preload("res://scripts/battle_spatial_service.gd")
const MAP_PATH := "res://data/maps/pingjiang_long_street_qa.tres"
var failures := 0

func check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("PINGJIANG_SCROLL: " + reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var map := load(MAP_PATH) as WuxiaMapDefinition
    check(map != null, "map Resource is importable")
    if map == null:
        quit(1)
        return
    check(map.viewport_size == Vector2i(4800, 1000) and map.primary_axis == "horizontal",
        "world is three landscape screens, not a stretched single-screen")
    check(map.background != null and Vector2i(map.background.get_size()) == map.viewport_size,
        "actual background texture has native 4800x1000 dimensions")
    check(map.scene_art != null and map.scene_art.valid_for(map.viewport_size),
        "all three real image layers share a 4800x1000 origin and 80px unit scale")
    check(map.to_record().size() > 0, "WuxiaMapDefinition passes native content contract")
    var bake = Bake.new(MAP_PATH)
    check(bake.error.is_empty() and bake.polygon_mode,
        "MapBake can load long painting and walkable polygon")
    if not bake.error.is_empty():
        quit(1)
        return
    check(is_equal_approx(bake.pixels_per_unit, Scale.PIXELS_PER_UNIT),
        "long map preserves 80 pixels per combat unit")
    var radius := Scale.footprint_radius_pixels()
    var left := Vector2(200, 790)
    var center := Vector2(2400, 790)
    var right := Vector2(4600, 790)
    check(bake.is_walkable_point(left, radius) and bake.is_walkable_point(center, radius)
        and bake.is_walkable_point(right, radius), "three viewport samples accept actor footprint")
    check(not bake.is_walkable_point(Vector2(2400, 580), radius)
        and not bake.is_walkable_point(Vector2(2400, 975), radius),
        "buildings and outside road remain unwalkable")
    var space = Spatial.new(MAP_PATH)
    check(space.is_valid_position(left, radius) and space.is_valid_position(right, radius)
        and space.clear_segment(left, right, radius),
        "FREE navigation stays continuous over the entire three-screen road")
    check(bake.markers.has("player_start") and bake.markers.has("street_mid")
        and bake.markers.has("street_end"), "authored anchor points survive bake")
    check(Shift.world_offset(left, Vector2(map.viewport_size)) == Vector2.ZERO,
        "near western edge the camera is clamped")
    check(Shift.world_offset(center, Vector2(map.viewport_size)) == Vector2(-1600, 0),
        "middle of long street scrolls to second viewport")
    check(Shift.world_offset(right, Vector2(map.viewport_size)) == Vector2(-3200, 0),
        "near eastern edge the camera clamps to end of painting")
    var screen := Vector2(800, 790)
    var stage_offset := Shift.world_offset(center, Vector2(map.viewport_size))
    check(Shift.screen_to_world(screen, stage_offset) == center
        and Shift.world_to_screen(center, stage_offset) == screen,
        "mouse-to-world and world-to-screen remain invertible after scrolling")
    check(Scale.actor_height_pixels() == 200.0 and radius == 24.0,
        "actor scale and ground footprint did not change")
    print("PINGJIANG_SCROLL_PASS failures=%d" % failures)
    quit(1 if failures > 0 else 0)
