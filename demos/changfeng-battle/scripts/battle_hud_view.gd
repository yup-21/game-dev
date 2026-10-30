extends RefCounted
## R8: owns UI projections and child-control binding, not combat decisions.
## A later art pass can replace the bound controls without changing the model.
const Hand = preload("res://scripts/battle_hand_view.gd")
const Status = preload("res://scripts/battle_hud_status.gd")
const UITheme = preload("res://scripts/hd2d_ui_theme.gd")
const ArtCatalog = preload("res://scripts/hd2d_art_catalog.gd")
const ChargeRail = preload("res://scripts/hd2d_ctb_rail.gd")
const CharacterCardUI = preload("res://scripts/character_card_ui.gd")
var controls: Dictionary = {}

func bind_controls(bound_controls: Dictionary) -> void:
    controls = bound_controls

func show_status(snapshot: Dictionary, owner_id: int, priority: Variant,
        story_encounter: bool, auto_battle: bool, spatial_mode: String,
        has_free_space: bool, player_decision: bool, ticket: int) -> void:
    Status.render(snapshot, owner_id, priority, story_encounter, auto_battle,
        spatial_mode, has_free_space, player_decision, ticket, controls)

func show_hand(hand: Array, available: bool, pass_only: bool,
        find_actions: Callable, can_approach: Callable, can_free_step: Callable,
        add_card: Callable) -> Dictionary:
    return Hand.render_physical_hand(hand, available, pass_only,
        find_actions, can_approach, can_free_step, add_card)

func layout_hand(container: HBoxContainer, selected: Callable) -> void:
    Hand.layout_fan(container, selected)

func _veil(parent: Control, texture: Texture2D) -> TextureRect:
    # Decorative texture is deliberately non-interactive: the battlefield
    # must still receive all clicks outside the actual card/command controls.
    var image := TextureRect.new()
    image.texture = texture
    image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    image.stretch_mode = TextureRect.STRETCH_SCALE
    image.mouse_filter = Control.MOUSE_FILTER_IGNORE
    image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    parent.add_child(image)
    return image

func build(host: Node2D, story_encounter: bool, snapshot: Dictionary) -> Dictionary:
    var status_label: Label
    var help_label: Label
    var clash_label: Label
    var phase_label: Label
    var auto_button: Button
    var spatial_mode_button: Button
    var roster_labels: Dictionary = {}
    var roster_bars: Dictionary = {}
    var command_scroll: ScrollContainer
    var command_actions: VBoxContainer
    var context_veil: TextureRect
    var card_actions: HBoxContainer
    var charge_rail: Control
    var character_card: Control
    var selection_label: Label
    var intro_title: Label
    var intro_subtitle: Label
    var canvas := CanvasLayer.new()
    canvas.name = "WuxiaCombatHUD"
    host.add_child(canvas)
    var hud := Control.new()
    hud.name = "UnifiedHUD"
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(hud)

    # A small title and muted state caption leave the camera fully visible.
    var ribbon := Control.new()
    ribbon.name = "ChapterRibbon"
    ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(ribbon)
    ribbon.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    ribbon.offset_bottom = 61.0
    _veil(ribbon, preload("res://assets/ui/veil_top.svg"))
    # Standalone filigree keeps the central chapter label readable.
    var title_filagree := _veil(ribbon,
        preload("res://assets/ui/ornaments/chapter_filagree.svg"))
    title_filagree.anchor_left = 0.5
    title_filagree.anchor_right = 0.5
    title_filagree.anchor_top = 0.0
    title_filagree.anchor_bottom = 0.0
    title_filagree.offset_left = -300.0
    title_filagree.offset_right = 300.0
    title_filagree.offset_top = 0.0
    title_filagree.offset_bottom = 54.0
    var heading := Label.new()
    heading.text = "雨夜追兵" if story_encounter else "断桥听风"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 23)
    heading.add_theme_color_override("font_color", UITheme.PAPER)
    heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ribbon.add_child(heading)
    heading.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    heading.offset_top = 8.0
    heading.offset_bottom = 43.0
    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 11)
    status_label.add_theme_color_override("font_color", UITheme.MUTED)
    status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ribbon.add_child(status_label)
    status_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    status_label.offset_left = 15.0
    status_label.offset_right = 510.0
    status_label.offset_top = 13.0
    status_label.offset_bottom = 47.0
    phase_label = Label.new()
    phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    phase_label.add_theme_font_size_override("font_size", 12)
    phase_label.add_theme_color_override("font_color", UITheme.GOLD)
    phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ribbon.add_child(phase_label)
    phase_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    phase_label.offset_left = -460.0
    phase_label.offset_right = -285.0
    phase_label.offset_top = 15.0
    phase_label.offset_bottom = 42.0
    auto_button = Button.new()
    auto_button.name = "AutoBattleToggle"
    auto_button.text = "自动战斗 · 关"
    auto_button.tooltip_text = "托管我方行动；按 A 随时恢复手动"
    ribbon.add_child(auto_button)
    auto_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    auto_button.offset_left = -138.0
    auto_button.offset_right = -12.0
    auto_button.offset_top = 11.0
    auto_button.offset_bottom = 45.0
    UITheme.apply_button(auto_button)
    auto_button.pressed.connect(Callable(host, "_toggle_auto_battle"))
    spatial_mode_button = Button.new()
    spatial_mode_button.name = "BattleSpatialModeToggle"
    spatial_mode_button.tooltip_text = "网格 / 无网格双模式；按 M 切换（行动阶段生效）"
    ribbon.add_child(spatial_mode_button)
    spatial_mode_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    spatial_mode_button.offset_left = -280.0
    spatial_mode_button.offset_right = -145.0
    spatial_mode_button.offset_top = 11.0
    spatial_mode_button.offset_bottom = 45.0
    UITheme.apply_button(spatial_mode_button)
    spatial_mode_button.pressed.connect(Callable(host, "_toggle_spatial_mode"))
    help_label = Label.new()
    help_label.text = "M 切换网格/无网格 · P 显示路径 · 左键落点或点敌自动接近 · C 角色卡 · Space 收势"
    help_label.visible = false
    ribbon.add_child(help_label)

    # Team status floats directly over the scene: no per-actor rectangular
    # panels, only portraits and fine health/qi strokes.
    var party := Control.new()
    party.name = "FloatingRoster"
    party.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(party)
    party.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    party.offset_left = 0.0
    party.offset_right = 214.0
    party.offset_top = 75.0
    party.offset_bottom = 459.0
    _veil(party, preload("res://assets/ui/veil_left.svg"))
    var roster_heading := Label.new()
    roster_heading.text = "江湖同行"
    roster_heading.position = Vector2(13, 10)
    roster_heading.size = Vector2(180, 23)
    roster_heading.add_theme_font_size_override("font_size", 13)
    roster_heading.add_theme_color_override("font_color", UITheme.GOLD)
    roster_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
    party.add_child(roster_heading)
    var roster_scroll := ScrollContainer.new()
    roster_scroll.name = "RosterScroll"
    roster_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    party.add_child(roster_scroll)
    roster_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    roster_scroll.offset_left = 12.0
    roster_scroll.offset_right = -9.0
    roster_scroll.offset_top = 37.0
    roster_scroll.offset_bottom = -10.0
    roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    var roster_list := VBoxContainer.new()
    roster_list.name = "ActorList"
    roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    roster_list.add_theme_constant_override("separation", 5)
    roster_scroll.add_child(roster_list)
    for actor in snapshot.get("actors", []):
        var actor_id := int(actor.id)
        var enemy := int(actor.get("team_id", 0)) != 0
        var actor_row := HBoxContainer.new()
        actor_row.name = "Status_%d" % actor_id
        actor_row.custom_minimum_size = Vector2(0, 65)
        actor_row.add_theme_constant_override("separation", 7)
        # Enemy progress is on the right CTB rail and over each battle sprite.
        # Keep their read-only controls for existing status consumers.
        actor_row.visible = not enemy
        roster_list.add_child(actor_row)
        var avatar_slot := Control.new()
        avatar_slot.custom_minimum_size = Vector2(58, 65)
        actor_row.add_child(avatar_slot)
        var avatar := TextureRect.new()
        avatar.texture = ArtCatalog.avatar(actor_id, enemy)
        avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        avatar.mouse_filter = Control.MOUSE_FILTER_STOP
        avatar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        avatar.tooltip_text = "查看 %s 的角色卡" % str(actor.name)
        avatar.gui_input.connect(Callable(host, "_on_roster_avatar_input").bind(actor_id))
        avatar_slot.add_child(avatar)
        avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        avatar.offset_left = 5.0
        avatar.offset_top = 5.0
        avatar.offset_right = -5.0
        avatar.offset_bottom = -5.0
        var portrait_border := _veil(avatar_slot,
            preload("res://assets/ui/ornaments/portrait_frame.svg"))
        portrait_border.name = "PortraitFrame"
        var detail := VBoxContainer.new()
        detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        detail.add_theme_constant_override("separation", 3)
        actor_row.add_child(detail)
        var entry := Label.new()
        entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        entry.add_theme_font_size_override("font_size", 12)
        entry.add_theme_color_override("font_color", UITheme.RED if enemy else UITheme.JADE)
        detail.add_child(entry)
        roster_labels[actor_id] = entry
        var hp := ProgressBar.new()
        UITheme.apply_meter(hp, UITheme.RED if enemy else Color("a5cda9"))
        detail.add_child(hp)
        var qi := ProgressBar.new()
        UITheme.apply_meter(qi, UITheme.JADE)
        detail.add_child(qi)
        roster_bars[actor_id] = {"hp": hp, "qi": qi}

    # Contextual commands float beside, never instead of, the CTB rail.
    var context := Control.new()
    context.name = "ContextActions"
    context.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(context)
    context.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    context.offset_left = -336.0
    context.offset_right = -126.0
    context.offset_top = -538.0
    context.offset_bottom = -265.0
    context_veil = _veil(context, preload("res://assets/ui/veil_right.svg"))
    clash_label = Label.new()
    clash_label.name = "ClashDetails"
    clash_label.position = Vector2(11, 10)
    clash_label.size = Vector2(190, 62)
    clash_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    clash_label.add_theme_font_size_override("font_size", 12)
    clash_label.add_theme_color_override("font_color", UITheme.PAPER)
    context.add_child(clash_label)
    command_scroll = ScrollContainer.new()
    command_scroll.name = "ContextScroll"
    context.add_child(command_scroll)
    command_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    command_scroll.offset_left = 11.0
    command_scroll.offset_right = -9.0
    command_scroll.offset_top = 76.0
    command_scroll.offset_bottom = -8.0
    command_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    command_actions = VBoxContainer.new()
    command_actions.name = "CommandActions"
    command_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    command_actions.add_theme_constant_override("separation", 5)
    command_scroll.add_child(command_actions)

    # Ink fades out into the battlefield. Cards themselves are the UI and do
    # not sit inside a second solid, framed tray.
    var hand_stage := Control.new()
    hand_stage.name = "HandStage"
    hand_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(hand_stage)
    hand_stage.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    hand_stage.offset_left = 0.0
    hand_stage.offset_right = 0.0
    hand_stage.offset_top = -255.0
    hand_stage.offset_bottom = 0.0
    _veil(hand_stage, preload("res://assets/ui/ornaments/hand_fan_tray.svg"))
    var hand_title := Label.new()
    hand_title.text = "武 学"
    hand_title.add_theme_font_size_override("font_size", 15)
    hand_title.add_theme_color_override("font_color", UITheme.GOLD)
    hand_stage.add_child(hand_title)
    hand_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    hand_title.offset_left = 28.0
    hand_title.offset_right = 110.0
    hand_title.offset_top = 11.0
    hand_title.offset_bottom = 36.0
    selection_label = Label.new()
    selection_label.name = "HandInstruction"
    selection_label.text = "选一式，点目标；右键取消。"
    selection_label.add_theme_font_size_override("font_size", 11)
    selection_label.add_theme_color_override("font_color", UITheme.MUTED)
    hand_stage.add_child(selection_label)
    selection_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    selection_label.offset_left = 112.0
    selection_label.offset_right = -140.0
    selection_label.offset_top = 13.0
    selection_label.offset_bottom = 40.0
    var hand_scroll := ScrollContainer.new()
    hand_scroll.name = "HandScroll"
    hand_stage.add_child(hand_scroll)
    hand_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hand_scroll.offset_left = 75.0
    hand_scroll.offset_right = -128.0
    hand_scroll.offset_top = 38.0
    hand_scroll.offset_bottom = -10.0
    hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    card_actions = HBoxContainer.new()
    card_actions.name = "CardActions"
    # Center short hands; once cards overflow, normal scroll starts at the left.
    card_actions.alignment = BoxContainer.ALIGNMENT_CENTER
    card_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card_actions.add_theme_constant_override("separation", -12)
    hand_scroll.add_child(card_actions)
    card_actions.sort_children.connect(Callable(host, "_request_fan_layout"))

    # The original CTB is a real vertical charge gauge, not a stack of
    # decorative portraits or a second turn-order model.
    charge_rail = ChargeRail.new()
    charge_rail.name = "ChargeRail"
    hud.add_child(charge_rail)
    charge_rail.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
    charge_rail.offset_left = -116.0
    charge_rail.offset_right = -8.0
    charge_rail.offset_top = 63.0
    charge_rail.offset_bottom = -131.0

    character_card = CharacterCardUI.new()
    hud.add_child(character_card)
    character_card.switch_requested.connect(Callable(host, "_on_character_school_switch"))

    # Chapter reveal is visual only, and cannot swallow user mouse input.
    intro_title = Label.new()
    intro_title.text = "雨 夜 追 兵" if story_encounter else "断 桥 听 风"
    intro_title.add_theme_font_size_override("font_size", 54)
    intro_title.add_theme_color_override("font_color", UITheme.PAPER)
    intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hud.add_child(intro_title)
    intro_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    intro_title.offset_left = -320.0
    intro_title.offset_right = 320.0
    intro_title.offset_top = -160.0
    intro_title.offset_bottom = -84.0
    intro_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    intro_subtitle = Label.new()
    intro_subtitle.text = "一剑试江湖   ·   水墨武学 / 立体战场"
    intro_subtitle.add_theme_font_size_override("font_size", 20)
    intro_subtitle.add_theme_color_override("font_color", UITheme.GOLD)
    intro_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hud.add_child(intro_subtitle)
    intro_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    intro_subtitle.offset_left = -320.0
    intro_subtitle.offset_right = 320.0
    intro_subtitle.offset_top = -90.0
    intro_subtitle.offset_bottom = -45.0
    intro_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE

    return {
        "status_label": status_label,
        "help_label": help_label,
        "clash_label": clash_label,
        "phase_label": phase_label,
        "auto_button": auto_button,
        "spatial_mode_button": spatial_mode_button,
        "roster_labels": roster_labels,
        "roster_bars": roster_bars,
        "command_scroll": command_scroll,
        "command_actions": command_actions,
        "context_veil": context_veil,
        "card_actions": card_actions,
        "charge_rail": charge_rail,
        "character_card": character_card,
        "selection_label": selection_label,
        "intro_title": intro_title,
        "intro_subtitle": intro_subtitle
    }

