extends Node2D
## HD-2D vertical slice. All tactical state and legality remain in BattleModel.
## Canonical player battle uses only painted 2D terrain and Sprite2D actors.
const Model = preload("res://scripts/battle_model.gd")
const BattleCommandController = preload("res://scripts/battle_command_controller.gd")
const BattleInputController = preload("res://scripts/battle_input_controller.gd")
const ContinuousSpace = preload("res://scripts/battle_spatial_service.gd")
const ContinuousPreview = preload("res://scripts/continuous_move_preview.gd")
const EnemyAI = preload("res://scripts/enemy_ai.gd")
const IllustratedMap = preload("res://scripts/illustrated_battle_map.gd")
const UITheme = preload("res://scripts/hd2d_ui_theme.gd")
const CardUI = preload("res://scripts/hd2d_card_ui.gd")
const ArtCatalog = preload("res://scripts/hd2d_art_catalog.gd")
const Animator = preload("res://scripts/hd2d_animation.gd")
const Facing = preload("res://scripts/actor_facing.gd")
const VFX = preload("res://scripts/battle_vfx_2d.gd")
const ResponsePolicy = preload("res://scripts/hd2d_response_policy.gd")
const CharacterRegistry = preload("res://scripts/character_registry.gd")
const CharacterCardUI = preload("res://scripts/character_card_ui.gd")
const ChargeRail = preload("res://scripts/hd2d_ctb_rail.gd")
const BattleHandView = preload("res://scripts/battle_hand_view.gd")
const BattleHUDStatus = preload("res://scripts/battle_hud_status.gd")
const PresentationCoordinator = preload("res://scripts/battle_presentation_coordinator.gd")
var model = Model.new()
var story_encounter := false
var observer_id := 0
var result_reported := false
var ai = EnemyAI.new()
var animation_driver = Animator.new()
var presentation = PresentationCoordinator.new()
var effects_driver
var continuous_space
var continuous_preview
var continuous_preview_enabled := false
var illustrated_map: CanvasLayer
var camera: Camera2D
var actor_nodes: Dictionary = {}
var visual_cells: Dictionary = {}
var movement_paths: Dictionary = {}
var continuous_paths: Dictionary = {}
var snap: Dictionary = {}
var legals: Array = []
var status_label: Label
var help_label: Label
var clash_label: Label
var phase_label: Label
var roster_labels: Dictionary = {}
var roster_bars: Dictionary = {}
var animation_time := 0.0
var animation_ticket := -1
var ai_wait := 0.0
var auto_battle := false
var auto_button: Button
var spatial_mode_button: Button
var hovered := Vector2i(-1, -1)
var card_actions: HBoxContainer
var fan_layout_pending := false
var command_actions: VBoxContainer
var command_scroll: ScrollContainer
var context_veil: TextureRect
var charge_rail: Control
var character_card: Control
var selection_label: Label
var selected_card_uid := ""
var selected_usage_id := ""
var selected_technique := ""
var selected_node := ""
var selected_kind := ""
var last_cue := ""
var camera_shake := 0.0
var elapsed := 0.0
var intro_remaining := 3.25
var intro_title: Label
var intro_subtitle: Label

func _ready() -> void:
    var session = _session()
    story_encounter = session != null and session.phase == "battle"
    if story_encounter:
        model.reset(session.encounter_seed(), -1, "tingfeng", session.encounter_options())
    else:
        model.reset(2026, -1, "tingfeng", _quick_character_options())
    observer_id = _first_player_id()
    snap = model.snapshot(observer_id)
    legals = model.legal_actions(_decision_owner())
    _build_world()
    if illustrated_map != null:
        continuous_space = ContinuousSpace.new()
        continuous_preview = ContinuousPreview.new()
        illustrated_map.scene_root.add_child(continuous_preview)
    # 3D terrain, procedural scenery, and far-away backdrop are removed.
    # Only 2D painted ground and 2D sprite action frames are visible.
    effects_driver = VFX.new(illustrated_map.scene_root)
    _build_ui()
    _refresh()
    _update_status()

func _quick_character_options() -> Dictionary:
    var configured: Dictionary=CharacterRegistry.new().battle_options([], {0:"shen_changfeng",1:"pursuer_captain"})
    configured["map_definition_path"]="res://data/maps/rainy_bridge.json"
    var session=get_node_or_null("/root/GameSession")
    if session != null:
        configured["spatial_mode"]=str(session.get("battle_spatial_mode"))
    return configured

func _session():
    return get_node_or_null("/root/GameSession")

func _first_player_id() -> int:
    for actor in model.state.actors:
        if actor.team_id == 0 and actor.controller == "PLAYER":
            return actor.id
    return 0

func _player_decision() -> bool:
    var actor = model.state.get_actor(_decision_owner())
    return actor != null and actor.controller == "PLAYER"

func _report_story_result() -> void:
    if not story_encounter or result_reported or str(snap.get("outcome", "playing")) == "playing":
        return
    var session = _session()
    if session != null and session.phase == "battle":
        session.report_battle(str(snap.get("outcome", "draw")), int(snap.get("winning_team", -1)))
    result_reported = true

func _build_world() -> void:
    camera = Camera2D.new()
    camera.name = "BattleCamera2D"
    camera.position = Vector2.ZERO
    add_child(camera)
    camera.make_current()
    illustrated_map = IllustratedMap.new(story_encounter,
        str(model.state.map_definition_path))
    add_child(illustrated_map)
    for actor in snap.get("actors", []):
        _create_actor(actor)

func _create_actor(actor: Dictionary) -> void:
    if illustrated_map == null:
        return
    var id := int(actor.id)
    if actor_nodes.has(id):
        return
    var sprite: Sprite2D = illustrated_map.add_actor(actor,
        ArtCatalog.sheet_for_actor(id, int(actor.get("team_id", 0)) != 0))
    sprite.set_meta("faces_left_unflipped", ArtCatalog.sheet_faces_left(id))
    actor_nodes[id] = illustrated_map.actors[id]
    visual_cells[id] = Vector2i(actor.cell)
    animation_driver.register_actor(id, sprite,
        Vector2i(actor.get("facing", Vector2i.RIGHT)))

func _refresh_target_markers() -> void:
    if illustrated_map == null:
        return
    var target_cells: Dictionary = {}
    var actions: Array = _selected_actions() if not selected_kind.is_empty() else legals
    for action in actions:
        if selected_kind.is_empty() and str(action.get("kind", "")) != "MOVE":
            continue
        if action.has("target_cell") and not (selected_kind == "PLAY_CARD"
                and _can_free_movement_card(selected_card_uid, selected_usage_id)):
            target_cells[action.target_cell] = true
        if action.has("target_id"):
            for actor in snap.get("actors", []):
                if int(actor.id) == int(action.target_id):
                    target_cells[actor.cell] = true
    if not selected_kind.is_empty() and (
            (selected_kind == "PLAY_CARD"
                and _can_approach_card(selected_card_uid, selected_usage_id))
            or (selected_kind == "USE_ABILITY"
                and _can_approach_technique(selected_technique, selected_node))):
        for target in model.state.actors:
            if target.hp_u > 0 and model.state.is_hostile(_decision_owner(), target.id):
                target_cells[target.cell] = true
    illustrated_map.set_highlights(target_cells,
        animation_ticket < 0 and _player_decision() and not auto_battle)

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

func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "WuxiaCombatHUD"
    add_child(canvas)
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
    auto_button.pressed.connect(_toggle_auto_battle)
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
    spatial_mode_button.pressed.connect(_toggle_spatial_mode)
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
    for actor in snap.get("actors", []):
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
        avatar.gui_input.connect(_on_roster_avatar_input.bind(actor_id))
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
    card_actions.sort_children.connect(_request_fan_layout)

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
    character_card.switch_requested.connect(_on_character_school_switch)

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

func _request_fan_layout() -> void:
    # Container positioning is authoritative. Rotation and slight vertical
    # offsets only change presentation, not card order or scroll coordinates.
    if fan_layout_pending:
        return
    fan_layout_pending = true
    call_deferred("_layout_fan_cards")

func _layout_fan_cards() -> void:
    fan_layout_pending = false
    BattleHandView.layout_fan(card_actions, Callable(self, "_is_selected_card"))

func _on_roster_avatar_input(event: InputEvent, id: int) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _open_character_card(id)

func _toggle_spatial_mode() -> void:
    if illustrated_map == null or model.state.spatial == null or auto_battle or animation_ticket >= 0 or not _player_decision():
        return
    var target_mode: String = "FREE" if model.state.spatial_mode == "GRID" else "GRID"
    _submit("SET_SPATIAL_MODE", {"spatial_mode": target_mode})

func _toggle_auto_battle() -> void:
    _set_auto_battle(not auto_battle)

func _set_auto_battle(enabled: bool) -> void:
    if auto_battle == enabled:
        return
    auto_battle = enabled
    ai_wait = 0.0
    _clear_selection()
    if enabled and character_card != null and character_card.visible:
        character_card.call("close_card")
    _rebuild_actions()
    _refresh_target_markers()
    _update_status()

func _open_character_card(id: int) -> void:
    if character_card != null:
        character_card.call("open_actor",model,id)

func _on_character_school_switch(id: int, school_id: String) -> void:
    if character_card == null or not character_card.visible:
        return
    if id != _decision_owner() or not _player_decision():
        return
    character_card.call("close_card")
    _submit("SWITCH_SCHOOL",{"school_id":school_id})

func _refresh() -> void:
    # Read priority from the NEW state before choosing hand visibility.
    snap = model.snapshot(observer_id)
    var owner := _decision_owner()
    var owner_actor = model.state.get_actor(owner)
    if owner_actor != null and owner_actor.controller == "PLAYER":
        observer_id = owner
    snap = model.snapshot(observer_id)
    legals = model.legal_actions(owner) if _player_decision() else []
    _report_story_result()
    for actor in snap.get("actors", []):
        var id := int(actor.id)
        if not actor_nodes.has(id):
            _create_actor(actor)
    _rebuild_actions()
    _refresh_target_markers()

func _decision_owner() -> int:
    if snap.get("phase", "") == "CLASH":
        return int(snap.get("clash", {}).get("priority_actor_id", -1))
    return int(snap.get("active_id", -1))

func _find_actions(uid: String, usage: String) -> Array:
    var choices: Array = []
    for action in legals:
        if str(action.get("kind", "")) == "PLAY_CARD" and str(action.get("card_uid", action.get("card_id", ""))) == uid and str(action.get("usage_id", "")) == usage:
            choices.append(action)
    return choices

## A card can be chosen before entering range; the authoritative composite
## validator determines whether a particular enemy is actually reachable.
func _has_attack_damage(usage: Dictionary) -> bool:
    for effect in usage.get("effects", []):
        if str(effect.get("type", "")) == "deal_damage":
            return true
    return false

func _can_approach_card(uid: String, usage_id: String) -> bool:
    if model.state.spatial == null or model.state.spatial_mode!="FREE" or str(snap.get("phase", "")) != "ACTION":
        return false
    var actor = model.state.get_actor(_decision_owner())
    if actor == null or actor.hp_u <= 0 or not actor.hand.has(uid):
        return false
    var usage: Dictionary = model.cards.usage(uid,usage_id)
    if usage.is_empty() or str(usage.get("timing", "")) != "ACTION" or str(usage.get("target", {}).get("kind", "")) != "enemy_actor" or not _has_attack_damage(usage):
        return false
    if not model.rules.condition_allows(actor,usage):
        return false
    var definition: Dictionary = model.cards.canonical_definition(uid)
    if not model.cards.valid_definition(definition):
        return false
    if bool(usage.get("once_per_action",false)) and int(actor.card_uses.get(str(definition.id)+":"+usage_id,0)) > 0:
        return false
    var attack: Dictionary = {"kind":"PLAY_CARD","actor_id":actor.id,"target_id":-1,"card_uid":uid,"usage_id":usage_id}
    var quote: Dictionary = model.costs.quote(actor,usage.get("cost",{}),model.rules.context(actor.id,attack))
    return model.costs.can_pay(actor,quote)

func _can_approach_technique(technique_id: String, node_id: String) -> bool:
    if model.state.spatial == null or model.state.spatial_mode!="FREE" or str(snap.get("phase", "")) != "ACTION":
        return false
    var actor = model.state.get_actor(_decision_owner())
    if actor == null or actor.hp_u <= 0:
        return false
    for usage in model.techniques.available_nodes(actor,technique_id,"ACTION"):
        if str(usage.get("id", "")) != node_id or str(usage.get("target", {}).get("kind", "")) != "enemy_actor" or not _has_attack_damage(usage):
            continue
        var current: bool=int(actor.technique_states[technique_id].last_used_action)==actor.turns_started
        if not model.conditions.allows(actor,usage.get("when",{}),{"timing":"ACTION","tick":model.state.global_tick,"same_action":current}):
            return false
        var attack: Dictionary={"kind":"USE_ABILITY","actor_id":actor.id,"technique_id":technique_id,"node_id":node_id}
        var quote: Dictionary=model.costs.quote(actor,model.techniques.cost(actor,technique_id,node_id),model.rules.context(actor.id,attack))
        return model.costs.can_pay(actor,quote)
    return false

func _can_free_movement_card(uid: String, usage_id: String) -> bool:
    if model.state.spatial_mode!="FREE" or model.state.spatial==null:
        return false
    var actor=model.state.get_actor(_decision_owner())
    if actor==null or actor.hp_u<=0 or not actor.hand.has(uid):
        return false
    var usage: Dictionary=model.cards.usage(uid,usage_id)
    if usage.is_empty() or str(usage.get("timing",""))!=model.rules.timing(actor.id):
        return false
    if str(usage.get("target",{}).get("kind",""))!="reachable_cell":
        return false
    var available:=false
    for effect in usage.get("effects",[]):
        if str(effect.get("type",""))=="move" and int(effect.get("max_distance",0))>0:
            available=true
    if not available or not model.rules.condition_allows(actor,usage):
        return false
    if model.state.mode=="CLASH" and (int(model.state.clash.counts.get(actor.id,0))>=2 or model.state.clash.stack.size()>=4):
        return false
    var definition: Dictionary=model.cards.canonical_definition(uid)
    if bool(usage.get("once_per_action",false)) and int(actor.card_uses.get(str(definition.get("id",""))+":"+usage_id,0))>0:
        return false
    var quote: Dictionary=model.costs.quote(actor,usage.get("cost",{}),
        model.rules.context(actor.id,{"kind":"PLAY_CARD_FREE_MOVE","card_uid":uid,"usage_id":usage_id}))
    return model.costs.can_pay(actor,quote)

func _enemy_at(cell: Vector2i) -> int:
    var owner: int = _decision_owner()
    for target in model.state.actors:
        if target.cell == cell and target.hp_u > 0 and model.state.is_hostile(owner, target.id):
            return target.id
    return -1

func _submit_selected_approach(target_id: int) -> void:
    if target_id < 0 or selected_kind.is_empty():
        return
    var params: Dictionary={"attack_kind":selected_kind,"target_id":target_id}
    if selected_kind=="PLAY_CARD" and _can_approach_card(selected_card_uid,selected_usage_id):
        params["card_uid"]=selected_card_uid
        params["usage_id"]=selected_usage_id
    elif selected_kind=="USE_ABILITY" and _can_approach_technique(selected_technique,selected_node):
        params["technique_id"]=selected_technique
        params["node_id"]=selected_node
    else:
        return
    _submit("MOVE_AND_ATTACK",params)

func _clear_selection() -> void:
    selected_card_uid = ""
    selected_usage_id = ""
    selected_technique = ""
    selected_node = ""
    selected_kind = ""

func _unavailable_card_hint(card: Dictionary, phase: String) -> String:
    if phase == "CLASH":
        return "交锋中暂无合法应变；仍然保留已抽到的手牌。"
    if phase != "ACTION":
        return "等待当前角色行动；手牌不会被丢弃。"
    for usage in card.get("usages", []):
        if str(usage.get("timing", "")) == "ACTION" and str(usage.get("target", {}).get("kind", "")) == "enemy_actor":
            return "已抽到攻击招式。当前没有合法攻击目标；靠近敌人并检查内息和攻击条件。"
    return "已抽到此招，当前不满足使用时机、费用或目标条件。"

func _add_visible_hand_card(card: Dictionary, usage: Dictionary, playable: bool) -> void:
    var uid := str(card.get("uid", card.get("card_id", "")))
    var usage_id := str(usage.get("id", ""))
    var button: Button = BattleHandView.make_physical_card(card, usage,
        playable, selected_card_uid == uid and selected_usage_id == usage_id)
    button.set_meta("usage_id", usage_id)
    button.set_meta("display_only", not playable)
    if playable:
        button.pressed.connect(_select_card.bind(uid, usage_id))
        _bind_card_feedback(button)
    else:
        button.disabled = true
        button.modulate = Color(0.75, 0.80, 0.82, 0.87)
        button.tooltip_text += "\n" + _unavailable_card_hint(card, str(snap.get("phase", "")))
    card_actions.add_child(button)

func _rebuild_actions() -> void:
    if card_actions == null or command_actions == null:
        return
    for child in card_actions.get_children():
        child.queue_free()
    for child in command_actions.get_children():
        child.queue_free()
    var available: bool = _player_decision() and not auto_battle and not bool(snap.get("animation_pending", false)) and str(snap.get("outcome", "playing")) == "playing"
    var owner = model.state.get_actor(_decision_owner())
    var actor_name := str(owner.name) if owner != null else "等待"
    var pass_only := str(snap.get("phase", "")) == "CLASH" and ResponsePolicy.should_auto_pass(
        "CLASH", false, legals)
    # Never use legal_actions as the source of visible hand cards. That would
    # hide drawn attacks when the opponent starts outside their attack range.
    var hand_counts: Dictionary = BattleHandView.render_physical_hand(
        snap.get("hand", []), available, pass_only,
        Callable(self, "_find_actions"), Callable(self, "_can_approach_card"),
        Callable(self, "_can_free_movement_card"),
        Callable(self, "_add_visible_hand_card"))
    var displayed_count: int = int(hand_counts.displayed_count)
    var playable_count: int = int(hand_counts.playable_count)
    var hint := "%s · 手牌 %d 张" % [actor_name, displayed_count]
    if auto_battle:
        hint += "    自动托管中 · 按 A 恢复手动"
    elif available and not pass_only:
        hint += "    选择亮起的招式，再点击目标" if playable_count > 0 else "    灰色牌已抽到，靠近目标或满足条件后可出"
    else:
        hint += "    当前等待应变／动画，手牌仍保留"
    selection_label.text = hint
    _request_fan_layout()
    if not available or pass_only:
        return

    var seen_abilities: Dictionary = {}
    for action in legals:
        if str(action.get("kind", "")) != "USE_ABILITY":
            continue
        var technique_id := str(action.get("technique_id", ""))
        var node_id := str(action.get("node_id", ""))
        var key := technique_id + ":" + node_id
        if seen_abilities.has(key):
            continue
        seen_abilities[key] = true
        var technique_def: Dictionary = model.techniques.definitions.get(technique_id,{})
        var stage_def: Dictionary = model.techniques.node(owner,technique_id,node_id)
        var button := CardUI.make_card(technique_id + ":" + node_id,
            "tf_change" if technique_id == "tf_change_stage" else technique_id,
            str(technique_def.get("name","武学续式")),
            str(stage_def.get("name",node_id)),
            model.techniques.cost(owner,technique_id,node_id),
            selected_technique == technique_id and selected_node == node_id)
        button.set_meta("technique_id", technique_id)
        button.set_meta("node_id", node_id)
        button.pressed.connect(_select_technique.bind(technique_id, node_id))
        card_actions.add_child(button)
        _bind_card_feedback(button)

    # Make ranged-out staged martial attacks selectable as well.
    if owner != null:
        for technique_id in owner.technique_states:
            for stage_def in model.techniques.available_nodes(owner,str(technique_id),"ACTION"):
                var node_id: String=str(stage_def.get("id",""))
                var key: String=str(technique_id)+":"+node_id
                if seen_abilities.has(key) or not _can_approach_technique(str(technique_id),node_id):
                    continue
                seen_abilities[key]=true
                var technique_def: Dictionary=model.techniques.definitions.get(str(technique_id),{})
                var button := CardUI.make_card(key,
                    "tf_change" if str(technique_id)=="tf_change_stage" else str(technique_id),
                    str(technique_def.get("name","武学续式")),
                    str(stage_def.get("name",node_id)),
                    model.techniques.cost(owner,str(technique_id),node_id),
                    selected_technique==str(technique_id) and selected_node==node_id)
                button.set_meta("technique_id",str(technique_id))
                button.set_meta("node_id",node_id)
                button.pressed.connect(_select_technique.bind(str(technique_id),node_id))
                card_actions.add_child(button)
                _bind_card_feedback(button)

    var commands := {
        "BASIC_GUARD": "守势 · 格挡",
        "END_ACTION": "收势 · 结束行动",
        "PASS_REACTION": "按兵 · 交还响应",
        "PITCH_CARD": "弃牌 · 调息",
        "RESET_TECHNIQUE": "收招 · 复位",
        "SWITCH_SCHOOL": "切换武学"
    }
    var command_seen: Dictionary = {}
    var pitch_actions: Array = []
    var school_switch_available := false
    for action in legals:
        var kind := str(action.get("kind", ""))
        if not commands.has(kind):
            continue
        if kind == "PITCH_CARD":
            pitch_actions.append(action)
            continue
        if kind == "SWITCH_SCHOOL":
            school_switch_available = true
            continue
        var key := kind + ":" + str(action.get("card_uid", action.get("technique_id", "")))
        if command_seen.has(key):
            continue
        command_seen[key] = true
        var command_button := Button.new()
        command_button.text = str(commands[kind])
        if kind == "RESET_TECHNIQUE":
            command_button.text = "复位 · " + str(action.get("technique_id", ""))
        UITheme.apply_button(command_button)
        command_button.pressed.connect(_submit_legal.bind(action))
        command_actions.add_child(command_button)
    if school_switch_available:
        var schools_button := Button.new()
        schools_button.name = "SwitchSchoolMenu"
        schools_button.text = "武学 · 切换  ▸"
        UITheme.apply_button(schools_button)
        schools_button.pressed.connect(_open_character_card.bind(_decision_owner()))
        command_actions.add_child(schools_button)
    if not pitch_actions.is_empty():
        # Present one contextual command instead of N technical card-UID rows.
        var pitch_toggle := Button.new()
        pitch_toggle.name = "PitchToggle"
        pitch_toggle.text = "调息 · 弃牌  ▸"
        UITheme.apply_button(pitch_toggle)
        pitch_toggle.pressed.connect(_toggle_pitch_choices.bind(pitch_actions, pitch_toggle))
        command_actions.add_child(pitch_toggle)
    if snap.get("phase", "") == "CLASH" and not command_seen.has("PASS_REACTION:"):
        var pass_button := Button.new()
        pass_button.text = "按兵 · 交还响应"
        UITheme.apply_button(pass_button)
        pass_button.pressed.connect(_submit.bind("PASS_REACTION", {}))
        command_actions.add_child(pass_button)

func _toggle_pitch_choices(actions: Array, toggle: Button) -> void:
    var existing := command_actions.get_node_or_null("PitchChoices")
    if existing != null:
        existing.queue_free()
        toggle.text = "调息 · 弃牌  ▸"
        return
    toggle.text = "调息 · 收起  ▾"
    var choices := VBoxContainer.new()
    choices.name = "PitchChoices"
    choices.add_theme_constant_override("separation", 3)
    command_actions.add_child(choices)
    for action in actions:
        var card_uid := str(action.get("card_uid", ""))
        var card_name := "手牌"
        for card in snap.get("hand", []):
            if str(card.get("uid", card.get("card_id", ""))) == card_uid:
                card_name = str(card.get("name", "手牌"))
                break
        var choice := Button.new()
        choice.text = "弃 · " + card_name
        UITheme.apply_button(choice)
        choice.pressed.connect(_submit_legal.bind(action))
        choices.add_child(choice)

func _bind_card_feedback(button: Button) -> void:
    # Scale changes do not affect the HBox layout or the legal action data.
    button.pivot_offset = Vector2(button.custom_minimum_size.x * 0.5, button.custom_minimum_size.y)
    button.mouse_entered.connect(_on_card_hover.bind(button, true))
    button.mouse_exited.connect(_on_card_hover.bind(button, false))

func _on_card_hover(button: Button, entering: bool) -> void:
    if not is_instance_valid(button):
        return
    var chosen := _is_selected_card(button)
    button.z_index = 5 if entering or chosen else 0
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_CUBIC)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(button, "scale",
        Vector2.ONE * (1.055 if entering else (1.025 if chosen else 1.0)), 0.14)

func _is_selected_card(button: Button) -> bool:
    if button.has_meta("technique_id"):
        return str(button.get_meta("technique_id")) == selected_technique and str(button.get_meta("node_id")) == selected_node
    return button.has_meta("card_uid") and str(button.get_meta("card_uid")) == selected_card_uid and str(button.get_meta("usage_id")) == selected_usage_id

func _paint_selection() -> void:
    for child in card_actions.get_children():
        if not child is Button:
            continue
        var chosen := _is_selected_card(child)
        UITheme.apply_card(child, chosen)
        if chosen:
            child.z_index = 4
            child.scale = Vector2.ONE * 1.025
        elif not child.is_hovered():
            child.z_index = 0
            child.scale = Vector2.ONE

func _update_card_selection() -> void:
    _paint_selection()
    _request_fan_layout()

func _select_card(uid: String, usage: String) -> void:
    _clear_selection()
    selected_card_uid = uid
    selected_usage_id = usage
    selected_kind = "PLAY_CARD"
    _update_card_selection()
    _activate_selection()

func _select_technique(technique: String, node: String) -> void:
    _clear_selection()
    selected_technique = technique
    selected_node = node
    selected_kind = "USE_ABILITY"
    _update_card_selection()
    _activate_selection()

func _selected_actions() -> Array:
    if selected_kind == "PLAY_CARD":
        return _find_actions(selected_card_uid, selected_usage_id)
    var choices: Array = []
    if selected_kind == "USE_ABILITY":
        for action in legals:
            if str(action.get("kind", "")) == selected_kind and str(action.get("technique_id", "")) == selected_technique and str(action.get("node_id", "")) == selected_node:
                choices.append(action)
    return choices

func _submit_legal(action: Dictionary) -> void:
    var params: Dictionary = {}
    for key in ["card_uid", "card_id", "usage_id", "technique_id", "node_id", "target_cell", "target_id", "link_id", "school_id"]:
        if action.has(key):
            params[key] = action[key]
    _clear_selection()
    _submit(str(action.get("kind", "")), params)

func _activate_selection() -> void:
    var actions := _selected_actions()
    if actions.is_empty():
        if selected_kind=="PLAY_CARD" and _can_free_movement_card(selected_card_uid,selected_usage_id):
            selection_label.text="已选择身法：点击地图任意合法位置，按路径距离施展步法；右键取消。"
            _paint_selection()
            _refresh_target_markers()
            return
        if (selected_kind=="PLAY_CARD" and _can_approach_card(selected_card_uid,selected_usage_id)) or (selected_kind=="USE_ABILITY" and _can_approach_technique(selected_technique,selected_node)):
            selection_label.text="已选择攻击招式：点击敌方角色自动寻路接近并出招；右键取消。"
            _paint_selection()
            _refresh_target_markers()
            return
        _clear_selection()
        return
    # In FREE, a movement card targets arbitrary world coordinates, including
    # the defensive-reaction dodge; do not silently snap it to a cell.
    if selected_kind=="PLAY_CARD" and _can_free_movement_card(selected_card_uid,selected_usage_id):
        selection_label.text="已选择身法：点击地图任意合法位置；右键取消。"
        _paint_selection()
        _refresh_target_markers()
        return
    # Untargeted effects execute immediately. Link-targeted responses get buttons.
    if not actions[0].has("target_cell") and not actions[0].has("target_id") and not actions[0].has("link_id"):
        _submit_legal(actions[0])
        return
    for action in actions:
        if not action.has("link_id"):
            continue
        var button := Button.new()
        button.text = "截势：选择响应层 %s" % str(action.link_id)
        UITheme.apply_button(button)
        button.pressed.connect(_submit_legal.bind(action))
        command_actions.add_child(button)
    selection_label.text = "已选择招式：点击敌方角色直接出招，或自动接近后出招；右键取消。"
    _paint_selection()
    _refresh_target_markers()

func _action_at(cell: Vector2i) -> Dictionary:
    for action in _selected_actions():
        if action.has("target_cell") and action.target_cell == cell:
            return action
        if action.has("target_id"):
            var target_id := int(action.target_id)
            for actor in snap.get("actors", []):
                if int(actor.id) == target_id and actor.cell == cell:
                    return action
    return {}

func _update_status() -> void:
    if status_label == null or snap.is_empty():
        return
    BattleHUDStatus.render(snap, _decision_owner(),
        model.state.get_actor(_decision_owner()),
        story_encounter, auto_battle, str(model.state.spatial_mode),
        model.state.spatial != null, _player_decision(), animation_ticket,
        {"status": status_label, "auto": auto_button,
        "spatial": spatial_mode_button, "roster_labels": roster_labels,
        "roster_bars": roster_bars, "rail": charge_rail,
        "commands": command_actions, "veil": context_veil,
        "scroll": command_scroll, "clash": clash_label, "phase": phase_label})

func _auto_pass_unavailable_reactions() -> bool:
    # Work entirely through the authoritative, versioned submit pipeline.
    # Both human and AI participants are skipped when they have no viable
    # response card or technique; do not consume time for an empty pass.
    if str(snap.get("phase", "")) != "CLASH" or animation_ticket >= 0:
        return false
    var owner := _decision_owner()
    var legal: Array = model.legal_actions(owner)
    if not ResponsePolicy.should_auto_pass("CLASH",
            bool(model.state.animation_pending), legal):
        return false
    var result: Dictionary = model.submit(model.request("PASS_REACTION", owner))
    if not bool(result.get("success", false)):
        push_warning("Unable to auto-pass unavailable reaction: " + str(result.get("message", "")))
        return false
    # Normal-pass events contain only PRIORITY_PASSED. When this is the
    # second pass, combat resolution can emit damage/attack events: preserve
    # those animation tickets so the result is still shown in the arena.
    var presentation_needed := false
    for event in result.get("events", []):
        if str(event.get("type", "")) != "PRIORITY_PASSED":
            presentation_needed = true
            break
    _accept(result)
    if not presentation_needed and bool(model.state.animation_pending):
        var ticket := int(result.get("ticket", -1))
        var acknowledged: Dictionary = model.acknowledge_animation(ticket)
        if bool(acknowledged.get("success", false)):
            presentation.cancel()
            animation_ticket = -1
            animation_time = 0.0
            _accept(acknowledged)
    return true

func _process(delta: float) -> void:
    if snap.is_empty():
        return
    elapsed += delta
    if intro_remaining > 0.0:
        intro_remaining = maxf(0.0, intro_remaining - delta)
        var reveal: float = minf(1.0, intro_remaining / 0.65)
        intro_title.modulate.a = reveal
        intro_subtitle.modulate.a = reveal
        intro_title.visible = intro_remaining > 0.0
        intro_subtitle.visible = intro_remaining > 0.0
    camera_shake = maxf(0.0, camera_shake - delta)
    # CanvasLayer does not follow Camera2D: shake the painted world instead.
    if illustrated_map != null:
        illustrated_map.scene_root.position = Vector2(
            sin(elapsed * 71.0) * 10.0, sin(elapsed * 89.0) * 6.0) * camera_shake
    _update_cursor()
    _update_continuous_preview()
    var moving: Dictionary = {}
    for actor in snap.get("actors", []):
        var id := int(actor.id)
        if actor_nodes.has(id):
            var node: Node2D = actor_nodes[id] if illustrated_map != null else null
            if illustrated_map != null:
                if continuous_paths.has(id):
                    var free_steps: Array = continuous_paths[id]
                    var next_position: Vector2 = Vector2(free_steps[0])
                    if node.position.distance_to(next_position) <= 1.0:
                        free_steps.pop_front()
                    else:
                        var heading: Vector2 = next_position - node.position
                        animation_driver.set_facing(id, Facing.from_delta(Vector2i(roundi(heading.x), roundi(heading.y)), animation_driver.facing_for(id)))
                        node.position = node.position.move_toward(next_position, delta * 160.0)
                        if node.position.distance_to(next_position) <= 1.0:
                            node.position = next_position
                            free_steps.pop_front()
                    if free_steps.is_empty():
                        continuous_paths.erase(id)
                        visual_cells[id] = Vector2i(actor.cell)
                    else:
                        continuous_paths[id] = free_steps
                    moving[id] = continuous_paths.has(id)
                    continue
                var path2: Array = movement_paths.get(id, [])
                var dest2: Vector2 = Vector2(actor.get("position", illustrated_map.point_for_cell(Vector2i(actor.cell))))
                if not path2.is_empty():
                    var step2 := Vector2i(path2[0])
                    animation_driver.set_facing(id, Facing.from_delta(step2 - Vector2i(visual_cells.get(id, actor.cell)), animation_driver.facing_for(id)))
                    dest2 = illustrated_map.point_for_cell(step2)
                node.position = node.position.move_toward(dest2, delta * 160.0)
                var walking2 := node.position.distance_to(dest2) > 1.0
                if not walking2 and not path2.is_empty():
                    node.position = dest2
                    visual_cells[id] = Vector2i(path2.pop_front())
                    if path2.is_empty(): movement_paths.erase(id)
                    else: movement_paths[id] = path2
                moving[id] = walking2 or not path2.is_empty()
                continue
    animation_driver.update(delta, moving)
    if illustrated_map != null:
        for actor in snap.get("actors", []):
            var id := int(actor.id)
            var role: Node2D = actor_nodes.get(id, null)
            if role != null:
                role.visible = float(actor.hp) > 0
                role.z_index = clampi(roundi(role.position.y / 20.0), 0, 100)
    if effects_driver != null:
        effects_driver.update(delta)
    if animation_ticket >= 0:
        var finished_ticket: int = presentation.advance(delta,
            animation_driver.remaining_seconds(),
            not movement_paths.is_empty() or not continuous_paths.is_empty())
        animation_time = presentation.wait_remaining
        if finished_ticket >= 0:
            animation_ticket = -1
            _accept(model.acknowledge_animation(finished_ticket))
        return
    if snap.get("outcome", "playing") != "playing":
        return
    if character_card != null and character_card.visible:
        return
    # Resolve up to both priority passes without any human prompt or AI
    # thinking delay. Stop immediately if damage/response animation begins.
    for _auto_step in range(2):
        if not _auto_pass_unavailable_reactions():
            break
        if animation_ticket >= 0:
            return
    var decision_id := int(snap.get("active_id", -1))
    if snap.get("phase", "") == "CLASH":
        decision_id = int(snap.get("clash", {}).get("priority_actor_id", -1))
    var decision_actor = model.state.get_actor(decision_id)
    if decision_actor != null and (decision_actor.controller != "PLAYER" or auto_battle):
        ai_wait -= delta
        if ai_wait <= 0:
            var request: Dictionary = ai.choose_action(model.decision_context(decision_id))
            ai_wait = 0.4
            if not request.is_empty():
                _accept(model.submit(request))

func _accept(result: Dictionary) -> void:
    if not result.get("success", false):
        var warning: String = str(result.get("message", "行动无法执行"))
        push_warning(warning)
        if selection_label != null:
            selection_label.text = "无法执行：%s" % warning
        return
    for event in result.get("events", []):
        if str(event.get("type",""))=="BATTLE_MODE_CHANGED":
            movement_paths.clear()
            continuous_paths.clear()
            continuous_preview_enabled = str(event.get("to","GRID"))=="FREE"
            var session=get_node_or_null("/root/GameSession")
            if session!=null and session.has_method("set_battle_spatial_mode"):
                session.call("set_battle_spatial_mode",str(event.get("to","GRID")))
            if continuous_preview != null:
                continuous_preview.clear_preview()
            if illustrated_map != null:
                for role_id in actor_nodes:
                    var combatant=model.state.get_actor(int(role_id))
                    if combatant!=null:
                        actor_nodes[role_id].position=combatant.position
                        visual_cells[role_id]=Vector2i(combatant.cell)
    _cue_events(result.get("events", []))
    # Presentation follows each real path waypoint, rather than the straight
    # chord between old and final grid cells. Facing tracks each segment.
    for event in result.get("events", []):
        if str(event.get("type", "")) == "MOVE":
            var id: int=int(event.get("actor_id",-1))
            if actor_nodes.has(id):
                continuous_paths.erase(id)
                visual_cells[id]=Vector2i(event.get("from",Vector2i.ZERO))
                movement_paths[id]=event.get("path",[]).duplicate()
        elif str(event.get("type", "")) == "MOVE_FREE":
            var id: int=int(event.get("actor_id",-1))
            if actor_nodes.has(id) and illustrated_map != null:
                movement_paths.erase(id)
                var steps: Array = []
                for point in event.get("path", PackedVector2Array()):
                    steps.append(Vector2(point))
                if not steps.is_empty():
                    steps.pop_front()
                if not steps.is_empty():
                    continuous_paths[id] = steps
    animation_driver.events(result.get("events", []))
    if effects_driver != null:
        effects_driver.handle_events(result.get("events", []), actor_nodes)
    _clear_selection()
    _refresh()
    if snap.get("animation_pending", false):
        presentation.begin(int(result.get("ticket", snap.get("ticket", -1))),
            animation_driver.remaining_seconds())
    else:
        presentation.cancel()
    animation_ticket = presentation.ticket
    animation_time = presentation.wait_remaining
    _refresh_target_markers()
    _update_status()

func _skip_presentation() -> void:
    # Snap graphics to the committed model state. Skip must never submit
    # a second attack or apply an effect; only acknowledge the active ticket.
    if animation_ticket < 0:
        return
    for actor in model.state.actors:
        if not actor_nodes.has(actor.id):
            continue
        actor_nodes[actor.id].position = Vector2(actor.position)
        visual_cells[actor.id] = Vector2i(actor.cell)
    movement_paths.clear()
    continuous_paths.clear()
    animation_driver.reset()
    if effects_driver != null:
        effects_driver.clear()
    var ticket_to_ack: int = presentation.skip()
    animation_ticket = -1
    animation_time = 0.0
    if ticket_to_ack >= 0:
        _accept(model.acknowledge_animation(ticket_to_ack))

func _cue_events(events: Array) -> void:
    for event in events:
        var kind := str(event.get("type", ""))
        var id := int(event.get("defender_id",
            event.get("target_id", event.get("actor_id", -1))))
        if kind in ["ATTACK_DECLARED", "COMBO_TRIGGERED", "SHIELD", "MOVE"]:
            id = int(event.get("actor_id", id))
        if id >= 0:
            illustrated_map.pulse_actor(id)
        if kind in ["DAMAGE", "HP_DAMAGED", "ATTACK_HIT", "COMBO_TRIGGERED"]:
            camera_shake = 0.20
        last_cue = kind

func _submit(kind: String, params: Dictionary = {}) -> void:
    # Gate stale input and auto mode before attempting a versioned command.
    var dispatched: Dictionary = BattleCommandController.from_view(
        model, snap, _player_decision(), auto_battle, animation_ticket, kind, params)
    if bool(dispatched.get("dispatched", false)):
        _accept(dispatched.get("result", {}))

func _legal(kind: String, cell: Vector2i = Vector2i(-1, -1)) -> Dictionary:
    # Movement always requires a real target. The shared optional-cell
    # sentinel (-1,-1) must never choose the first legal MOVE when the user
    # clicks blocked water, cliff faces or outside the calibrated grid.
    if kind == "MOVE" and cell.x < 0:
        return {}
    for action in legals:
        if str(action.get("kind", "")) != kind:
            continue
        if cell.x >= 0 and action.get("target_cell", Vector2i(-2, -2)) != cell:
            continue
        return action
    return {}

func _hover_cell() -> Vector2i:
    return illustrated_map.cell_from_screen(
        get_viewport().get_mouse_position(), snap.get("terrain", {}))

func _screen_to_battle(screen: Vector2) -> Vector2:
    return illustrated_map.to_battle_point(screen)

func _update_cursor() -> void:
    hovered = _hover_cell()
    var usable := not _action_at(hovered).is_empty() if not selected_kind.is_empty() else not _legal("MOVE", hovered).is_empty()
    if not selected_kind.is_empty() and _enemy_at(hovered)>=0:
        usable=usable or (selected_kind=="PLAY_CARD" and _can_approach_card(selected_card_uid,selected_usage_id)) or (selected_kind=="USE_ABILITY" and _can_approach_technique(selected_technique,selected_node))
    if model.state.spatial_mode=="FREE" and selected_kind.is_empty():
        usable = false
    illustrated_map.set_cursor(hovered, usable and animation_ticket < 0)

func _update_continuous_preview() -> void:
    if model.state.spatial_mode!="FREE" or (not continuous_preview_enabled and not (selected_kind=="PLAY_CARD" and _can_free_movement_card(selected_card_uid,selected_usage_id))) or continuous_space == null or continuous_preview == null or not _player_decision() or animation_ticket >= 0:
        if continuous_preview != null:
            continuous_preview.clear_preview()
        return
    var martial_step: bool=selected_kind=="PLAY_CARD" and _can_free_movement_card(selected_card_uid,selected_usage_id)
    if not selected_kind.is_empty() and not martial_step:
        continuous_preview.clear_preview()
        return
    var actor = model.state.get_actor(_decision_owner())
    if actor == null:
        continuous_preview.clear_preview()
        return
    var goal: Vector2 = _screen_to_battle(get_viewport().get_mouse_position())
    var path: PackedVector2Array = model.preview_free_path(actor.id, goal)
    if path.size() < 2:
        continuous_preview.clear_preview()
        return
    var cost: float = model.state.spatial.path_length(path)
    var unit: float = maxf(model.state.spatial.bake.step.x, model.state.spatial.bake.step.y)
    var units: int = ceili((cost - 0.0001) / unit)
    var remaining: int = int(actor.stats.get("move_budget", 2)) - actor.normal_moves_used
    var reachable: bool = units > 0 and units <= remaining and actor.qi_u >= units * 10000
    if martial_step:
        var usage: Dictionary=model.cards.usage(selected_card_uid,selected_usage_id)
        remaining=int(usage.get("target",{}).get("max_distance",0))
        for effect in usage.get("effects",[]):
            if str(effect.get("type",""))=="move": remaining=mini(remaining,int(effect.get("max_distance",0)))
        reachable=cost>0.25 and cost<=float(remaining)*unit+0.001
    continuous_preview.show_preview(path, cost, reachable)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S and animation_ticket >= 0:
        _skip_presentation()
        get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
        _toggle_spatial_mode()
        get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
        if model.state.spatial_mode!="FREE": return
        continuous_preview_enabled = not continuous_preview_enabled
        if not continuous_preview_enabled and continuous_preview != null:
            continuous_preview.clear_preview()
        get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_A:
        _toggle_auto_battle()
        get_viewport().set_input_as_handled()
        return
    if character_card != null and character_card.visible:
        if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
            character_card.call("close_card")
            get_viewport().set_input_as_handled()
        return
    if auto_battle and event is InputEventMouseButton:
        return
    if auto_battle and event is InputEventKey and event.keycode in [KEY_C, KEY_Q, KEY_G, KEY_SPACE, KEY_ENTER]:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        _clear_selection()
        _rebuild_actions()
        _refresh_target_markers()
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if selected_kind=="PLAY_CARD" and _can_free_movement_card(selected_card_uid,selected_usage_id):
            var step_intent: Dictionary = BattleInputController.world_click(
                "FREE", true, true, selected_kind, true, selected_card_uid,
                selected_usage_id, -1, _screen_to_battle(get_viewport().get_mouse_position()), {})
            _submit(str(step_intent.kind), step_intent.params)
            get_viewport().set_input_as_handled()
        elif not selected_kind.is_empty():
            var selected := _action_at(_hover_cell())
            if not selected.is_empty():
                _submit_legal(selected)
            else:
                _submit_selected_approach(_enemy_at(_hover_cell()))
            get_viewport().set_input_as_handled()
        else:
            var intent: Dictionary = BattleInputController.world_click(
                str(model.state.spatial_mode), illustrated_map != null,
                _player_decision(), selected_kind, false, "", "",
                _enemy_at(_hover_cell()), _screen_to_battle(get_viewport().get_mouse_position()),
                _legal("MOVE", _hover_cell()))
            if not intent.is_empty():
                _submit(str(intent.kind), intent.params)
                if model.state.spatial_mode == "FREE":
                    get_viewport().set_input_as_handled()
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_F3:
                if illustrated_map != null:
                    illustrated_map.set_debug_grid(not illustrated_map.debug_grid.visible)
            KEY_C:
                _open_character_card(observer_id)
            KEY_Q:
                var attack := _legal("BASIC_ATTACK")
                if not attack.is_empty():
                    _submit("BASIC_ATTACK", {"target_id": attack.target_id})
            KEY_G:
                if not _legal("BASIC_GUARD").is_empty():
                    _submit("BASIC_GUARD")
            KEY_SPACE, KEY_ENTER:
                var kind := "PASS_REACTION" if snap.get("phase", "") == "CLASH" else "END_ACTION"
                if not _legal(kind).is_empty():
                    _submit(kind)
            KEY_R:
                if story_encounter:
                    return
                model.reset(2026, -1, "tingfeng", _quick_character_options())
                _set_auto_battle(false)
                animation_driver.reset()
                if effects_driver != null:
                    effects_driver.clear()
                _clear_selection()
                presentation.reset_battle()
                animation_ticket = -1
                animation_time = 0.0
                _refresh()
                _refresh_target_markers()
                movement_paths.clear()
                continuous_paths.clear()
                for actor in snap.get("actors", []):
                    var id: int=int(actor.id)
                    actor_nodes[id].position = (Vector2(actor.get("position",
                        illustrated_map.point_for_cell(Vector2i(actor.cell)))))
                    visual_cells[id]=Vector2i(actor.cell)
                    animation_driver.set_facing(id,Vector2i(actor.facing))

            KEY_ESCAPE:
                if story_encounter and snap.get("outcome", "playing") != "playing":
                    get_tree().change_scene_to_file("res://demo_result.tscn")
                elif not story_encounter:
                    get_tree().change_scene_to_file("res://opening.tscn")
