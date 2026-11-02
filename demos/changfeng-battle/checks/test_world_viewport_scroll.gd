extends SceneTree
## Vertical/horizontal/mixed stages scroll visually while feet, LOS and
## authored map points stay in the same 80px/unit world coordinates.
const ViewportShift = preload("res://scripts/world_viewport_offset.gd")
const Scale = preload("res://scripts/combat_scale.gd")
var failed := 0

func verify(ok: bool, detail: String) -> void:
    if not ok:
        failed += 1
        push_error("WORLD_SCROLL: " + detail)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var view := ViewportShift.VIEWPORT_SIZE
    verify(view == Vector2(1600,1000), "screen UI remains landscape 1600x1000")
    verify(ViewportShift.world_offset(Vector2(700,800),view) == Vector2.ZERO,
        "existing single-screen opening/battle is unchanged")
    var vertical := Vector2(1600,2400)
    verify(ViewportShift.world_offset(Vector2(800,240),vertical) == Vector2.ZERO,
        "north entrance cannot scroll beyond top edge")
    var middle := ViewportShift.world_offset(Vector2(800,1250),vertical)
    verify(middle == Vector2(0,-750),
        "vertical center follows feet without changing X axis")
    verify(ViewportShift.world_offset(Vector2(800,2310),vertical) == Vector2(0,-1400),
        "south exit clamps at bottom edge")
    verify(ViewportShift.world_offset(Vector2(2400,500),Vector2(3200,1000))
        == Vector2(-1600,0),"horizontal street can scroll right")
    verify(ViewportShift.world_offset(Vector2(2000,1700),Vector2(2400,2200))
        == Vector2(-800,-1200),"mixed map follows both axes")
    var screen := Vector2(720,560)
    var world := ViewportShift.screen_to_world(screen,middle)
    verify(world == Vector2(720,1310)
        and ViewportShift.world_to_screen(world,middle) == screen,
        "mouse-to-foot and foot-to-screen coordinates invert exactly")
    verify(is_equal_approx(Scale.to_units(160.0),2.0),
        "scrolling does not modify world length units")
    var chapter := load("res://data/native/chapters/rain_escort_prologue.tres") as WuxiaChapterDefinition
    verify(chapter != null and not chapter.to_record().is_empty(),
        "existing story definition remains importable")
    if chapter != null:
        var staging: WuxiaChapterSceneDefinition = chapter.scene.duplicate(true)
        verify(staging.world_size == Vector2i(1600,1000),
            "existing chapter has 1600x1000 world by default")
        staging.world_size = Vector2i(1600,2400)
        verify(staging.to_record().is_empty(),
            "oversized story refuses reused single-screen background")
    var painted = load("res://data/maps/rainy_bridge.tres") as WuxiaMapDefinition
    if painted != null:
        var staged_map: WuxiaMapDefinition = painted.duplicate(true)
        staged_map.viewport_size = Vector2i(1600,2400)
        staged_map.area_bounds = Rect2(80,320,1440,1800)
        verify(staged_map.to_record().is_empty(),
            "oversized world rejects stretched old painted map")
    print("WORLD_SCROLL_PASS failures=%d" % failed)
    quit(1 if failed else 0)
