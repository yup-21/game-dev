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
const DIM = Color("53665e")
const PANEL_ART: Texture2D = preload("res://assets/ui/jade_panel_frame.svg")

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
    # Nine-slice original filigree: corner details remain sharp at every panel size.
    var frame := StyleBoxTexture.new()
    frame.texture = PANEL_ART
    frame.texture_margin_left = 24.0
    frame.texture_margin_right = 24.0
    frame.texture_margin_top = 24.0
    frame.texture_margin_bottom = 24.0
    frame.content_margin_left = 16.0
    frame.content_margin_right = 16.0
    frame.content_margin_top = 12.0
    frame.content_margin_bottom = 12.0
    container.add_theme_stylebox_override("panel", frame)

static func apply_meter(meter: ProgressBar, fill_color: Color) -> void:
    meter.show_percentage = false
    meter.custom_minimum_size = Vector2(0, 7)
    var background := StyleBoxFlat.new()
    background.bg_color = Color("102522")
    background.set_corner_radius_all(3)
    var fill := StyleBoxFlat.new()
    fill.bg_color = fill_color
    fill.set_corner_radius_all(3)
    meter.add_theme_stylebox_override("background", background)
    meter.add_theme_stylebox_override("fill", fill)


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
    var box := StyleBoxFlat.new()
    box.bg_color = Color("18342f") if hover else Color("102a27")
    box.border_color = Color("f2d99c") if selected else (GOLD if hover else Color("648477"))
    box.set_border_width_all(3 if selected else 2)
    box.set_corner_radius_all(12)
    box.shadow_color = Color(0.02, 0.05, 0.05, 0.72)
    box.shadow_size = 12 if selected else 7
    box.shadow_offset = Vector2(0, 5)
    return box

static func apply_card(button: Button, selected: bool = false) -> void:
    button.custom_minimum_size = Vector2(176, 184)
    button.add_theme_stylebox_override("normal", card_style(selected))
    button.add_theme_stylebox_override("hover", card_style(selected, true))
    button.add_theme_stylebox_override("pressed", card_style(true, true))
    button.add_theme_stylebox_override("focus", card_style(true, true))
    # The underlying Button retains a readable .text for the input/automation
    # contract; its visual text is supplied by child Labels in hd2d_card_ui.
    for state in ["font_color", "font_hover_color", "font_pressed_color",
                  "font_focus_color", "font_disabled_color"]:
        button.add_theme_color_override(state, Color.TRANSPARENT)
