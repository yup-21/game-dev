extends SceneTree
const StoryFixture = preload("res://checks/story_test_helper.gd")
## End-to-end encounter wiring and chapter ownership, without graphical inputs.
const Session = preload("res://scripts/game_session.gd")
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

func check_numeric_catalog(director) -> void:
    var original: Dictionary = director.encounter("escort_ambush")
    check(not original.is_empty(), "typed encounter exists")
    check(original.seed is int and original.seed == 2026,
        "native Resource preserves integer encounter seed")
    var valid: bool = true
    for actor in director.battle_options("escort_ambush").get("combatants", []):
        valid = valid and actor.id is int and actor.team_id is int
        valid = valid and actor.cell[0] is int and actor.cell[1] is int
    check(valid, "typed actor IDs, teams and coordinates are integers")
    for value in [0,-2026]:
        var entry: Dictionary = original.duplicate(true)
        entry.id = "r41_numeric_" + str(absi(value))
        entry.seed = value
        var accepted = Director.new()
        check(accepted._register_entry(entry) and accepted.encounter(str(entry.id)).seed == value,
            "integer seed accepted: " + str(value))
    check(director._valid_integer(-9223372036854775808.0),
        "minimum int64 normalized")
    check(not director._valid_integer(9223372036854775808.0),
        "upper int64 rejected")
    for value in [NAN, INF, -INF, 0.5, "2", true]:
        check(not director._valid_integer(value),
            "invalid numeric content rejected")
    var overlapping: Dictionary = original.duplicate(true)
    overlapping.id = "r41_overlap"
    overlapping.combatants[1].cell = overlapping.combatants[0].cell.duplicate()
    var semantic = Director.new()
    check(semantic._register_entry(overlapping),
        "encounter schema validates independently of combat rules")
    var game = Model.new()
    game.reset(int(overlapping.seed),0,"tingfeng",
        semantic.battle_options("r41_overlap"))
    check(game.state.mode=="FINISHED" and not game.state.party_error.is_empty(),
        "BattleModel rejects overlapping authored spawn cells")

func _run() -> void:
	var session=Session.new()
	root.add_child(session)
	if not check(session.director.load_error.is_empty(),"encounter data validates"):
		finish(session)
		return
	check(session.phase=="menu" and not session.begin_encounter(),"menu cannot bypass the story")
	session.start_new_game()
	check(session.phase=="story" and session.items.is_empty(),"new game clears old progress")
	check(StoryFixture.finish_prologue(session,0),"authored dialogue completes")
	check(bool(session.flags.get("helped_escort",false))
		and session.choices.size()==1,"dialogue decision is tracked through emitted events")
	check(session.items.get("taixu_fragment",0)==1
		and bool(session.flags.get("obtained_fragment",false)),"story reward persists")
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
