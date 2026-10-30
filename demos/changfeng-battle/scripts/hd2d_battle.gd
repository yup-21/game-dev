extends Node2D
## HD-2D vertical slice. All tactical state and legality remain in BattleModel.
## Canonical player battle uses only painted 2D terrain and Sprite2D actors.
const Model = preload("res://scripts/battle_model.gd")
const BattleCommandController = preload("res://scripts/battle_command_controller.gd")
const BattleInputController = preload("res://scripts/battle_input_controller.gd")
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
const BattleWorld2D = preload("res://scripts/battle_world_2d.gd")
const BattlePresenter = preload("res://scripts/battle_presentation_player.gd")
const BattleHUDView = preload("res://scripts/battle_hud_view.gd")
var model = Model.new()
var story_encounter := false
var observer_id := 0
var result_reported := false
var ai = EnemyAI.new()
var animation_driver = Animator.new()
var presentation = PresentationCoordinator.new()
var presentation_player
var world = BattleWorld2D.new()
var hud_view = BattleHUDView.new()
var effects_driver
var continuous_preview
var continuous_preview_enabled := false
var _preview_last_goal := Vector2.INF
var _preview_last_actor := -1
var _preview_last_revision := -1
var _preview_last_card := ""
var _preview_last_query_ms: int = -1000000
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
    continuous_preview_enabled = model.state.spatial_mode == "FREE"
    observer_id = _first_player_id()
    snap = model.snapshot(observer_id)
    legals = model.legal_actions(_decision_owner())
    presentation_player = BattlePresenter.new(animation_driver, presentation)
    _build_world()
    if illustrated_map != null:
        continuous_preview = ContinuousPreview.new()
        illustrated_map.scene_root.add_child(continuous_preview)
    # 3D terrain, procedural scenery, and far-away backdrop are removed.
    # Only 2D painted ground and 2D sprite action frames are visible.
    presentation_player.attach(illustrated_map.scene_root)
    effects_driver = presentation_player.effects
    _build_ui()
    hud_view.bind_controls({"status": status_label, "auto": auto_button,
        "spatial": spatial_mode_button, "roster_labels": roster_labels,
        "roster_bars": roster_bars, "rail": charge_rail,
        "commands": command_actions, "veil": context_veil,
        "scroll": command_scroll, "clash": clash_label, "phase": phase_label})
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
    world.build(self, story_encounter, str(model.state.map_definition_path),
        snap.get("actors", []), animation_driver)
    camera = world.camera
    illustrated_map = world.illustrated_map
    actor_nodes = world.actor_nodes
    visual_cells = world.visual_cells
    movement_paths = world.movement_paths
    continuous_paths = world.continuous_paths

func _create_actor(actor: Dictionary) -> void:
    world.add_actor(actor, animation_driver)

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

func _build_ui() -> void:
    # R8: the reusable HUD module owns control construction and signal wiring.
    var refs: Dictionary = hud_view.build(self, story_encounter, snap)
    status_label = refs.status_label
    help_label = refs.help_label
    clash_label = refs.clash_label
    phase_label = refs.phase_label
    auto_button = refs.auto_button
    spatial_mode_button = refs.spatial_mode_button
    roster_labels = refs.roster_labels
    roster_bars = refs.roster_bars
    command_scroll = refs.command_scroll
    command_actions = refs.command_actions
    context_veil = refs.context_veil
    card_actions = refs.card_actions
    charge_rail = refs.charge_rail
    character_card = refs.character_card
    selection_label = refs.selection_label
    intro_title = refs.intro_title
    intro_subtitle = refs.intro_subtitle

func _request_fan_layout() -> void:
    # Container positioning is authoritative. Rotation and slight vertical
    # offsets only change presentation, not card order or scroll coordinates.
    if fan_layout_pending:
        return
    fan_layout_pending = true
    call_deferred("_layout_fan_cards")

func _layout_fan_cards() -> void:
    fan_layout_pending = false
    hud_view.layout_hand(card_actions, Callable(self, "_is_selected_card"))

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
    var hand_counts: Dictionary = hud_view.show_hand(
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
    hud_view.show_status(snap, _decision_owner(),
        model.state.get_actor(_decision_owner()),
        story_encounter, auto_battle, str(model.state.spatial_mode),
        model.state.spatial != null, _player_decision(), animation_ticket)

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
    var moving: Dictionary = world.tick(delta, snap, animation_driver)
    var finished_ticket: int = presentation_player.tick(delta, moving,
        world.paths_pending())
    if animation_ticket >= 0:
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
                continuous_preview.clear_all()
            if illustrated_map != null:
                for role_id in actor_nodes:
                    var combatant=model.state.get_actor(int(role_id))
                    if combatant!=null:
                        actor_nodes[role_id].position=combatant.position
                        visual_cells[role_id]=Vector2i(combatant.cell)
    _cue_events(result.get("events", []))
    # The world consumes movement paths; presentation only owns visual cues.
    world.queue_motion_events(result.get("events", []))
    presentation_player.consume(result.get("events", []), actor_nodes)
    _clear_selection()
    _refresh()
    presentation_player.begin(int(result.get("ticket", snap.get("ticket", -1))),
        bool(snap.get("animation_pending", false)))
    animation_ticket = presentation.ticket
    animation_time = presentation.wait_remaining
    _refresh_target_markers()
    _update_status()

func _skip_presentation() -> void:
    # Snap graphics to the committed model state. Skip must never submit
    # a second attack or apply an effect; only acknowledge the active ticket.
    if animation_ticket < 0:
        return
    world.snap_to_authority(model.state.actors, animation_driver)
    var ticket_to_ack: int = presentation_player.skip()
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
    return world.to_battle_point(screen)

func _update_cursor() -> void:
    hovered = _hover_cell()
    var usable := not _action_at(hovered).is_empty() if not selected_kind.is_empty() else not _legal("MOVE", hovered).is_empty()
    if not selected_kind.is_empty() and _enemy_at(hovered)>=0:
        usable=usable or (selected_kind=="PLAY_CARD" and _can_approach_card(selected_card_uid,selected_usage_id)) or (selected_kind=="USE_ABILITY" and _can_approach_technique(selected_technique,selected_node))
    if model.state.spatial_mode=="FREE" and selected_kind.is_empty():
        usable = false
    illustrated_map.set_cursor(hovered, usable and animation_ticket < 0)

func _update_continuous_preview() -> void:
    if model.state.spatial_mode != "FREE" or model.state.spatial == null or continuous_preview == null or not _player_decision() or animation_ticket >= 0:
        if continuous_preview != null:
            continuous_preview.clear_all()
        _preview_last_actor = -1
        return
    var martial_step: bool = selected_kind == "PLAY_CARD" and _can_free_movement_card(selected_card_uid, selected_usage_id)
    if not selected_kind.is_empty() and not martial_step:
        continuous_preview.clear_all()
        _preview_last_actor = -1
        return
    var actor = model.state.get_actor(_decision_owner())
    if actor == null:
        continuous_preview.clear_all()
        _preview_last_actor = -1
        return
    var unit: float = maxf(model.state.spatial.bake.step.x, model.state.spatial.bake.step.y)
    var remaining: int = int(actor.stats.get("move_budget", 2)) - actor.normal_moves_used
    if martial_step:
        var usage: Dictionary = model.cards.usage(selected_card_uid, selected_usage_id)
        remaining = int(usage.get("target", {}).get("max_distance", 0))
        for effect in usage.get("effects", []):
            if str(effect.get("type", "")) == "move":
                remaining = mini(remaining, int(effect.get("max_distance", 0)))
    var limit: float = maxf(0.0, float(remaining) * unit)
    if limit <= 0.0:
        continuous_preview.clear_all()
        _preview_last_actor = -1
        return
    continuous_preview.show_range(actor.position, limit)
    if not continuous_preview_enabled and not martial_step:
        continuous_preview.clear_preview()
        _preview_last_goal = Vector2.INF
        return
    var goal: Vector2 = _screen_to_battle(get_viewport().get_mouse_position())
    # Path length can never be smaller than the direct distance. Reject
    # out-of-range hover without running even the first A* query.
    if actor.position.distance_to(goal) > limit + 0.001:
        continuous_preview.clear_preview()
        _preview_last_goal = Vector2.INF
        return
    var revision: int = int(model.state.revision)
    var card_key: String = selected_card_uid + ":" + selected_usage_id if martial_step else ""
    var same_context: bool = _preview_last_actor == actor.id and _preview_last_revision == revision and _preview_last_card == card_key
    if same_context and _preview_last_goal.distance_to(goal) < 3.0:
        return
    var now_ms: int = Time.get_ticks_msec()
    if same_context and now_ms - _preview_last_query_ms < 50:
        continuous_preview.clear_preview()
        return
    _preview_last_actor = actor.id
    _preview_last_revision = revision
    _preview_last_card = card_key
    _preview_last_goal = goal
    _preview_last_query_ms = now_ms
    var path: PackedVector2Array = model.preview_free_path(actor.id, goal)
    if path.size() < 2:
        continuous_preview.clear_preview()
        return
    var cost: float = model.state.spatial.path_length(path)
    # A detour can exceed movement range even when the goal is inside the
    # circle. Hide the route completely, as requested, instead of redrawing it.
    if cost > limit + 0.001 or cost < 0.25:
        continuous_preview.clear_preview()
        return
    var units: int = ceili((cost - 0.0001) / unit)
    var affordable: bool = martial_step or actor.qi_u >= units * 10000
    continuous_preview.show_preview(path, cost, affordable, limit)

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
                presentation_player.reset_battle()
                _clear_selection()
                animation_ticket = -1
                animation_time = 0.0
                _refresh()
                _refresh_target_markers()
                world.snap_to_authority(model.state.actors, animation_driver)

            KEY_ESCAPE:
                if story_encounter and snap.get("outcome", "playing") != "playing":
                    get_tree().change_scene_to_file("res://demo_result.tscn")
                elif not story_encounter:
                    get_tree().change_scene_to_file("res://opening.tscn")
