extends RefCounted
## Painterly wuxia card presentation. No game rules live here.
## Eight distinct illustrations are stored in one 4x2 PNG atlas.
const WuxiaTheme = preload("res://scripts/hd2d_ui_theme.gd")
const OptionalPaintings = preload("res://scripts/hd2d_card_art.gd")
const ATLAS: Texture2D = preload("res://assets/ui/technique_art_atlas_v1.png")
const FRAME: Texture2D = preload("res://assets/ui/jade_card_filagree.svg")
const SEAL: Texture2D = preload("res://assets/ui/jade_seal.svg")
const ATLAS_COLUMNS := 4
const ATLAS_ROWS := 2
const CARD_SIZE := Vector2(148, 186)
const ART_SIZE := Vector2(132, 108)

static func _image_index(definition_id: String, title: String) -> int:
    var key := definition_id.to_lower()
    if key.contains("probe") or title.contains("探锋"):
        return 0
    if key.contains("sunder") or title.contains("断岳"):
        return 1
    if key.contains("step") or title.contains("游身") or title.contains("踏雪"):
        return 2
    if key.contains("guard") or title.contains("化劲"):
        return 3
    if key.contains("change") or title.contains("变锋"):
        return 4
    if key.contains("flow") or title.contains("连携"):
        return 5
    if key.contains("breath") or title.contains("调息"):
        return 6
    if key.contains("final") or title.contains("截势"):
        return 7
    return posmod((definition_id + title).hash(), ATLAS_COLUMNS * ATLAS_ROWS)

static func illustration(definition_id: String, title: String) -> Texture2D:
    # Prefer optional high-resolution painted assets from PR #32; preserve the
    # existing atlas when a painting is not shipped with the game.
    var optional := OptionalPaintings.for_card({"definition_id": definition_id, "name": title})
    if optional != null and optional.resource_path.ends_with(".png"):
        return optional
    var index := _image_index(definition_id, title)
    var region_width := float(ATLAS.get_width()) / float(ATLAS_COLUMNS)
    var region_height := float(ATLAS.get_height()) / float(ATLAS_ROWS)
    var atlas_texture := AtlasTexture.new()
    atlas_texture.atlas = ATLAS
    atlas_texture.region = Rect2(
        float(index % ATLAS_COLUMNS) * region_width,
        float(index / ATLAS_COLUMNS) * region_height,
        region_width, region_height)
    return atlas_texture

static func _text(parent: Control, value: String, top: float, font_size: int, color: Color, weight: bool = false) -> Label:
    var label := Label.new()
    label.text = value
    label.position = Vector2(11, top)
    label.size = Vector2(124, 23)
    label.clip_text = true
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    if weight:
        label.add_theme_constant_override("outline_size", 2)
        label.add_theme_color_override("font_outline_color", Color("0e1e1b"))
    parent.add_child(label)
    return label

static func make_card(uid: String, definition_id: String, title: String,
        usage: String, cost: Dictionary, selected: bool = false) -> Button:
    var button := Button.new()
    button.name = "WuxiaCard_" + str(uid.hash())
    # The plain-text label is intentionally retained for focus, testing, and accessibility.
    # Visual labels are composited as children; they ignore mouse input.
    button.text = "%s · %s\n气 %.1f  ·  血 %.1f" % [
        title, usage, float(cost.get("qi", 0.0)), float(cost.get("hp", 0.0))]
    button.tooltip_text = "%s\n%s\n消耗：气 %.1f  ·  血 %.1f" % [
        title, usage, float(cost.get("qi", 0.0)), float(cost.get("hp", 0.0))]
    button.set_meta("card_uid", uid)
    button.set_meta("card_definition_id", definition_id)
    WuxiaTheme.apply_card(button, selected)
    button.custom_minimum_size = CARD_SIZE
    button.clip_contents = true
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

    var painting := TextureRect.new()
    painting.texture = illustration(definition_id, title)
    painting.position = Vector2(8, 9)
    painting.size = ART_SIZE
    painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    painting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    painting.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(painting)

    var art_shadow := ColorRect.new()
    art_shadow.color = Color(0.05, 0.12, 0.12, 0.55)
    art_shadow.position = Vector2(8, 99)
    art_shadow.size = Vector2(132, 18)
    art_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(art_shadow)

    _text(button, title, 121, 15, WuxiaTheme.PAPER, true)
    _text(button, usage, 142, 12, WuxiaTheme.JADE)
    var qi_cost := float(cost.get("qi", 0.0))
    var hp_cost := float(cost.get("hp", 0.0))
    _text(button, "◈ 气 %.1f · 血 %.1f" % [qi_cost, hp_cost], 164, 11,
        WuxiaTheme.RED if hp_cost > 0.0 else WuxiaTheme.GOLD)

    var filagree := TextureRect.new()
    filagree.texture = FRAME
    filagree.position = Vector2.ZERO
    filagree.size = CARD_SIZE
    filagree.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    filagree.stretch_mode = TextureRect.STRETCH_SCALE
    filagree.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(filagree)

    var stamp := TextureRect.new()
    stamp.texture = SEAL
    stamp.position = Vector2(119, 7)
    stamp.size = Vector2(22, 22)
    stamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    stamp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(stamp)
    return button
