extends Control
## Read-only CTB gauge track. The BattleModel/TurnManager owns all charge
## advancement; this control only projects published gauge values to pixels.
const ArtCatalog = preload("res://scripts/hd2d_art_catalog.gd")
const CHARGE := 10000.0
const TOP := 49.0
const BOTTOM := 42.0
const PORTRAIT := 36.0
const ALLY := Color("83d6bc")
const ENEMY := Color("d28c80")
const GOLD := Color("e8c989")
const RAIL_ART: Texture2D = preload("res://assets/ui/ornaments/ctb_rail.svg")
const MARKER_FRAME: Texture2D = preload("res://assets/ui/ornaments/ctb_marker_frame.svg")

var _actors: Array = []
var _priority_id := -1
var _markers: Dictionary = {}
var _marker_y: Dictionary = {}
var _round_avatar_material: ShaderMaterial

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Cropped avatar texture, with the original CTB actor image preserved.
    var round_shader := Shader.new()
    round_shader.code = "shader_type canvas_item;\nvoid fragment() {\n    vec2 d = UV - vec2(0.5);\n    if (dot(d, d) > 0.210) discard;\n    COLOR = texture(TEXTURE, UV);\n}\n"
    _round_avatar_material = ShaderMaterial.new()
    _round_avatar_material.shader = round_shader
    resized.connect(_layout_markers)
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

func _layout_markers() -> void:
    if size.y <= TOP + BOTTOM:
        return
    _marker_y.clear()
    for side in range(2):
        var entries: Array = []
        for actor in _actors:
            var enemy := int(actor.get("team_id", 0)) != 0
            if enemy != (side == 1) or float(actor.get("hp", 0.0)) <= 0.0:
                continue
            entries.append({
                "id": int(actor.get("id", -1)),
                "actual": gauge_y(float(actor.get("gauge", 0.0)))
            })
        entries.sort_custom(func(a, b): return float(a["actual"]) < float(b["actual"]))
        # Separate portraits that share a charge value. The small dots on
        # the centre line remain at their exact, unmodified gauge positions.
        var shifted: Array = []
        var previous := -100000.0
        for entry in entries:
            var y := maxf(float(entry["actual"]), previous + 39.0)
            shifted.append(y)
            previous = y
        if not shifted.is_empty() and float(shifted[-1]) > size.y - BOTTOM:
            var excess := float(shifted[-1]) - (size.y - BOTTOM)
            for i in range(shifted.size()):
                shifted[i] = float(shifted[i]) - excess
        for i in range(entries.size()):
            var id: int = entries[i]["id"]
            if not _markers.has(id):
                continue
            var placed := float(shifted[i])
            _marker_y[id] = placed
            var frame: Panel = _markers[id]
            frame.position = Vector2(7.0 if side == 0 else size.x - PORTRAIT - 7.0,
                placed - PORTRAIT * 0.5)
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
        var y := gauge_y(float(actor.get("gauge", 0.0)))
        var enemy := int(actor.get("team_id", 0)) != 0
        var tint := ENEMY if enemy else ALLY
        if id == _priority_id:
            tint = GOLD
        var end_x := size.x - PORTRAIT - 7.0 if enemy else 7.0 + PORTRAIT
        draw_line(Vector2(cx, y), Vector2(end_x, float(_marker_y[id])),
            Color(tint, 0.55), 1.0, true)
        draw_circle(Vector2(cx, y), 4.2 if id == _priority_id else 3.0, tint)
