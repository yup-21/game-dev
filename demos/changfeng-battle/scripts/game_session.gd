extends Node
## Persistent glue between opening story, the existing combat engine and aftermath.
## Stores demo-only progress; never replaces BattleModel, card zones or CTB.
const ScenarioDirector = preload("res://scripts/scenario_director.gd")
const CharacterProgress = preload("res://scripts/character_progression.gd")
const MartialProgress = preload("res://scripts/martial_progression.gd")
const Inventory = preload("res://scripts/inventory_system.gd")
const Saves = preload("res://scripts/save_system.gd")
var director=ScenarioDirector.new()
var phase: String="menu"
var chapter_id: String=""
var choices: Array=[]
var flags: Dictionary={}
var items: Dictionary={}
var encounter_id: String=""
var battle_outcome: String=""
var winning_team: int=-1
var injury_stacks: int=0
var aftercare: String=""
var character_records: Dictionary={}
var martial_records: Dictionary={}
var training_awarded: bool=false
var persistent_states: Dictionary={}
var inventories: Dictionary={}
var opening_checkpoint: Dictionary={}
var management_history: Array=[]
func open_management(from_scene: String) -> void:
	if from_scene in ["res://opening.tscn","res://study.tscn","res://demo_result.tscn","res://martial_hall.tscn","res://inventory.tscn","res://save_slots.tscn"]:
		management_history.append(from_scene)
		if management_history.size()>12: management_history.pop_front()

func return_from_management() -> String:
	if management_history.is_empty(): return "res://opening.tscn"
	return str(management_history.pop_back())
var save_message: String=""

func start_new_game() -> void:
	phase="story"
	chapter_id="rain_escort_prologue"
	choices.clear()
	flags.clear()
	items.clear()
	encounter_id=""
	battle_outcome=""
	winning_team=-1
	injury_stacks=0
	aftercare=""
	training_awarded=false
	character_records={0:CharacterProgress.new().create_record()}
	martial_records.clear()
	persistent_states.clear()
	inventories={0:Inventory.new().starter_record()}
	opening_checkpoint.clear()
	management_history.clear()

func study_fragment() -> bool:
	if phase!="story" or not items.has("taixu_fragment"): return false
	flags["studied_fragment"]=true
	if not martial_records.has(0): martial_records[0]={}
	if not martial_records[0].has("taixu"): martial_records[0]["taixu"]=MartialProgress.new().create_record()
	return true

func record_choice(node_id: String, option_id: int) -> void:
	if phase!="story": return
	choices.append({"node_id":node_id,"option":option_id})
	flags["helped_escort"]=option_id==0 if node_id=="escort_urgent" else flags.get("helped_escort",false)

func record_story_event(event_id: String) -> void:
	if phase!="story": return
	if event_id=="obtain_fragment":
		flags["obtained_fragment"]=true
		items["taixu_fragment"]=1
		if inventories.has(0) and Inventory.new().count(inventories[0],"taixu_scroll")==0:
			Inventory.new().add(inventories[0],"taixu_scroll",1)

func begin_encounter(id: String="escort_ambush") -> bool:
	if phase!="story" or not bool(flags.get("obtained_fragment",false)) or director.encounter(id).is_empty(): return false
	phase="battle"
	encounter_id=id
	battle_outcome=""
	winning_team=-1
	return true

func encounter_options() -> Dictionary:
	if phase!="battle": return {}
	var options: Dictionary=director.battle_options(encounter_id)
	if injury_stacks>0: options["initial_statuses"]={0:{"meridian_wound":injury_stacks}}
	options["character_progressions"]=character_records.duplicate(true)
	options["martial_progressions"]=martial_records.duplicate(true)
	options["persistent_states"]=persistent_states.duplicate(true)
	options["inventories"]=inventories.duplicate(true)
	return options

func encounter_seed() -> int:
	return int(director.encounter(encounter_id).get("seed",2026))

func capture_battle_progress(model) -> void:
	if phase!="battle" or model==null: return
	for actor in model.state.actors:
		if actor.team_id!=0: continue
		character_records[actor.id]=CharacterProgress.new().export_record(actor)
		martial_records[actor.id]=MartialProgress.new().export_records(actor)
		persistent_states[actor.id]=model.statuses.export_persistent(actor.id)
		persistent_states[actor.id].erase("meridian_wound")
		if model.inventory_records.has(actor.id):
			inventories[actor.id]=model.inventory_records[actor.id].duplicate(true)

func add_loot(actor_id: int,item_id: String,count: int=1) -> bool:
	if phase not in ["story","aftermath","complete"] or not inventories.has(actor_id): return false
	return Inventory.new().add(inventories[actor_id],item_id,count)

func equip_item(actor_id: int,item_id: String,slot: String) -> bool:
	if phase not in ["story","aftermath","complete"] or not inventories.has(actor_id): return false
	return Inventory.new().equip(inventories[actor_id],item_id,slot)

func unequip_item(actor_id: int,slot: String) -> bool:
	if phase not in ["story","aftermath","complete"] or not inventories.has(actor_id): return false
	return Inventory.new().unequip(inventories[actor_id],slot)

func use_field_item(actor_id: int,item_id: String) -> bool:
	if phase not in ["story","aftermath","complete"] or actor_id!=0 or not inventories.has(actor_id): return false
	var catalog=Inventory.new()
	var effect: Dictionary=catalog.item(item_id).get("use",{})
	if str(effect.get("kind",""))!="remove_status" or str(effect.get("status_id",""))!="meridian_wound" or injury_stacks<=0: return false
	if not catalog.remove(inventories[actor_id],item_id,1): return false
	injury_stacks=maxi(0,injury_stacks-1)
	if injury_stacks==0:
		flags["healed_injury"]=true
		if persistent_states.has(actor_id): persistent_states[actor_id].erase("meridian_wound")
	return true

func allocate_training_point(stat: String) -> bool:
	if phase not in ["aftermath","complete"] or not character_records.has(0): return false
	return CharacterProgress.new().allocate_record(character_records[0],{"STR":10,"AGI":10,"CON":10,"MND":10},stat,1)

func breakthrough_taixu() -> bool:
	if phase not in ["aftermath","complete"] or not martial_records.has(0) or not martial_records[0].has("taixu"): return false
	return MartialProgress.new().breakthrough_record(martial_records[0]["taixu"])

func choose_martial_trait(id: String,trait_id: String) -> bool:
	if phase not in ["aftermath","complete","story"] or not martial_records.has(0) or not martial_records[0].has(id): return false
	return MartialProgress.new().unlock_trait_record(martial_records[0][id],id,trait_id)

func breakthrough_martial(id: String) -> bool:
	if phase not in ["aftermath","complete"] or not martial_records.has(0) or not martial_records[0].has(id): return false
	return MartialProgress.new().breakthrough_record(martial_records[0][id])

func report_battle(outcome: String, team: int) -> bool:
	if phase!="battle" or outcome not in ["victory","defeat","draw"]: return false
	battle_outcome=outcome
	winning_team=team
	if outcome=="victory" and not training_awarded:
		training_awarded=true
		var record: Dictionary=character_records.get(0,CharacterProgress.new().create_record())
		record.earned_points=int(record.get("earned_points",0))+1
		record.unspent_points=int(record.get("unspent_points",0))+1
		character_records[0]=record
		if martial_records.has(0) and martial_records[0].has("taixu"):
			var martial_record: Dictionary=martial_records[0]["taixu"]
			martial_record.xp=mini(1000000,int(martial_record.xp)+50)
	phase="aftermath"
	# The scripted rainy-night overexertion introduces one persistent injury tag.
	injury_stacks=maxi(injury_stacks,1)
	aftercare=""
	return true

func choose_aftercare(choice: String) -> bool:
	if phase!="aftermath" or not aftercare.is_empty() or choice not in ["rest","pursue"]: return false
	aftercare=choice
	if choice=="rest":
		injury_stacks=0
		if persistent_states.has(0): persistent_states[0].erase("meridian_wound")
		flags["healed_injury"]=true
		if bool(flags.get("helped_escort",false)): flags["escort_healing_hint"]=true
	else:
		# A visible battle penalty, without revealing a life counter.
		flags["pursued_early"]=true
		if not bool(flags.get("helped_escort",false)): flags["pursuer_token_clue"]=true
	return true

func retry_encounter() -> bool:
	if phase!="aftermath" or encounter_id.is_empty(): return false
	phase="battle"
	battle_outcome=""
	winning_team=-1
	aftercare=""
	return true

func finish_demo() -> bool:
	if phase!="aftermath" or aftercare.is_empty(): return false
	phase="complete"
	return true

func return_to_menu() -> void:
	phase="menu"

## Save only explicit persistent game data. Live CTB/clash snapshots are intentionally excluded.
func export_save_data() -> Dictionary:
	if phase not in ["story","aftermath","complete"]: return {}
	return {"phase":phase,"chapter_id":chapter_id,"choices":choices.duplicate(true),
		"flags":flags.duplicate(true),"items":items.duplicate(true),"encounter_id":encounter_id,
		"battle_outcome":battle_outcome,"winning_team":winning_team,"injury_stacks":injury_stacks,
		"aftercare":aftercare,"training_awarded":training_awarded,
		"character_records":character_records.duplicate(true),"martial_records":martial_records.duplicate(true),
		"persistent_states":persistent_states.duplicate(true),"inventories":inventories.duplicate(true),
		"opening_checkpoint":opening_checkpoint.duplicate(true)}

func _valid_actor_keys(value: Variant) -> bool:
	if not value is Dictionary or value.size()>8: return false
	for key in value:
		var name: String=str(key)
		if not name.is_valid_int() or int(name)<0 or int(name)>1023: return false
	return true

func _actor_map(value: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for key in value: result[int(str(key))]=value[key].duplicate(true)
	return result

func validate_save_data(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=16: return false
	if data.get("phase","") not in ["story","aftermath","complete"]: return false
	if data.get("chapter_id","")!="rain_escort_prologue": return false
	if not data.get("choices") is Array or data.choices.size()>64: return false
	if not data.get("flags") is Dictionary or not data.get("items") is Dictionary: return false
	if not data.get("encounter_id") is String or not data.get("battle_outcome") is String: return false
	if data.battle_outcome not in ["","victory","defeat","draw"]: return false
	if not data.get("winning_team") is int or int(data.winning_team) not in [-1,0,1]: return false
	if not data.get("injury_stacks") is int or int(data.injury_stacks)<0 or int(data.injury_stacks)>3: return false
	if data.get("aftercare","") not in ["","rest","pursue"]: return false
	if not data.get("training_awarded") is bool: return false
	if not data.get("opening_checkpoint") is Dictionary: return false
	if data.opening_checkpoint.size()>8: return false
	if data.opening_checkpoint.has("phase") and data.opening_checkpoint.phase not in ["menu","cinematic","explore","dialogue","complete"]: return false
	for field in ["character_records","martial_records","persistent_states","inventories"]:
		if not _valid_actor_keys(data.get(field)): return false
	var characters: Dictionary=data.character_records
	for record in characters.values():
		if not CharacterProgress.new().valid(record): return false
	for records in data.martial_records.values():
		if not records is Dictionary or records.size()>40: return false
		for rec in records.values():
			if not MartialProgress.new().valid(rec): return false
	for records in data.persistent_states.values():
		if not records is Dictionary or records.size()>64: return false
		for key in records:
			var entry: Variant=records[key]
			if not entry is Dictionary or not entry.get("stacks") is int or int(entry.stacks)<1 or int(entry.stacks)>1000: return false
	var inventory=Inventory.new()
	if not inventory.load_error.is_empty(): return false
	for record in data.inventories.values():
		if not inventory.valid(record): return false
	return true

func import_save_data(data: Dictionary) -> bool:
	if not validate_save_data(data): return false
	phase=str(data.phase)
	chapter_id=str(data.chapter_id)
	choices=data.choices.duplicate(true)
	flags=data.flags.duplicate(true)
	items=data.items.duplicate(true)
	encounter_id=str(data.encounter_id)
	battle_outcome=str(data.battle_outcome)
	winning_team=int(data.winning_team)
	injury_stacks=int(data.injury_stacks)
	aftercare=str(data.aftercare)
	training_awarded=bool(data.training_awarded)
	character_records=_actor_map(data.character_records)
	martial_records=_actor_map(data.martial_records)
	persistent_states=_actor_map(data.persistent_states)
	inventories=_actor_map(data.inventories)
	opening_checkpoint=data.opening_checkpoint.duplicate(true)
	return true

func save_game(slot: int) -> bool:
	var saves=Saves.new()
	var ok: bool=saves.save(slot,self)
	save_message="存档成功" if ok else saves.last_error
	return ok

func load_game(slot: int) -> bool:
	var saves=Saves.new()
	var ok: bool=saves.load(slot,self)
	save_message="读档成功" if ok else saves.last_error
	return ok

func resume_scene() -> String:
	match phase:
		"story":
			if items.has("taixu_fragment"): return "res://study.tscn"
			return "res://opening.tscn"
		"aftermath","complete": return "res://demo_result.tscn"
	return "res://opening.tscn"
