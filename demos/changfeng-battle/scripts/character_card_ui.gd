extends Control
signal switch_requested(actor_id: int, school_id: String)
## Interactive character dossier. CharacterRegistry owns identity and art;
## BattleModel's CombatantState is the sole authority for mutable values.
const Registry = preload("res://scripts/character_registry.gd")
const ItemCatalog = preload("res://scripts/item_catalog.gd")
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
    if not has_node("Backdrop"):
        push_error("Character dossier must be instantiated from scenes/ui/character_card.tscn")
        return
    _bind_native_scene()

func _bind_native_scene() -> void:
    # In the authored PackedScene every panel, image and label is editable.
    title_label = find_child("DossierTitle", true, false) as Label
    identity_label = find_child("Identity", true, false) as Label
    bio_label = find_child("Biography", true, false) as Label
    martial_label = find_child("MartialDetails", true, false) as Label
    schools_column = find_child("LearnedSchools", true, false) as VBoxContainer
    stats_label = find_child("Stats", true, false) as Label
    status_label = find_child("StatusDetails", true, false) as Label
    art_label = find_child("ArtDescription", true, false) as Label
    portrait = find_child("RolePortrait", true, false) as TextureRect
    preview = find_child("SpritePreview", true, false) as TextureRect
    var shade: ColorRect = get_node("Backdrop")
    if not shade.gui_input.is_connected(_on_backdrop_input):
        shade.gui_input.connect(_on_backdrop_input)
    var close: Button = find_child("CloseCharacterCard", true, false) as Button
    if not close.pressed.is_connected(close_card):
        close.pressed.connect(close_card)

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
    var sheet: Texture2D = Art.sheet_for_character(str(definition.id),actor.team_id!=0)
    var profile := Art.animation_profile_for_character(str(definition.id))
    if profile != null and profile.native_frames != null:
        # SpriteFrames already supplies a cropped frame; never slice it again.
        preview.texture = sheet
    else:
        var frame := AtlasTexture.new()
        frame.atlas = sheet
        var columns: int = profile.idle_columns() if profile != null else 6
        var rows: int = profile.idle_rows() if profile != null else 4
        frame.region = Rect2(0, 0, sheet.get_width() / float(columns),
            sheet.get_height() / float(rows))
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
    var catalog = ItemCatalog.new()
    var gear_names: Array = []
    for slot in actor.equipment:
        var item: Dictionary = catalog.get_item(str(actor.equipment[slot]))
        var label: String = str(slot) + " · " + str(item.get("name",actor.equipment[slot]))
        var affix_record: Dictionary = actor.equipment_affixes.get(slot,{})
        var names: Array = affix_record.get("affix_names",[])
        if not names.is_empty():
            label += "（" + "、".join(names) + "）"
        gear_names.append(label)
    status_label.text += ("装备：" + " / ".join(gear_names) if not gear_names.is_empty() else "装备：无")
    visible = true
    return true
