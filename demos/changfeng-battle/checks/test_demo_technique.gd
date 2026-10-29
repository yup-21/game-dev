extends SceneTree
## Real BattleModel rule-path test for the demo's generated attack chain.
const Session=preload("res://scripts/game_session.gd")
const Model=preload("res://scripts/battle_model.gd")
var failures: int=0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool,label: String) -> void:
	if not ok:
		failures+=1
		push_error("FAIL "+label)
	else: print("PASS "+label)

func _play(model,uid: String) -> bool:
	if model.state.animation_pending: model.acknowledge_animation(model.state.animation_ticket)
	for option in model.legal_actions(0):
		if str(option.get("kind",""))=="PLAY_CARD" and str(option.get("card_uid",""))==uid:
			var result: Dictionary=model.submit(model.request("PLAY_CARD",0,option))
			return bool(result.get("success",false))
	return false

func _finish(model) -> bool:
	for _i in range(5):
		if model.state.mode!="CLASH": break
		if model.state.animation_pending: model.acknowledge_animation(model.state.animation_ticket)
		var id: int=int(model.state.clash.priority_actor_id)
		var req: Dictionary={}
		for option in model.legal_actions(id):
			if option.kind=="PASS_REACTION": req=option; break
		if req.is_empty(): return false
		if not bool(model.submit(model.request("PASS_REACTION",id,req)).get("success",false)): return false
	if model.state.animation_pending: model.acknowledge_animation(model.state.animation_ticket)
	return model.state.mode=="ACTION"

func _find(actor,cards,id: String) -> String:
	for uid in actor.hand:
		if str(cards.instance(uid).get("definition_id",""))==id: return str(uid)
	return ""

func _run() -> void:
	var session=Session.new()
	root.add_child(session)
	session.start_new_game()
	check(not session.study_fragment(),"cannot study before obtaining the scroll")
	session.record_choice("escort_urgent",0)
	session.record_story_event("obtain_fragment")
	check(session.study_fragment() and bool(session.flags.studied_fragment),"fragment unlock recorded")
	check(session.begin_encounter(),"study leads to encounter")
	var model=Model.new()
	var options: Dictionary=session.encounter_options()
	check(options.get("card_definitions",[]).size()==3,"three generated-card definitions registered")
	model.reset(session.encounter_seed(),0,"tingfeng",options)
	check(model.state.outcome=="playing" and model.state.actors.size()==6,"shared battle model starts")
	var actor=model.state.get_actor(0)
	actor.cell=Vector2i(7,4)
	model.state.get_actor(1).cell=Vector2i(8,4)
	actor.qi_u=60000
	var first: String=model.cards.create_instance(actor,"taixu_open","hand")
	check(not first.is_empty(),"learned root card is granted in hand")
	check(_play(model,first),"play root via legal card action")
	check(_finish(model),"root attack resolves")
	var second: String=_find(actor,model.cards,"taixu_follow")
	check(not second.is_empty(),"root hit generates follow-up")
	if not second.is_empty():
		check(str(model.cards.relations(second).get("parent_uid",""))==first,"generated card knows parent")
		check(_play(model,second),"play follow-up through same validator")
		check(_finish(model),"follow-up resolves")
	var third: String=_find(actor,model.cards,"taixu_final")
	check(not third.is_empty(),"follow-up hit generates final card")
	if not third.is_empty():
		check(_play(model,third),"play finisher")
		check(_finish(model),"finisher resolves")
		check(actor.exile_pile.has(third) and not actor.draw_pile.has(third),"temporary finisher is exiled")
	if not second.is_empty():
		check(actor.exile_pile.has(second),"follow-up is exiled after use")
	check(session.report_battle("victory",0),"battle outcome reaches aftermath")
	check(int(session.injury_stacks)==1,"rain battle inflicts one demo injury")
	check(session.choose_aftercare("rest"),"healing is available")
	check(session.injury_stacks==0 and session.remaining_life_months==719,"prior rescue reduces healing time to one month")
	check(not session.choose_aftercare("pursue"),"aftercare decision can only occur once")
	check(session.finish_demo(),"resolved aftermath concludes demo")
	session.return_to_menu()
	session.start_new_game()
	session.record_choice("escort_urgent",1)
	session.record_story_event("obtain_fragment")
	check(session.begin_encounter(),"asking who attacked still progresses without mandatory study")
	check(session.report_battle("victory",0),"alternate branch battle resolves")
	check(session.choose_aftercare("pursue"),"injured hero can pursue the clue")
	check(session.injury_stacks==1 and session.remaining_life_months==716,"pursuit exact 4-month cost")
	check(bool(session.flags.get("pursuer_token_clue",false)),"questioning route yields pursuer's token")
	print("DEMO TECHNIQUE FAILURES: ",failures)
	session.queue_free()
	quit(1 if failures>0 else 0)
