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
var remaining_life_months: int=720 # Demonstration starting budget, not full character lifespan simulation.
var elapsed_months: int=0
var injury_stacks: int=0
var aftercare: String=""

func start_new_game() -> void:
	phase="story"
	chapter_id="rain_escort_prologue"
	choices.clear()
	flags.clear()
	items.clear()
	encounter_id=""
	battle_outcome=""
	winning_team=-1
	remaining_life_months=720
	elapsed_months=0
	injury_stacks=0
	aftercare=""

func study_fragment() -> bool:
	if phase!="story" or not items.has("taixu_fragment"): return false
	flags["studied_fragment"]=true
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

func begin_encounter(id: String="escort_ambush") -> bool:
	if phase!="story" or not bool(flags.get("obtained_fragment",false)) or director.encounter(id).is_empty(): return false
	phase="battle"
	encounter_id=id
	battle_outcome=""
	winning_team=-1
	return true

func encounter_options() -> Dictionary:
	return director.battle_options(encounter_id) if phase=="battle" else {}

func encounter_seed() -> int:
	return int(director.encounter(encounter_id).get("seed",2026))

func report_battle(outcome: String, team: int) -> bool:
	if phase!="battle" or outcome not in ["victory","defeat","draw"]: return false
	battle_outcome=outcome
	winning_team=team
	phase="aftermath"
	# The scripted rainy-night overexertion introduces one persistent injury tag.
	injury_stacks=maxi(injury_stacks,1)
	aftercare=""
	return true

func choose_aftercare(choice: String) -> bool:
	if phase!="aftermath" or not aftercare.is_empty() or choice not in ["rest","pursue"]: return false
	aftercare=choice
	if choice=="rest":
		var delay: int=1 if bool(flags.get("helped_escort",false)) else 2
		elapsed_months+=delay
		remaining_life_months=maxi(0,remaining_life_months-delay)
		injury_stacks=0
		flags["healed_injury"]=true
	else:
		elapsed_months+=1
		remaining_life_months=maxi(0,remaining_life_months-(1+injury_stacks*3))
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
