extends SceneTree
## Real Godot headless contract test. Uses isolated test directory, never user saves.
const Inventory=preload("res://scripts/inventory_system.gd")
const Saves=preload("res://scripts/save_system.gd")
const Session=preload("res://scripts/game_session.gd")
const Model=preload("res://scripts/battle_model.gd")
const Martial=preload("res://scripts/martial_progression.gd")
var failures: int=0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool,label: String) -> void:
	if ok: print("PASS "+label)
	else:
		failures+=1
		push_error("FAIL "+label)

func _run() -> void:
	var inv=Inventory.new()
	check(inv.load_error.is_empty(),"item catalog validates")
	var rec=inv.starter_record()
	check(inv.valid(rec) and rec.equipment.size()==9,"starter bag validates nine gear slots")
	check(inv.count(rec,"healing_powder")==3,"starter medicine counts")
	var before: float=inv.weight(rec)
	check(inv.equip(rec,"old_saber","weapon"),"equip from bag")
	check(inv.count(rec,"old_saber")==0 and rec.equipment.weapon=="old_saber","gear moved, never duplicated")
	check(is_equal_approx(inv.weight(rec),before),"equipping preserves total carried weight")
	check(inv.equip(rec,"iron_sword","weapon"),"swapping gear returns previous sword to bag")
	check(inv.count(rec,"old_saber")==1 and rec.equipment.weapon=="iron_sword","old gear returned")
	check(inv.unequip(rec,"weapon") and inv.count(rec,"iron_sword")==1,"unequip returns gear")
	check(not inv.equip(rec,"healing_powder","head"),"consumable cannot be equipped")
	check(inv.add(rec,"healing_powder",18),"consumable stacks may split")
	check(inv.count(rec,"healing_powder")==21,"stacked totals remain intact")
	check(not inv.add(rec,"iron_ore",100),"capacity or weight overflow is atomic")
	check(inv.valid(rec),"failed add leaves inventory consistent")
	check(inv.equip(rec,"soft_boots","feet"),"boots are equippable")
	var gear_bonus: Array=inv.equipment_modifiers(rec)
	check(not gear_bonus.is_empty(),"equipment produces stat modifiers")
	var session=Session.new()
	root.add_child(session)
	session.start_new_game()
	check(session.inventories.has(0),"new story begins with a real backpack")
	session.record_story_event("obtain_fragment")
	check(inv.count(session.inventories[0],"taixu_scroll")==1,"story fragment is in quest item bag")
	check(not session.equip_item(0,"taixu_scroll","weapon"),"quest item cannot equip")
	session.study_fragment()
	check(session.equip_item(0,"soft_boots","feet"),"story session equips boots")
	check(session.equip_item(0,"iron_sword","weapon"),"story session equips sword")
	var began: bool=session.begin_encounter()
	check(began,"story begins 3v3 encounter with equipped gear")
	if not began:
		print("BLOCKER: "+session.director.load_error)
		quit(1)
		return
	var battle=Model.new()
	battle.reset(session.encounter_seed(),0,"tingfeng",session.encounter_options())
	check(battle.state.outcome=="playing","equipped encounter initializes")
	if battle.state.outcome!="playing":
		print("BLOCKER: "+str(battle.state.logs))
		quit(1)
		return
	var actor=battle.state.get_actor(0)
	check(actor.stats.attack==11 and actor.effective_attributes.AGI==11,"equipped sword modifies attack and agility")
	check(actor.stats.charge_speed>100,"equipped boots affect CTB")
	actor.hp_u=mini(actor.hp_u,actor.max_hp_u-40000)
	var use: Dictionary={}
	for option in battle.legal_actions(0):
		if option.kind=="USE_ITEM" and str(option.item_id)=="healing_powder": use=option
	check(not use.is_empty(),"consumable is a legal player action")
	if not use.is_empty():
		var response: Dictionary=battle.submit(battle.request("USE_ITEM",0,use))
		check(bool(response.get("success",false)),"consumable uses authoritative request/submit")
		check(actor.hp_u==actor.max_hp_u,"consumable restores actual HP but does not exceed effective cap")
		check(battle.inventory.count(battle.inventory_records[0],"healing_powder")==2,"item stack decremented exactly once")
		if battle.state.animation_pending: battle.acknowledge_animation(battle.state.animation_ticket)
		var second: Dictionary={}
		for option in battle.legal_actions(0):
			if option.kind=="USE_ITEM": second=option
		check(second.is_empty(),"only one consumable per owner action")
	session.capture_battle_progress(battle)
	check(inv.count(session.inventories[0],"healing_powder")==2,"consumed inventory persists back to story")
	check(session.report_battle("victory",0),"battle reaches aftermath")
	check(session.choose_aftercare("pursue"),"injury remains after pursuit")
	check(session.injury_stacks==1,"wound recorded")
	check(session.use_field_item(0,"meridian_ointment"),"ointment heals one injury outside combat")
	check(session.injury_stacks==0 and inv.count(session.inventories[0],"meridian_ointment")==0,"field medicine consumes exactly one ointment")
	check(session.save_game(0)==false,"invalid public slot rejected")
	# Read/write an isolated alternate folder to avoid ever touching a player's saves.
	var saves=Saves.new("user://test_martial_save_v1")
	check(saves.save(1,session),"versioned atomic save succeeds")
	check(saves.info(1).state=="ready","save digest validates")
	var restored=Session.new()
	root.add_child(restored)
	var loaded: bool=saves.load(1,restored)
	check(loaded,"saved story reloads into a clean GameSession")
	if not loaded:
		print("BLOCKER: "+saves.last_error)
		quit(1)
		return
	check(restored.phase=="aftermath" and restored.martial_records[0].has("taixu"),"martial progress survives reload")
	check(restored.inventories[0].equipment.weapon=="iron_sword","equipped sword survives serialization")
	check(inv.count(restored.inventories[0],"healing_powder")==2,"stack quantities survive serialization")
	check(restored.injury_stacks==0 and restored.aftercare=="pursue","healing and choices survive serialization")
	var current: Dictionary=restored.export_save_data()
	var bad: Dictionary=current.duplicate(true)
	bad.inventories[0].stacks=[{"id":"fake_unsafe_item","count":1}]
	check(not restored.validate_save_data(bad),"unknown item IDs rejected before load")
	check(not saves.load(4,restored),"out-of-range save slot refused")
	var path: String=ProjectSettings.globalize_path("user://test_martial_save_v1/slot_01.json")
	var reader=FileAccess.open(path,FileAccess.READ)
	var contents: String=reader.get_as_text()
	reader.close()
	var writer=FileAccess.open(path,FileAccess.WRITE)
	writer.store_string(contents.replace('"version": 1','"version": 999'))
	writer.close()
	check(saves.info(1).state=="corrupt" and not saves.load(1,restored),"tampered version/digest rejected")
	check(restored.export_save_data()==current,"invalid file did not mutate loaded session")
	# Martial tiers and exclusive 4th-rank traits affect the actual battle stats.
	var mastered: Dictionary=Martial.new().create_record(4)
	check(Martial.new().unlock_trait_record(mastered,"taixu","thunder_break"),"rank four selects a real trait")
	check(not Martial.new().unlock_trait_record(mastered,"taixu","flowing_qi"),"exclusive branch blocks second trait")
	var baseline=Model.new()
	baseline.reset(2026,0,"tingfeng")
	var advanced=Model.new()
	advanced.reset(2026,0,"tingfeng",{"martial_progressions":{0:{"taixu":mastered}}})
	check(advanced.state.outcome=="playing","advanced martial record is valid")
	check(advanced.state.get_actor(0).stats.break_power>baseline.state.get_actor(0).stats.break_power,"martial trait modifies combat-derived stats")
	check(advanced.state.get_actor(0).stats.qi_cost_percent<baseline.state.get_actor(0).stats.qi_cost_percent,"rank four improves martial cost")
	for path_scene in ["res://inventory.tscn","res://martial_hall.tscn","res://save_slots.tscn"]:
		check(load(path_scene)!=null,"interactive scene parses: "+path_scene)
	saves.delete(1)
	session.queue_free()
	restored.queue_free()
	print("SAVE INVENTORY MARTIAL: ",failures," failures")
	quit(1 if failures>0 else 0)
