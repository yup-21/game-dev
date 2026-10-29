extends SceneTree
## End-to-end encounter wiring and chapter ownership, without graphical inputs.
const Session = preload("res://scripts/game_session.gd")
const Story = preload("res://scripts/opening_story.gd")
const Model = preload("res://scripts/battle_model.gd")
var failures: int=0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok: print("PASS ",message)
	else:
		failures+=1
		push_error("FAIL "+message)

func _run() -> void:
	var session=Session.new()
	root.add_child(session)
	var story=Story.new()
	check(session.director.load_error.is_empty(),"encounter data validates")
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
	check(session.begin_encounter(),"chapter can launch its encounter")
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
	print("DEMO FLOW FAILURES: ",failures)
	session.queue_free()
	quit(1 if failures>0 else 0)
