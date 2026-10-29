extends SceneTree
## End-to-end encounter wiring and chapter ownership, without graphical inputs.
const Session = preload("res://scripts/game_session.gd")
const Story = preload("res://scripts/opening_story.gd")
const Model = preload("res://scripts/battle_model.gd")
const Director = preload("res://scripts/scenario_director.gd")
var failures: int=0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> bool:
	if ok: print("PASS ",message)
	else:
		failures+=1
		push_error("FAIL "+message)
	return ok

func finish(session) -> void:
	print("DEMO FLOW FAILURES: ",failures)
	session.free()
	quit(1 if failures>0 else 0)

func load_numeric_catalog(entry: Dictionary):
	var path: String="user://demo_flow_numeric_test.json"
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		check(false,"numeric test catalog can be written")
		return null
	file.store_string(JSON.stringify({"schema_version":1,"encounters":[entry]}))
	file.close()
	var director=Director.new(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return director

func check_numeric_catalog(director) -> void:
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_scenario.json")).encounters[0]
	var normalized: Dictionary=director.encounter(str(original.id))
	check(original.seed is float and normalized.seed is int and normalized.seed==2026,"JSON seed is normalized without changing its value")
	var integers: bool=true
	for actor in director.battle_options(str(original.id)).combatants:
		integers=integers and actor.id is int and actor.team_id is int and actor.cell[0] is int and actor.cell[1] is int
	check(integers,"JSON actor IDs, teams and coordinates become integers")
	for value in [0,-2026]:
		var entry: Dictionary=original.duplicate(true)
		entry.seed=value
		var accepted=load_numeric_catalog(entry)
		check(accepted!=null and accepted.load_error.is_empty() and accepted.encounter(str(entry.id)).seed==value,"integer seed accepted: "+str(value))
	check(director._valid_integer(-9223372036854775808.0),"minimum int64 float can be normalized")
	check(not director._valid_integer(9223372036854775808.0),"float at int64 upper limit is rejected before conversion")
	for value in [NAN,INF,-INF]:
		check(not director._valid_integer(value),"non-finite numeric value rejected: "+str(value))
	var cases: Array=[
		[0.5,"fraction"],[-0.5,"negative fraction"],
		["2","numeric string"],[true,"boolean"],[null,"null"],
		[[],"array"],[{},"dictionary"],
		[1e20,"positive overflow"],[-1e20,"negative overflow"],
	]
	for test_case in cases:
		var unexpected: Array=[]
		for field in ["seed","id","team_id","cell_x","cell_y"]:
			var entry: Dictionary=original.duplicate(true)
			if field=="seed": entry.seed=test_case[0]
			elif field in ["id","team_id"]: entry.combatants[0][field]=test_case[0]
			else: entry.combatants[0].cell[0 if field=="cell_x" else 1]=test_case[0]
			var rejected=load_numeric_catalog(entry)
			if rejected==null or rejected.load_error.is_empty() or not rejected.encounter(str(entry.id)).is_empty(): unexpected.append(field)
		check(unexpected.is_empty(),"JSON rejects "+test_case[1]+" in all integer fields: "+str(unexpected))
	var overlapping: Dictionary=original.duplicate(true)
	overlapping.combatants[1].cell=overlapping.combatants[0].cell.duplicate()
	var semantic=load_numeric_catalog(overlapping)
	check(semantic!=null and semantic.load_error.is_empty(),"scenario normalization leaves battle rules to BattleModel")
	if semantic!=null and semantic.load_error.is_empty():
		var game=Model.new()
		game.reset(int(semantic.encounter(str(original.id)).seed),0,"tingfeng",semantic.battle_options(str(original.id)))
		check(game.state.mode=="FINISHED" and not game.state.party_error.is_empty(),"BattleModel rejects overlapping JSON spawn cells")

func _run() -> void:
	var session=Session.new()
	root.add_child(session)
	var story=Story.new()
	if not check(session.director.load_error.is_empty(),"encounter data validates"):
		finish(session)
		return
	check(session.phase=="menu" and not session.begin_encounter(),"menu cannot bypass the story")
	session.start_new_game()
	check(session.phase=="story" and session.items.is_empty(),"new game clears old progress")
	session.record_choice("escort_urgent",0)
	check(bool(session.flags.get("helped_escort",false)),"dialogue decision is tracked")
	story.begin()
	story.skip_cinematic()
	check(story.interact(),"can speak after cutscene")
	for _i in range(20):
		if story.phase!="dialogue": break
		if not story.current_dialogue().get("choices",[]).is_empty():
			check(story.choose(0),"choose to aid escort")
		else:
			story.advance_dialogue()
		if story.obtained_fragment: session.record_story_event("obtain_fragment")
	check(story.phase=="complete" and session.items.get("taixu_fragment",0)==1,"story reward persists")
	if not check(session.begin_encounter(),"chapter can launch its encounter"):
		finish(session)
		return
	var config: Dictionary=session.encounter_options()
	check(config.get("combatants",[]).size()==6,"story owns its six-character roster")
	var game=Model.new()
	game.reset(session.encounter_seed(),0,"tingfeng",config)
	check(game.state.actors.size()==6 and game.state.outcome=="playing","same BattleModel starts story encounter")
	check(session.report_battle("victory",0),"match result recorded")
	check(session.phase=="aftermath" and session.battle_outcome=="victory","aftermath available")
	check(session.retry_encounter(),"retry remains in chapter")
	check(session.items.get("taixu_fragment",0)==1 and session.phase=="battle","retry retains story progress")
	check(session.report_battle("defeat",1),"defeat has same aftermath contract")
	check(session.finish_demo() and session.phase=="complete","demo may reach closing credits")
	session.return_to_menu()
	session.start_new_game()
	check(session.items.is_empty() and session.choices.is_empty(),"new game has no stale fragment or decisions")
	check(load("res://opening.tscn")!=null and load("res://demo_result.tscn")!=null,"entry / ending scenes resolve")
	check_numeric_catalog(session.director)
	finish(session)
