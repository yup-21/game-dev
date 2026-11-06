extends RefCounted
## Static HUD layout lives in scenes/ui/battle_hud.tscn. Only party entries,
## cards and legal commands are created from the current battle snapshot.
const HUDScene = preload("res://scenes/ui/battle_hud.tscn")
const Hand = preload("res://scripts/battle_hand_view.gd")
const Status = preload("res://scripts/battle_hud_status.gd")
const UITheme = preload("res://scripts/hd2d_ui_theme.gd")
const ArtCatalog = preload("res://scripts/hd2d_art_catalog.gd")
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

func build(host: Node2D, story_encounter: bool, snapshot: Dictionary) -> Dictionary:
    # Main battle already has this scene as an editable child. Other harnesses
    # can instantiate exactly the same PackedScene instead of rebuilding UI.
    var canvas: CanvasLayer = host.get_node_or_null("WuxiaCombatHUD") as CanvasLayer
    if canvas == null:
        canvas = HUDScene.instantiate()
        host.add_child(canvas)
    var hud: Control = canvas.get_node("UnifiedHUD")
    var ribbon: Control = hud.get_node("ChapterRibbon")
    var heading: Label = ribbon.get_node("Heading")
    heading.text = "雨夜追兵" if story_encounter else "断桥听风"
    var status_label: Label = ribbon.get_node("Status")
    var phase_label: Label = ribbon.get_node("Phase")
    var help_label: Label = ribbon.get_node("Help")
    var auto_button: Button = ribbon.get_node("AutoBattleToggle")
    var spatial_mode_button: Button = ribbon.get_node("BattleSpatialModeToggle")
    UITheme.apply_button(auto_button)
    UITheme.apply_button(spatial_mode_button)
    if not auto_button.pressed.is_connected(Callable(host, "_toggle_auto_battle")):
        auto_button.pressed.connect(Callable(host, "_toggle_auto_battle"))
    if not spatial_mode_button.pressed.is_connected(Callable(host, "_toggle_spatial_mode")):
        spatial_mode_button.pressed.connect(Callable(host, "_toggle_spatial_mode"))

    var roster_list: VBoxContainer = hud.get_node("FloatingRoster/RosterScroll/ActorList")
    for previous in roster_list.get_children():
        previous.queue_free()
    var roster_labels: Dictionary = {}
    var roster_bars: Dictionary = {}
    for actor in snapshot.get("actors", []):
        var actor_id: int = int(actor.id)
        var enemy: bool = int(actor.get("team_id", 0)) != 0
        var actor_row := HBoxContainer.new()
        actor_row.name = "Status_%d" % actor_id
        actor_row.custom_minimum_size = Vector2(0, 65)
        actor_row.add_theme_constant_override("separation", 7)
        actor_row.visible = not enemy
        roster_list.add_child(actor_row)
        var avatar_slot := Control.new()
        avatar_slot.custom_minimum_size = Vector2(58, 65)
        actor_row.add_child(avatar_slot)
        var avatar := TextureRect.new()
        avatar.texture = ArtCatalog.avatar_for_character(str(actor.get("character_id", "")), enemy) \
            if not str(actor.get("character_id", "")).is_empty() else ArtCatalog.avatar(actor_id, enemy)
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
        var portrait_border := TextureRect.new()
        portrait_border.name = "PortraitFrame"
        portrait_border.texture = preload("res://assets/imported/ui/ornaments/portrait_frame.svg")
        portrait_border.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait_border.stretch_mode = TextureRect.STRETCH_SCALE
        portrait_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
        avatar_slot.add_child(portrait_border)
        portrait_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
        var posture_bar := ProgressBar.new()
        posture_bar.name = "PostureMeter"
        UITheme.apply_meter(posture_bar, UITheme.GOLD)
        detail.add_child(posture_bar)
        roster_bars[actor_id] = {"hp": hp, "qi": qi, "posture": posture_bar}

    var context: Control = hud.get_node("ContextActions")
    var clash_label: Label = context.get_node("ClashDetails")
    var command_scroll: ScrollContainer = context.get_node("ContextScroll")
    var command_actions: VBoxContainer = command_scroll.get_node("CommandActions")
    var context_veil: TextureRect = context.get_node("RightVeil")
    var stage: Control = hud.get_node("HandStage")
    var selection_label: Label = stage.get_node("HandInstruction")
    var card_actions: HBoxContainer = stage.get_node("HandScroll/CardActions")
    if not card_actions.sort_children.is_connected(Callable(host, "_request_fan_layout")):
        card_actions.sort_children.connect(Callable(host, "_request_fan_layout"))
    var charge_rail: Control = hud.get_node("ChargeRail")
    var character_card: Control = hud.get_node("CharacterCardOverlay")
    if not character_card.switch_requested.is_connected(Callable(host, "_on_character_school_switch")):
        character_card.switch_requested.connect(Callable(host, "_on_character_school_switch"))
    var intro_title: Label = hud.get_node("IntroTitle")
    intro_title.text = "雨 夜 追 兵" if story_encounter else "断 桥 听 风"
    return {
        "status_label": status_label, "help_label": help_label,
        "clash_label": clash_label, "phase_label": phase_label,
        "auto_button": auto_button, "spatial_mode_button": spatial_mode_button,
        "roster_labels": roster_labels, "roster_bars": roster_bars,
        "command_scroll": command_scroll, "command_actions": command_actions,
        "context_veil": context_veil, "card_actions": card_actions,
        "charge_rail": charge_rail, "character_card": character_card,
        "selection_label": selection_label, "intro_title": intro_title,
        "intro_subtitle": hud.get_node("IntroSubtitle")
    }
