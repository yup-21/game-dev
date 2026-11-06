extends RefCounted
## Painterly wuxia card presentation. No game rules live here.
## Eight distinct illustrations are stored in one 4x2 PNG atlas.
const WuxiaTheme = preload("res://scripts/hd2d_ui_theme.gd")
const CardScene = preload("res://scenes/ui/battle_card.tscn")
const OptionalPaintings = preload("res://scripts/hd2d_card_art.gd")
const ATLAS: Texture2D = preload("res://assets/imported/ui/card-art/atlas.png")
const ATLAS_COLUMNS := 4
const ATLAS_ROWS := 2

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

static func make_card(uid: String, definition_id: String, title: String,
        usage: String, cost: Dictionary, selected: bool = false) -> Button:
    var button: Button = CardScene.instantiate()
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
    button.get_node("Painting").texture = illustration(definition_id, title)
    button.get_node("Title").text = title
    button.get_node("Usage").text = usage
    var qi_cost := float(cost.get("qi", 0.0))
    var hp_cost := float(cost.get("hp", 0.0))
    var cost_label: Label = button.get_node("Cost")
    cost_label.text = "◈ 气 %.1f · 血 %.1f" % [qi_cost, hp_cost]
    cost_label.add_theme_color_override("font_color",
        WuxiaTheme.RED if hp_cost > 0.0 else WuxiaTheme.GOLD)
    return button
