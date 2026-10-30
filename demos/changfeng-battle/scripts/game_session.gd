extends Node
## Persistent glue between opening story, the existing combat engine and aftermath.
## Stores demo-only progress; never replaces BattleModel, card zones or CTB.
const ScenarioDirector = preload("res://scripts/scenario_director.gd")
var director=ScenarioDirector.new()
var phase: String="menu"
var chapter_id: String=""
var choices: Array=[]
var flags: Dictionary={}
var items: Dictionary={}
var encounter_id: String=""
var battle_outcome: String=""
var winning_team: int=-1
## Game-session preference: preserved across story scenes and encounter retries.
var battle_spatial_mode: String="GRID"

func start_new_game() -> void:
	phase="story"
	chapter_id="rain_escort_prologue"
	choices.clear()
	flags.clear()
	items.clear()
	encounter_id=""
	battle_outcome=""
	winning_team=-1

func record_choice(node_id: String, option_id: int) -> void:
	if phase!="story": return
	choices.append({"node_id":node_id,"option":option_id})
	flags["helped_escort"]=option_id==0 if node_id=="escort_urgent" else flags.get("helped_escort",false)

func record_story_event(event_id: String) -> void:
	if phase!="story": return
	if event_id=="obtain_fragment":
		flags["obtained_fragment"]=true
		items["taixu_fragment"]=1

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
	options["spatial_mode"]=battle_spatial_mode
	return options

func set_battle_spatial_mode(next_mode: String) -> bool:
	if next_mode not in ["GRID","FREE"]: return false
	battle_spatial_mode=next_mode
	return true

func encounter_seed() -> int:
	return int(director.encounter(encounter_id).get("seed",2026))

func report_battle(outcome: String, team: int) -> bool:
	if phase!="battle" or outcome not in ["victory","defeat","draw"]: return false
	battle_outcome=outcome
	winning_team=team
	phase="aftermath"
	return true

func retry_encounter() -> bool:
	if phase!="aftermath" or encounter_id.is_empty(): return false
	phase="battle"
	battle_outcome=""
	winning_team=-1
	return true

func finish_demo() -> bool:
	if phase!="aftermath": return false
	phase="complete"
	return true

func return_to_menu() -> void:
	phase="menu"
