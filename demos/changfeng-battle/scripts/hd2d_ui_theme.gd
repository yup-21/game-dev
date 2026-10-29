extends RefCounted
## Original jade-and-ink combat UI palette for HD-2D wuxia battle.
const INK = Color("142823")
const PANEL = Color("1b3530", 0.94)
const PANEL_LIGHT = Color("27483f", 0.96)
const JADE = Color("67bc9e")
const GOLD = Color("d0af75")
const PAPER = Color("efe7d1")
const MUTED = Color("b8c6b8")
const RED = Color("d78a79")

static func panel(background: Color = PANEL, outline: Color = GOLD) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = background
    box.border_color = outline
    box.set_border_width_all(1)
    box.set_corner_radius_all(5)
    box.content_margin_left = 14.0
    box.content_margin_top = 10.0
    box.content_margin_right = 14.0
    box.content_margin_bottom = 10.0
    box.shadow_color = Color(0.02, 0.07, 0.06, 0.44)
    box.shadow_size = 6
    return box

static func apply_panel(container: PanelContainer) -> void:
    container.add_theme_stylebox_override("panel", panel())

static func apply_button(button: Button) -> void:
    button.add_theme_stylebox_override("normal", panel(PANEL_LIGHT, Color("587568")))
    button.add_theme_stylebox_override("hover", panel(Color("385e50"), GOLD))
    button.add_theme_stylebox_override("pressed", panel(Color("446e59"), GOLD))
    button.add_theme_stylebox_override("disabled", panel(Color("253d35"), Color("43584e")))
    button.add_theme_color_override("font_color", PAPER)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_disabled_color", MUTED)
    button.add_theme_font_size_override("font_size", 15)
    button.custom_minimum_size = Vector2(155, 43)
