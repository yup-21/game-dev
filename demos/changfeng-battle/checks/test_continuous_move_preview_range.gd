extends SceneTree
## FREE range is an exact geometric budget bound, not a claim that terrain
## inside the ring is traversable. Over-budget routes must be invisible.
const Preview = preload("res://scripts/continuous_move_preview.gd")
var failures := 0

func _check(ok: bool, detail: String) -> void:
    if not ok:
        failures += 1
        push_error("FREE_RANGE_UI: " + detail)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var parent := Node2D.new()
    get_root().add_child(parent)
    var preview = Preview.new()
    parent.add_child(preview)
    await process_frame
    preview.show_range(Vector2(100, 70), 90.0)
    _check(preview.visible and preview.range_fill.visible and preview.range_outline.visible,
        "movement range stays visible")
    _check(preview.range_fill.polygon.size() == 64,
        "range ring uses a smooth polygon")
    var route := PackedVector2Array([Vector2(100, 70), Vector2(180, 70)])
    preview.show_preview(route, 80.0, true, 90.0)
    _check(preview.route.visible and preview.route.points.size() == 2,
        "within-budget route is visible")
    preview.show_preview(route, 110.0, false, 90.0)
    _check(not preview.route.visible and not preview.marker.visible
        and preview.range_fill.visible,
        "over-budget route vanishes while range remains")
    preview.clear_preview()
    _check(preview.visible and preview.range_outline.visible,
        "hiding the route does not erase the range")
    preview.clear_all()
    _check(not preview.visible and not preview.range_fill.visible,
        "leaving FREE preview clears all indicators")
    print("FREE_RANGE_UI_PASS failures=%d" % failures)
    quit(1 if failures else 0)
