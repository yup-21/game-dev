extends Control
signal switch_requested(actor_id: int, school_id: String)
## Interactive character dossier. CharacterRegistry owns identity and art;
## BattleModel's CombatantState is the sole authority for mutable values.
const Registry = preload("res://scripts/character_registry.gd")
const Art = preload("res://scripts/hd2d_art_catalog.gd")
const UITheme = preload("res://scripts/hd2d_ui_theme.gd")
var registry = Registry.new()
var actor_id: int = -1
var model
var title_label: Label
var identity_label: Label
var bio_label: Label
var martial_label: Label
var schools_column: VBoxContainer
var stats_label: Label
var status_label: Label
var art_label: Label
var portrait: TextureRect
var preview: TextureRect

func _ready() -> void:
    name = "CharacterCardOverlay"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    visible = false
    var shade := ColorRect.new()
    shade.name = "Backdrop"
    shade.color = Color(0.015,0.06,0.07,0.82)
    add_child(shade)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    shade.gui_input.connect(_on_backdrop_input)
    var panel := Panel.new()
    panel.name = "Dossier"
    add_child(panel)
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.offset_left = -490
    panel.offset_right = 490
    panel.offset_top = -325
    panel.offset_bottom = 325
    var style := StyleBoxFlat.new()
    style.bg_color = Color("132b2c")
    style.border_color = Color("9eae94",0.36)
    style.set_border_width_all(1)
    style.set_corner_radius_all(12)
    panel.add_theme_stylebox_override("panel",style)
    var margin := MarginContainer.new()
    panel.add_child(margin)
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left","right","top","bottom"]:
        margin.add_theme_constant_override("margin_"+side,20)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation",12)
    margin.add_child(column)
    var header := HBoxContainer.new()
    column.add_child(header)
    title_label = _label(header,"",27,UITheme.GOLD)
    title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var close := Button.new()
    close.name = "CloseCharacterCard"
    close.text = "收起  ×"
    UITheme.apply_button(close)
    header.add_child(close)
    close.pressed.connect(close_card)
    column.add_child(HSeparator.new())
    var content := HBoxContainer.new()
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation",25)
    column.add_child(content)
    var left := VBoxContainer.new()
    left.custom_minimum_size.x = 236
    left.add_theme_constant_override("separation",10)
    content.add_child(left)
    portrait = TextureRect.new()
    portrait.name = "RolePortrait"
    portrait.custom_minimum_size = Vector2(232,368)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    left.add_child(portrait)
    preview = TextureRect.new()
    preview.name = "SpritePreview"
    preview.custom_minimum_size = Vector2(100,94)
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    left.add_child(preview)
    art_label = _label(left,"",12,UITheme.MUTED)
    art_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var scroll := ScrollContainer.new()
    scroll.name = "RoleDetailsScroll"
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(scroll)
    var details := VBoxContainer.new()
    details.name = "RoleDetails"
    details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    details.add_theme_constant_override("separation",13)
    scroll.add_child(details)
    identity_label = _label(details,"",16,UITheme.JADE)
    bio_label = _label(details,"",15,UITheme.PAPER)
    bio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _label(details,"已 学 武 学 · 切 换",19,UITheme.GOLD)
    schools_column = VBoxContainer.new()
    schools_column.name = "LearnedSchools"
    schools_column.add_theme_constant_override("separation",6)
    details.add_child(schools_column)
    _label(details,"当 前 招 式",19,UITheme.GOLD)
    martial_label = _label(details,"",14,UITheme.PAPER)
    martial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _label(details,"气 血 · 属 性",19,UITheme.GOLD)
    stats_label = _label(details,"",15,UITheme.MUTED)
    _label(details,"实 时 状 态 · 装 备",19,UITheme.GOLD)
    status_label = _label(details,"",14,UITheme.PAPER)
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _label(parent: Node, value: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",color)
    parent.add_child(label)
    return label

func _on_backdrop_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        close_card()

func close_card() -> void:
    visible = false

func _request_switch(id: int, school_id: String) -> void:
    switch_requested.emit(id,school_id)

func open_actor(battle_model, id: int) -> bool:
    var actor = battle_model.state.get_actor(id)
    if actor == null:
        return false
    var definition: Dictionary = registry.get_profile(str(actor.character_id))
    if definition.is_empty():
        definition = registry.for_actor(id)
    if definition.is_empty():
        return false
    model = battle_model
    actor_id = id
    title_label.text = str(definition.name) + "  /  " + str(definition.title)
    identity_label.text = "%s · %s · %s" % [str(definition.role),str(definition.faction),str(definition.weapon)]
    bio_label.text = str(definition.biography) + "\n\n性情 · " + str(definition.personality)
    portrait.texture = Art.portrait_for_character(str(definition.id))
    var frame := AtlasTexture.new()
    var sheet: Texture2D = Art.sheet_for_character(str(definition.id),actor.team_id!=0)
    frame.atlas = sheet
    frame.region = Rect2(0,0,sheet.get_width()/6.0,sheet.get_height()/4.0)
    preview.texture = frame
    art_label.text = ("角色立绘已接入" if portrait.texture != null else "精细立绘待制作") + "\n动作素材：" + str(definition.art.sheet_quality)
    for child in schools_column.get_children():
        child.queue_free()
    var can_switch: Dictionary = {}
    for choice in battle_model.legal_actions(id):
        if str(choice.get("kind","")) == "SWITCH_SCHOOL":
            can_switch[str(choice.school_id)] = true
    for school_id in actor.learned_schools:
        var definition_school: Dictionary = battle_model.cards.catalog.get_school(str(school_id))
        var selected: bool = str(school_id) == actor.school_id
        var button := Button.new()
        button.name = "School_" + str(school_id)
        button.text = ("◆  " if selected else "◇  ") + str(definition_school.get("name",school_id)) + ("  · 当前" if selected else "  · 切换并结束行动")
        UITheme.apply_button(button)
        button.disabled = selected or not can_switch.has(str(school_id))
        button.tooltip_text = "当前装备" if selected else ("切换武学将重新装配牌组并消耗本次行动" if not button.disabled else "仅可在本角色的行动阶段切换")
        button.pressed.connect(_request_switch.bind(id,str(school_id)))
        schools_column.add_child(button)
    var descriptions: Array = [str(actor.school_name)]
    var school: Dictionary = battle_model.cards.catalog.get_school(str(actor.school_id))
    for form_id in school.get("core_forms",[]):
        var form: Dictionary = battle_model.cards.definitions.get(str(form_id),{})
        if not form.is_empty():
            descriptions.append("· " + str(form.get("name",form_id)))
    for tech_id in actor.technique_states:
        var technique: Dictionary = battle_model.techniques.definitions.get(str(tech_id),{})
        if not technique.is_empty():
            descriptions.append("· " + str(technique.get("name",tech_id)) + " / 阶段：" + str(actor.technique_states[tech_id].node))
    martial_label.text = "\n".join(descriptions)
    stats_label.text = "气血 %.0f / %.0f       内息 %.0f / %.0f\n" % [actor.hp,actor.max_hp,actor.qi,actor.max_qi]
    stats_label.text += "力道 STR %d     身法 AGI %d\n根骨 CON %d     心神 MND %d\n" % [
        int(actor.attributes.STR),int(actor.attributes.AGI),int(actor.attributes.CON),int(actor.attributes.MND)]
    stats_label.text += "攻击 %d     防御 %d     集气 %d" % [
        int(actor.stats.attack),int(actor.stats.defense),int(actor.stats.charge_speed)]
    var effects: Array = []
    for status_id in actor.statuses:
        effects.append(str(status_id)+" ×"+str(actor.statuses[status_id].get("stacks",1)))
    status_label.text = ("状态："+" · ".join(effects) if not effects.is_empty() else "状态：无") + "\n"
    status_label.text += "护盾 %.0f    已学技能 %d    抽牌堆 %d\n" % [
        actor.shield,actor.technique_states.size(),actor.draw_pile.size()]
    status_label.text += "装备栏与成长履历：尚未接入，暂无可显示数据。"
    visible = true
    return true
