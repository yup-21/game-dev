extends RefCounted
## Only loaded by --tingfeng-visual-check. Fixtures never enter normal play.
var ui
var checks = 0

func run(view) -> void:
	ui = view
	ui.next_decision = 1.0e30
	await _frames(2)
	ui._send_key(KEY_ENTER)
	await _frames(2)
	if not _ok(ui.started,"Enter starts the real battle view"): return
	if not _ok(ui.snap.terrain.size()==150,"original 15 x 10 board retained"): return
	if not _ok(ui.snap.phase=="ACTION","default mode is CTB free ACTION"): return
	await _save_capture("tingfeng-action.png")
	var old_battle: String = ui.snap.battle_id
	await _click_action("passive:0:insight")
	await _click_action("passive:1:conceal")
	await _click_action("restart")
	ui.next_decision = 1.0e30
	await _drain()
	if not _ok(ui.snap.battle_id!=old_battle and ui.passive_settings[0].insight==1 and ui.passive_settings[1].conceal==1,"passive selectors and actual restart button"): return
	_fixture(0)
	await _frames(2)
	var visible_before: int=ui._visible_logs().size()
	var raw_before: int=ui.model.state.logs.size()
	ui.model.state.logs.append({"type":"QA_SEMANTIC_ONLY"})
	ui._sync()
	if not _ok(ui._visible_logs().size()==visible_before and ui.model.state.logs.size()==raw_before+1,"empty-text log events are hidden without deleting semantic history"): return
	for i in range(12): ui.model.state.logs.append({"type":"QA_LINE","text":"UI滚动检查 %d" % i})
	ui._sync()
	await _frames(2)
	ui._click(Vector2(1300,850),MOUSE_BUTTON_WHEEL_UP)
	await _frames(2)
	if not _ok(ui.log_scroll==2,"mouse wheel scrolls filtered visible log lines"): return
	_fixture(0)
	await _frames(2)
	var move = _legal(0,"MOVE")
	if not _ok(not move.is_empty(),"normal movement available"): return
	if not await _ui_action(move): return
	if not _ok(ui.snap.actors[0].cell==move.target_cell,"real board click moves actor"): return
	_fixture(0)
	await _frames(2)
	_fixture(0,30)
	ui.model.state.actors[0].qi_u=8000
	ui._sync()
	var discounted_card: Dictionary={}
	for card in ui.snap.hand:
		if card.get("definition_id","")=="tf_guard": discounted_card=card
	var discounted_usage: Dictionary=ui._usage(discounted_card,"guard")
	if not _ok(float(ui._quoted_cost(discounted_usage).qi)<float(discounted_usage.cost.qi),"MND-discounted quote overrides base card cost"): return
	if not _ok(ui._usage_reason(discounted_card,discounted_usage).contains("0.9"),"insufficient qi explains actual discounted price"): return
	ui.model.state.actors[0].qi_u=9000
	ui._sync()
	await _frames(2)
	await _click_action("card:"+ui._uid(discounted_card))
	await _save_capture("tingfeng-discounted-cost.png")
	await _click_action("cancel")
	if not await _ui_action(_legal(0,"PLAY_CARD","guard")): return
	if not _ok(is_zero_approx(float(ui.snap.actors[0].qi)),"UI discounted branch pays displayed 0.9 qi"): return
	_fixture(0)
	await _frames(2)
	var guard_uid: String=""
	for card in ui.snap.hand:
		if card.get("definition_id","")=="tf_guard": guard_uid=ui._uid(card)
	ui.model.state.actors[0].qi_u=0
	ui._sync()
	await _frames(2)
	await _click_action("card:"+guard_uid)
	if not _ok(ui.usage_choices.size()==3,"unaffordable card still exposes all three uses"): return
	var disabled_reason: String=""
	for button in ui.buttons:
		if str(button.action)=="usage:guard": disabled_reason=str(button.get("reason",""))
	if not _ok(disabled_reason.begins_with("气不足"),"disabled branch explains insufficient qi"): return
	await _save_capture("tingfeng-insufficient-qi.png")
	await _click_action("cancel")
	_fixture(0)
	await _frames(2)
	var probe = _legal(0,"PLAY_CARD","probe")
	if not _ok(not probe.is_empty(),"fixture exposes probe legal usage"): return
	await _click_action("card:"+str(probe.get("card_uid",probe.get("card_id",""))))
	if not _ok(ui.usage_choices.size()==2,"same hand card opens both probe branches"): return
	await _save_capture("tingfeng-branches.png")
	await _click_action("cancel")
	if not _ok(ui.usage_choices.is_empty(),"branch picker cancels without playing"): return
	# A main-action move and self-target branch are routed through the same UI.
	if not await _ui_action(_legal(0,"PLAY_CARD","step")): return
	_fixture(0)
	await _frames(2)
	if not await _ui_action(_legal(0,"PLAY_CARD","guard")): return
	if not _ok(float(ui.snap.actors[0].shield)>0,"selected guard usage creates shield"): return
	_fixture(0)
	await _frames(2)
	if not await _ui_action(_legal(0,"PLAY_CARD","probe")): return
	if not _ok(ui.snap.phase=="CLASH" and ui._decision_actor()==1,"attack opens defender priority"): return
	if not _ok(ui._attack_cells()==ui.snap.attack.affected_cells and not ui._attack_cells().is_empty(),"CLASH overlay consumes authoritative affected cells"): return
	var response = _legal(1,"PLAY_CARD","yield")
	if not _ok(not response.is_empty(),"enemy has legal defense response"): return
	ui._consume(ui.model.submit(response))
	await _drain()
	if not _ok(ui._decision_actor()==0,"response alternates priority to player"): return
	var counter = _legal(0,"PLAY_CARD","attack_counter")
	if not _ok(not counter.is_empty() and counter.has("link_id"),"counter exposes selectable response link"): return
	if not await _ui_action(counter): return
	if not _ok(ui.snap.get("clash",{}).get("stack",[]).size()>=2,"real UI builds LIFO response stack"): return
	await _save_capture("tingfeng-clash.png")
	await _enemy_pass()
	if ui.snap.phase=="CLASH" and ui._decision_actor()==0:
		if not await _ui_action(_legal(0,"PASS_REACTION")): return
	await _finish_clash()
	if not _ok(ui.snap.phase=="ACTION","consecutive Pass resolves stack back to ACTION"): return
	# A fresh enemy attack lets the player select a defensive evasion destination.
	_fixture(1)
	await _frames(2)
	var attack = _legal(1,"BASIC_ATTACK")
	if not _ok(not attack.is_empty(),"enemy basic attack available"): return
	ui._consume(ui.model.submit(attack))
	await _drain()
	var evade = _legal(0,"PLAY_CARD","evasion")
	if not _ok(not evade.is_empty(),"defensive evasion legal target generated"): return
	if not await _ui_action(evade): return
	await _finish_clash()
	if not _ok(ui.snap.actors[0].cell==evade.target_cell,"defensive UI destination applied during LIFO resolution"): return
	_fixture(0)
	await _frames(2)
	if not await _ui_action(_legal(0,"BASIC_GUARD")): return
	if not await _ui_action(_legal(0,"PITCH_CARD")): return
	if not await _ui_action(_legal(0,"END_ACTION")): return
	if not _ok(ui.snap.active_id==1,"end action hands the CTB turn to next actor"): return
	# Isolated low-HP terminal fixture verifies the real input/result/restart flow.
	_fixture(0)
	ui.model.state.actors[1].hp_u=10000
	ui.model.state.actors[1].qi_u=0
	ui.model.state.actors[1].discard_pile.append_array(ui.model.state.actors[1].hand)
	ui.model.state.actors[1].hand.clear()
	ui.model.visibility.refresh_intel(1,true)
	ui._sync()
	await _frames(2)
	if not await _ui_action(_legal(0,"BASIC_ATTACK")): return
	await _finish_clash()
	if not _ok(ui.snap.outcome=="victory","real input reaches victory result view"): return
	await _save_capture("tingfeng-result.png")
	await _frames(2)
	await _click_action("restart")
	ui.next_decision=1.0e30
	await _drain()
	if not _ok(ui.snap.outcome=="playing" and ui.snap.phase=="ACTION","result button restarts a playable duel"): return
	print("PASS: ",checks," tingfeng real-UI checks (branches, board move, guard, chain target, Pass, evasion, passives, restart, terminal)")
	ui.get_tree().quit(0)

func _fixture(first_actor: int, mind: int = 10) -> void:
	ui.model.reset(2026,first_actor,"tingfeng",{"passives":ui.passive_settings.duplicate(true),"attributes":{0:{"STR":10,"AGI":10,"CON":10,"MND":mind}}})
	ui.started=true
	ui.next_decision=1.0e30
	ui.presentation_left=0
	ui.movements.clear()
	ui.effects.clear()
	for actor in ui.model.state.actors:
		actor.qi_u=actor.max_qi_u
		actor.cell=Vector2i(6,4) if actor.id==0 else Vector2i(7,4)
		actor.hand.clear()
		actor.draw_pile.clear()
		actor.discard_pile.clear()
		actor.resolving.clear()
		var wanted: Array=["tf_probe","tf_probe","tf_step","tf_guard","tf_change"]
		for uid in ui.model.cards.instances:
			var instance: Dictionary=ui.model.cards.instances[uid]
			if int(instance.get("owner_actor_id",-1))!=actor.id: continue
			var index: int=wanted.find(str(instance.get("definition_id","")))
			if index>=0:
				actor.hand.append(uid)
				wanted.remove_at(index)
			else: actor.draw_pile.append(uid)
		ui.model.visibility.refresh_intel(actor.id,true)
	ui.model.state.animation_pending=false
	ui._clear_selection()
	ui._sync()

func _legal(actor: int, kind: String, usage: String = "") -> Dictionary:
	for req in ui.model.legal_actions(actor):
		if str(req.kind)==kind and (usage.is_empty() or str(req.get("usage_id",""))==usage): return req.duplicate(true)
	return {}

func _ui_action(req: Dictionary) -> bool:
	if not _ok(not req.is_empty(),"UI requested action exists"): return false
	await _drain()
	var before: int=ui.snap.revision
	var kind: String=str(req.kind)
	match kind:
		"MOVE": ui._click(ui.cell_to_screen(req.target_cell),MOUSE_BUTTON_RIGHT)
		"BASIC_ATTACK": ui._send_key(KEY_Q)
		"BASIC_GUARD": ui._send_key(KEY_G)
		"PITCH_CARD", "PLAY_CARD":
			if kind=="PITCH_CARD": ui._send_key(KEY_C)
			await _frames(1)
			if not await _click_action("card:"+str(req.get("card_uid",req.get("card_id","")))): return false
			if kind=="PLAY_CARD":
				if not await _click_action("usage:"+str(req.usage_id)): return false
				await _frames(1)
				if ui.mode=="link":
					await _save_capture("tingfeng-link-target.png")
					if not await _click_action("link:"+str(req.link_id)): return false
				elif ui.mode=="card":
					if str(req.get("usage_id",""))=="evasion": await _save_capture("tingfeng-evasion-target.png")
					var cell: Vector2i=req.get("target_cell",ui.snap.actors[int(req.get("target_id",1))].cell)
					ui._click(ui.cell_to_screen(cell))
		"PASS_REACTION", "END_ACTION": ui._send_key(KEY_SPACE)
	await _drain()
	return _ok(ui.snap.revision>before,"real UI submits "+kind+" "+str(req.get("usage_id","")))

func _click_action(action: String) -> bool:
	await _frames(2)
	for button in ui.buttons:
		if str(button.action)==action:
			if not _ok(bool(button.enabled),"UI button enabled: "+action): return false
			ui._click(button.rect.get_center())
			await _frames(2)
			return true
	return _ok(false,"UI button exists: "+action)

func _enemy_pass() -> void:
	if ui.snap.phase=="CLASH" and ui._decision_actor()==1:
		var req = _legal(1,"PASS_REACTION")
		if not req.is_empty(): ui._consume(ui.model.submit(req))
		await _drain()

func _finish_clash() -> void:
	for _i in range(12):
		await _drain()
		if ui.snap.phase!="CLASH" or ui.snap.outcome!="playing": return
		if ui._decision_actor()==0:
			await _ui_action(_legal(0,"PASS_REACTION"))
		else: await _enemy_pass()

func _drain() -> void:
	for _i in range(8):
		if ui.snap.animation_pending:
			ui._consume(ui.model.acknowledge_animation(ui.snap.ticket))
		await _frames(1)
		if not ui.snap.animation_pending: break
	await _frames(2)

func _frames(count: int) -> void:
	for _i in range(count): await ui.get_tree().process_frame

func _ok(condition: bool, label: String) -> bool:
	checks+=1
	if not condition:
		printerr("FAIL: TINGFENG_UI ",label," phase=",ui.snap.get("phase")," active=",ui.snap.get("active_id")," priority=",ui._decision_actor()," mode=",ui.mode)
		ui.get_tree().quit(1)
	return condition



func _save_capture(filename: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await _frames(2)
	await ui._capture(filename)
