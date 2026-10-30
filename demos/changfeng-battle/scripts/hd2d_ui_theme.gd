extends RefCounted
## Original illustrated jade-and-ink HUD: reusable, resolution-independent styles.
const INK = Color("101e24")
const PANEL = Color("142c2d", 0.95)
const PANEL_LIGHT = Color("24433d", 0.97)
const JADE = Color("8ed7bd")
const GOLD = Color("d7b679")
const PAPER = Color("f4ead5")
const MUTED = Color("aebfb6")
const RED = Color("e3a18d")
const BLUE = Color("87b8c6")
const DIM = Color("53665e")

static func panel(background: Color = PANEL, outline: Color = GOLD) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = outline
    style.set_border_width_all(1)
    style.border_width_top = 2
    style.set_corner_radius_all(9)
    style.corner_detail = 8
    style.content_margin_left = 15.0
    style.content_margin_right = 15.0
    style.content_margin_top = 12.0
    style.content_margin_bottom = 11.0
    style.shadow_color = Color(0.015, 0.04, 0.05, 0.69)
    style.shadow_size = 12
    style.shadow_offset = Vector2(0, 5)
    return style

static func apply_panel(container: PanelContainer) -> void:
    container.add_theme_stylebox_override("panel", panel())

static func apply_button(button: Button) -> void:
    button.add_theme_stylebox_override("normal", panel(PANEL_LIGHT, Color("5c7b6d")))
    button.add_theme_stylebox_override("hover", panel(Color("34594c"), GOLD))
    button.add_theme_stylebox_override("pressed", panel(Color("476d58"), GOLD))
    button.add_theme_stylebox_override("disabled", panel(Color("263531"), DIM))
    button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    button.add_theme_color_override("font_color", PAPER)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_disabled_color", MUTED)
    button.add_theme_font_size_override("font_size", 14)
    button.custom_minimum_size = Vector2(146, 44)

static func card_style(selected: bool = false, hover: bool = false) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("345d52") if selected else (Color("294d48") if hover else Color("182e32"))
    style.border_color = Color("f6dc9a") if selected else (GOLD if hover else Color("537c75"))
    style.set_border_width_all(3 if selected else 2)
    style.border_width_bottom = 5 if selected else 3
    style.set_corner_radius_all(11)
    style.corner_detail = 8
    style.content_margin_left = 8
    style.content_margin_top = 8
    style.content_margin_right = 9
    style.content_margin_bottom = 8
    style.shadow_color = Color(0.01, 0.025, 0.035, 0.83)
    style.shadow_size = 16 if selected else 9
    style.shadow_offset = Vector2(0, 7 if selected else 4)
    return style

static func apply_card(button: Button, selected: bool = false) -> void:
    button.custom_minimum_size = Vector2(255, 161)
    button.add_theme_stylebox_override("normal", card_style(selected))
    button.add_theme_stylebox_override("hover", card_style(selected, true))
    button.add_theme_stylebox_override("pressed", card_style(true, true))
    button.add_theme_stylebox_override("disabled", card_style(false))
    button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    button.add_theme_color_override("font_color", PAPER)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color("fff0c9"))
    button.add_theme_font_size_override("font_size", 13)
    button.add_theme_constant_override("h_separation", 8)
    button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.add_theme_constant_override("icon_max_width", 93)
    button.expand_icon = true
    button.clip_text = true
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func gauge(background: Color, fill: Color) -> Array[StyleBoxFlat]:
    var empty := StyleBoxFlat.new()
    empty.bg_color = background
    empty.set_corner_radius_all(3)
    var active := StyleBoxFlat.new()
    active.bg_color = fill
    active.set_corner_radius_all(3)
    return [empty, active]

static func apply_gauge(bar: ProgressBar, fill: Color) -> void:
    var styles := gauge(Color("09191c"), fill)
    bar.add_theme_stylebox_override("background", styles[0])
    bar.add_theme_stylebox_override("fill", styles[1])
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(30, 6)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
