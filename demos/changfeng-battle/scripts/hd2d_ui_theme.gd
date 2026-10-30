extends RefCounted
## Single Wuxia combat theme. Text, cards, meters and contextual controls
## share one ink/jade/gold system; the HUD does not create framed panels.
const INK = Color("0c1d22")
const PANEL = Color("132c2e", 0.46)
const PANEL_LIGHT = Color("24473f", 0.62)
const JADE = Color("87d0b8")
const GOLD = Color("dfc28a")
const PAPER = Color("f2ecda")
const MUTED = Color("b9cec2")
const RED = Color("db998b")
const DIM = Color("4c655e")

static func panel(background: Color = PANEL, outline: Color = Color.TRANSPARENT) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = outline
    style.set_corner_radius_all(10)
    style.content_margin_left = 12.0
    style.content_margin_right = 12.0
    style.content_margin_top = 8.0
    style.content_margin_bottom = 8.0
    return style

static func apply_panel(container: PanelContainer) -> void:
    # Compatibility with other scenes; the new combat HUD uses veils instead.
    container.add_theme_stylebox_override("panel", panel())

static func apply_meter(meter: ProgressBar, fill_color: Color) -> void:
    meter.show_percentage = false
    meter.custom_minimum_size = Vector2(0, 4)
    meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var background := StyleBoxFlat.new()
    background.bg_color = Color(0.05, 0.16, 0.18, 0.66)
    background.set_corner_radius_all(2)
    var fill := StyleBoxFlat.new()
    fill.bg_color = fill_color
    fill.set_corner_radius_all(2)
    meter.add_theme_stylebox_override("background", background)
    meter.add_theme_stylebox_override("fill", fill)

static func command_style(hovered: bool = false) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("345c52", 0.50) if hovered else Color("142e30", 0.09)
    style.border_color = Color("d3b77e", 0.59) if hovered else Color.TRANSPARENT
    style.border_width_bottom = 1 if hovered else 0
    style.set_corner_radius_all(18)
    style.content_margin_left = 14.0
    style.content_margin_right = 14.0
    style.content_margin_top = 7.0
    style.content_margin_bottom = 7.0
    return style

static func apply_button(button: Button) -> void:
    button.custom_minimum_size = Vector2(104, 30)
    button.add_theme_stylebox_override("normal", command_style())
    button.add_theme_stylebox_override("hover", command_style(true))
    button.add_theme_stylebox_override("pressed", command_style(true))
    button.add_theme_stylebox_override("disabled", command_style())
    button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    button.add_theme_color_override("font_color", PAPER)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_disabled_color", DIM)
    button.add_theme_font_size_override("font_size", 12)
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func card_style(selected: bool = false, hover: bool = false) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = Color("203c38", 0.90) if hover or selected else Color("102b2c", 0.92)
    box.border_color = Color("f4d99e", 0.94) if selected else (Color("d8c187", 0.85) if hover else Color("81988b", 0.42))
    box.set_border_width_all(2 if selected else 1)
    box.set_corner_radius_all(7)
    box.shadow_color = Color(0.015, 0.04, 0.05, 0.77)
    box.shadow_size = 15 if selected else 8
    box.shadow_offset = Vector2(0, 6)
    return box

static func apply_card(button: Button, selected: bool = false) -> void:
    button.custom_minimum_size = Vector2(148, 186)
    button.add_theme_stylebox_override("normal", card_style(selected))
    button.add_theme_stylebox_override("hover", card_style(selected, true))
    button.add_theme_stylebox_override("pressed", card_style(true, true))
    button.add_theme_stylebox_override("focus", card_style(true, true))
    for state in ["font_color", "font_hover_color", "font_pressed_color",
                  "font_focus_color", "font_disabled_color"]:
        button.add_theme_color_override(state, Color.TRANSPARENT)
