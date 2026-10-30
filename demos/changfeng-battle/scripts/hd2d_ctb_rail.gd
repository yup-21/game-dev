extends Control
## Read-only CTB gauge track. The BattleModel/TurnManager owns all charge
## advancement; this control only projects published gauge values to pixels.
const ArtCatalog = preload("res://scripts/hd2d_art_catalog.gd")
const CHARGE := 10000.0
const TOP := 49.0
const BOTTOM := 42.0
const PORTRAIT := 36.0
const GLIDE_SECONDS := 0.32
const ALLY := Color("83d6bc")
const ENEMY := Color("d28c80")
const GOLD := Color("e8c989")
const RAIL_ART: Texture2D = preload("res://assets/ui/ornaments/ctb_rail.svg")
const MARKER_FRAME: Texture2D = preload("res://assets/ui/ornaments/ctb_marker_frame.svg")

var _actors: Array = []
var _priority_id := -1
var _markers: Dictionary = {}
var _marker_y: Dictionary = {}
var _target_y: Dictionary = {}
var _start_y: Dictionary = {}
var _glide_elapsed: Dictionary = {}
var _round_avatar_material: ShaderMaterial

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Cropped avatar texture, with the original CTB actor image preserved.
    var round_shader := Shader.new()
    round_shader.code = "shader_type canvas_item;\nvoid fragment() {\n    vec2 d = UV - vec2(0.5);\n    if (dot(d, d) > 0.210) discard;\n    COLOR = texture(TEXTURE, UV);\n}\n"
    _round_avatar_material = ShaderMaterial.new()
    _round_avatar_material.shader = round_shader
    resized.connect(func(): _layout_markers(true))
    _caption("出手", true)
    _caption("集气", false)

func _caption(text_value: String, at_top: bool) -> void:
    var label := Label.new()
    label.name = "ReadyLabel" if at_top else "ChargeLabel"
    label.text = text_value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_color_override("font_color", GOLD)
    label.add_theme_font_size_override("font_size", 13)
    add_child(label)
    if at_top:
        label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
        label.offset_top = 0.0
        label.offset_bottom = 27.0
    else:
        label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
        label.offset_top = -28.0
        label.offset_bottom = 0.0

func gauge_y(value: float) -> float:
    # An active actor may legitimately exceed the threshold. Clamp only its
    # display position; never normalize or change the underlying CTB value.
    return lerpf(maxf(TOP, size.y - BOTTOM), TOP,
        clampf(value / CHARGE, 0.0, 1.0))

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
    var frame := Panel.new()
    frame.name = "Charge_%d" % id
    frame.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
    frame.size = Vector2(PORTRAIT, PORTRAIT)
    frame.mouse_filter = Control.MOUSE_FILTER_STOP
    var border := StyleBoxFlat.new()
    border.bg_color = Color("102a2b", 0.93)
    border.border_color = ENEMY if enemy else ALLY
    border.set_border_width_all(0)
    border.set_corner_radius_all(18)
    frame.add_theme_stylebox_override("panel", border)
    frame.set_meta("actor_id", id)
    var avatar := TextureRect.new()
    avatar.name = "Portrait"
    avatar.texture = ArtCatalog.avatar(id, enemy)
    avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    avatar.material = _round_avatar_material
    frame.add_child(avatar)
    avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    avatar.offset_left = 2.0
    avatar.offset_top = 2.0
    avatar.offset_right = -2.0
    avatar.offset_bottom = -2.0
    var rim := TextureRect.new()
    rim.name = "Rim"
    rim.texture = MARKER_FRAME
    rim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rim.stretch_mode = TextureRect.STRETCH_SCALE
    rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_child(rim)
    rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(frame)
    return frame

func _layout_markers(snap_immediately: bool = false) -> void:
    if size.y <= TOP + BOTTOM:
        return
    var live: Dictionary = {}
    for actor in _actors:
        var id := int(actor.get("id", -1))
        if id < 0 or not _markers.has(id) or float(actor.get("hp", 0.0)) <= 0.0:
            continue
        live[id] = true
        var target := gauge_y(float(actor.get("gauge", 0.0)))
        # All portraits occupy the exact same horizontal rail. Equal charge
        # values intentionally overlap; neither team nor arrival order offsets
        # the authoritative position.
        if snap_immediately or not _marker_y.has(id):
            _marker_y[id] = target
            _target_y[id] = target
            _start_y[id] = target
            _glide_elapsed[id] = GLIDE_SECONDS
        elif not is_equal_approx(float(_target_y.get(id, target)), target):
            # Retarget from the current rendered position, not an old goal.
            # Repeated identical snapshots must not restart the animation.
            _start_y[id] = float(_marker_y[id])
            _target_y[id] = target
            _glide_elapsed[id] = 0.0
        var frame: Panel = _markers[id]
        frame.position = Vector2((size.x - PORTRAIT) * 0.5,
            float(_marker_y[id]) - PORTRAIT * 0.5)
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
        var elapsed := minf(GLIDE_SECONDS,
            float(_glide_elapsed.get(id, GLIDE_SECONDS)) + maxf(delta, 0.0))
        _glide_elapsed[id] = elapsed
        var t := elapsed / GLIDE_SECONDS
        var ease_out := 1.0 - pow(1.0 - t, 3.0)
        var y := lerpf(float(_start_y[id]), float(_target_y[id]), ease_out)
        if is_equal_approx(y, float(_marker_y[id])):
            continue
        _marker_y[id] = y
        var frame: Panel = _markers[id]
        frame.position = Vector2((size.x - PORTRAIT) * 0.5,
            y - PORTRAIT * 0.5)
        changed = true
    if changed:
        queue_redraw()

func _draw() -> void:
    var bottom := size.y - BOTTOM
    var cx := size.x * 0.5
    if bottom <= TOP:
        return
    draw_texture_rect(RAIL_ART, Rect2(Vector2.ZERO, size), false)
    draw_line(Vector2(cx, TOP), Vector2(cx, bottom), Color("ead1a0", 0.72), 1.5, true)
    for step in range(11):
        var y := lerpf(bottom, TOP, float(step) / 10.0)
        draw_line(Vector2(cx - 5.0, y), Vector2(cx + 5.0, y),
            Color("b7cabe", 0.36), 1.0, true)
    for actor in _actors:
        var id := int(actor.get("id", -1))
        if not _marker_y.has(id):
            continue
        var y := float(_marker_y[id])
        var enemy := int(actor.get("team_id", 0)) != 0
        var tint := ENEMY if enemy else ALLY
        if id == _priority_id:
            tint = GOLD
        # A subtle vertical travel cue sits behind the moving portrait.
        # There are no horizontal connectors or anti-overlap offsets.
        var target := float(_target_y.get(id, y))
        if absf(target - y) > 1.0:
            draw_line(Vector2(cx, y), Vector2(cx, target),
                Color(tint, 0.25), 2.0, true)
        draw_circle(Vector2(cx, y), PORTRAIT * 0.5 + 2.0,
            Color(tint, 0.17))
