extends Control
## Read-only CTB gauge track. The BattleModel/TurnManager owns all charge
## advancement; this control only projects published gauge values to pixels.
const ArtCatalog = preload("res://scripts/hd2d_art_catalog.gd")
const MarkerScene = preload("res://scenes/ui/ctb_marker.tscn")
const CHARGE := 10000.0
@export_range(0.0, 100.0, 1.0) var top_inset := 49.0
@export_range(0.0, 100.0, 1.0) var bottom_inset := 42.0
@export_range(20.0, 64.0, 1.0) var portrait_size := 36.0
@export_range(0.05, 1.0, 0.01) var glide_seconds := 0.32
const ALLY := Color("83d6bc")
const ENEMY := Color("d28c80")
const GOLD := Color("e8c989")

var _actors: Array = []
var _priority_id := -1
var _markers: Dictionary = {}
var _marker_y: Dictionary = {}
var _target_y: Dictionary = {}
var _start_y: Dictionary = {}
var _glide_elapsed: Dictionary = {}
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Labels, avatar mask, shaft and individual ticks are editable native nodes.
    resized.connect(func():
        _layout_track()
        _layout_markers(true))
    _layout_track()

func _layout_track() -> void:
    var upper := top_inset
    var lower := maxf(upper, size.y - bottom_inset)
    var center := size.x * 0.5
    var shaft: Line2D = get_node("TrackShaft") as Line2D
    shaft.points = PackedVector2Array([Vector2(center, upper), Vector2(center, lower)])
    var ticks: Node2D = get_node("Ticks") as Node2D
    for step in range(11):
        var tick: Line2D = ticks.get_node("Tick%d" % step) as Line2D
        tick.position = Vector2(center, lerpf(lower, upper, float(step) / 10.0))

func gauge_y(value: float) -> float:
    # An active actor may legitimately exceed the threshold. Clamp only its
    # display position; never normalize or change the underlying CTB value.
    return lerpf(maxf(top_inset, size.y - bottom_inset), top_inset,
        clampf(value / CHARGE, 0.0, 1.0))

func _portrait_x(enemy: bool) -> float:
    # Opposing lanes meet precisely at the rail: the inner edge of each
    # portrait touches the shaft, while its vertical position stays exact.
    var center := size.x * 0.5
    return center if enemy else center - portrait_size

func set_state(actors: Array, priority_id: int) -> void:
    _actors = actors.duplicate(true)
    _priority_id = priority_id
    var live: Dictionary = {}
    for actor in _actors:
        var id := int(actor.get("id", -1))
        if id < 0:
            continue
        live[id] = true
        var enemy := int(actor.get("team_id", 0)) != 0
        if not _markers.has(id):
            _markers[id] = _make_marker(id, enemy)
        var frame: Panel = _markers[id]
        frame.visible = float(actor.get("hp", 0.0)) > 0.0
        frame.modulate = Color.WHITE if id == _priority_id else Color(1, 1, 1, 0.88)
        frame.z_index = 2 if id == _priority_id else 1
        var rim := frame.get_node_or_null("Rim") as TextureRect
        if rim != null:
            rim.modulate = GOLD if id == _priority_id else (ENEMY if enemy else ALLY)
        frame.tooltip_text = "%s\n集气 %d / %d" % [
            str(actor.get("name", "江湖客")), int(actor.get("gauge", 0)), int(CHARGE)]
    for id in _markers.keys():
        if not live.has(id):
            _markers[id].queue_free()
            _markers.erase(id)
    _layout_markers()

func _make_marker(id: int, enemy: bool) -> Panel:
    var frame: Panel = MarkerScene.instantiate()
    frame.name = "Charge_%d" % id
    frame.custom_minimum_size = Vector2(portrait_size, portrait_size)
    frame.size = Vector2(portrait_size, portrait_size)
    frame.mouse_filter = Control.MOUSE_FILTER_STOP
    frame.set_meta("actor_id", id)
    var avatar: TextureRect = frame.get_node("Portrait")
    avatar.texture = ArtCatalog.avatar(id, enemy)
    add_child(frame)
    return frame

func _layout_markers(snap_immediately: bool = false) -> void:
    if size.y <= top_inset + bottom_inset:
        return
    var live: Dictionary = {}
    for actor in _actors:
        var id := int(actor.get("id", -1))
        if id < 0 or not _markers.has(id) or float(actor.get("hp", 0.0)) <= 0.0:
            continue
        live[id] = true
        var target := gauge_y(float(actor.get("gauge", 0.0)))
        # Allies sit left of the shaft, enemies right. Equal charge values
        # intentionally overlap inside a team; no collision-spacing offset
        # ever changes their authoritative Y position.
        if snap_immediately or not _marker_y.has(id):
            _marker_y[id] = target
            _target_y[id] = target
            _start_y[id] = target
            _glide_elapsed[id] = glide_seconds
        elif not is_equal_approx(float(_target_y.get(id, target)), target):
            # Retarget from the current rendered position, not an old goal.
            # Repeated identical snapshots must not restart the animation.
            _start_y[id] = float(_marker_y[id])
            _target_y[id] = target
            _glide_elapsed[id] = 0.0
        var frame: Panel = _markers[id]
        var enemy := int(actor.get("team_id", 0)) != 0
        frame.position = Vector2(_portrait_x(enemy),
            float(_marker_y[id]) - portrait_size * 0.5)
    for id in _marker_y.keys():
        if live.has(id):
            continue
        _marker_y.erase(id)
        _target_y.erase(id)
        _start_y.erase(id)
        _glide_elapsed.erase(id)
    queue_redraw()

func _process(delta: float) -> void:
    var changed := false
    for id in _target_y.keys():
        if not _markers.has(id):
            continue
        var elapsed := minf(glide_seconds,
            float(_glide_elapsed.get(id, glide_seconds)) + maxf(delta, 0.0))
        _glide_elapsed[id] = elapsed
        var t := elapsed / glide_seconds
        var ease_out := 1.0 - pow(1.0 - t, 3.0)
        var y := lerpf(float(_start_y[id]), float(_target_y[id]), ease_out)
        if is_equal_approx(y, float(_marker_y[id])):
            continue
        _marker_y[id] = y
        var frame: Panel = _markers[id]
        frame.position = Vector2(frame.position.x, y - portrait_size * 0.5)
        changed = true
    if changed:
        queue_redraw()

func _draw() -> void:
    var cx := size.x * 0.5
    if size.y - bottom_inset <= top_inset:
        return
    # Only transient charge trajectories remain procedural; the stationary
    # ornament, shaft, ticks and captions are authored in the .tscn.
    for actor in _actors:
        var id := int(actor.get("id", -1))
        if not _marker_y.has(id):
            continue
        var y := float(_marker_y[id])
        var enemy := int(actor.get("team_id", 0)) != 0
        var tint := ENEMY if enemy else ALLY
        if id == _priority_id:
            tint = GOLD
        # Travel streaks stay immediately beside the shaft, while the
        # separate ally/enemy halos follow the corresponding portraits.
        var target := float(_target_y.get(id, y))
        var near_axis_x := cx + (3.0 if enemy else -3.0)
        var portrait_cx := cx + (portrait_size * 0.5 if enemy else -portrait_size * 0.5)
        if absf(target - y) > 1.0:
            draw_line(Vector2(near_axis_x, y), Vector2(near_axis_x, target),
                Color(tint, 0.25), 2.0, true)
        draw_circle(Vector2(portrait_cx, y), portrait_size * 0.5 + 2.0,
            Color(tint, 0.17))
