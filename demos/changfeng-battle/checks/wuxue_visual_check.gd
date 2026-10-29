extends "res://checks/tingfeng_visual_check.gd"
## Opt-in V3 fixtures. Normal play never loads this script.

func run(view) -> void:
	ui=view
	ui.next_decision=1.0e30
	await _frames(2)
	ui._send_key(KEY_ENTER)
	await _frames(2)
	if not _ok(ui.snap.school_catalog.size()==11,"eleven schools exposed in the real battle view"): return
	var original_terrain: Dictionary=ui.snap.terrain.duplicate(true)
	if not await _click_action("school_open:0"): return
	if not _ok(ui.buttons.size()==12,"school modal offers all eleven schools and cancel"): return
	await _save_capture("wuxue-schools.png")
	if not await _click_action("school_set:wind_sword"): return
	if not await _click_action("school_open:1"): return
	if not await _click_action("school_set:saber"): return
	if not _ok(ui.snap.actors[0].school_id=="tingfeng" and ui.school_settings[0]=="wind_sword","selection remains pending until apply"): return
	await _save_capture("wuxue-pending.png")
	var battle_id: String=ui.snap.battle_id
	if not await _click_action("restart"): return
	ui.next_decision=1.0e30
	await _drain()
	if not _ok(ui.snap.battle_id!=battle_id and ui.snap.actors[0].school_id=="wind_sword" and ui.snap.actors[1].school_id=="saber","real apply button starts independently selected schools"): return
	if not _ok(ui.snap.terrain==original_terrain and ui.snap.terrain.size()==150,"original 15 x 10 bridge map unchanged"): return
	await _save_capture("wuxue-action.png")
	_school_fixture("wind_sword",["wind_flow","wind_final","tf_step"])
	await _frames(2)
	if not await _ui_action(_school_legal("wind_flow","probe")): return
	if not _ok(ui.snap.phase=="CLASH" and not ui._attack_cells().is_empty(),"V3 root card opens CLASH and authoritative target area"): return
	await _save_capture("wuxue-root-attack.png")
	await _finish_clash()
	if not _ok(float(ui.snap.actors[1].hp)<float(ui.snap.actors[1].max_hp),"V3 root attack resolves damage through the real UI"): return
	_school_fixture("finger",["finger_finish","finger_seal"])
	ui.model.statuses.add(1,"opening",1)
	ui._sync()
	await _frames(2)
	var condition_card: Dictionary=_definition_card("finger_finish")
	if not await _click_action("card:"+ui._uid(condition_card)): return
	if not _ok(ui._usage_summary(ui._usage(condition_card,"opening")).contains("露隙"),"conditional attack summary names its status requirement"): return
	await _save_capture("wuxue-condition.png")
	if not await _click_action("cancel"): return
	var before_hp: float=float(ui.snap.actors[1].hp)
	if not await _ui_action(_school_legal("finger_finish","opening")): return
	await _finish_clash()
	if not _ok(before_hp-float(ui.snap.actors[1].hp)>=5 and not ui.snap.actors[1].statuses.has("opening"),"conditional root deals bonus damage and consumes opening on hit"): return
	_school_fixture("needle",["needle_rain","needle_hidden","tf_step"],Vector2i(10,4))
	await _frames(2)
	var ranged_card: Dictionary=_definition_card("needle_rain")
	if not _ok(ui._usage_summary(ui._usage(ranged_card,"shoot")).contains("2–4格"),"ranged summary displays minimum and maximum straight-line range"): return
	if not await _click_action("card:"+ui._uid(ranged_card)): return
	await _save_capture("wuxue-range.png")
	if not await _click_action("usage:shoot"): return
	if not _ok(ui.mode=="card" and not ui._usage_actions(ui.selected_card,ui.selected_usage).is_empty(),"ranged usage waits for highlighted board target"): return
	await _save_capture("wuxue-ranged-target.png")
	ui._click(ui.cell_to_screen(Vector2i(10,4)))
	await _drain()
	await _finish_clash()
	if not _ok(float(ui.snap.actors[1].hp)<float(ui.snap.actors[1].max_hp),"clicking distant highlighted enemy resolves ranged root attack"): return
	_school_fixture("needle",["needle_rain"],Vector2i(8,5))
	if not _ok(_school_legal("needle_rain","shoot").is_empty(),"diagonal ranged target has no legal action"): return
	ui.model.state.actors[1].cell=Vector2i(7,4)
	ui._sync()
	if not _ok(_school_legal("needle_rain","shoot").is_empty(),"minimum ranged distance excludes adjacent target"): return
	_school_fixture("blood",["blood_burn","blood_burn","blood_finish"])
	ui.model.state.actors[0].qi_u=10000
	ui._sync()
	await _frames(2)
	var blood_card: Dictionary=_definition_card("blood_burn")
	if not await _click_action("card:"+ui._uid(blood_card)): return
	if not _ok(float(ui._quoted_cost(ui._usage(blood_card,"convert")).hp)==2 and ui._usage(blood_card,"convert").once_per_action,"blood cost and per-ACTION limit exposed in branch modal"): return
	await _save_capture("wuxue-blood-cost.png")
	if not await _click_action("cancel"): return
	before_hp=float(ui.snap.actors[0].hp)
	if not await _ui_action(_school_legal("blood_burn","convert")): return
	if not _ok(is_equal_approx(before_hp-float(ui.snap.actors[0].hp),2),"real branch click pays two blood"): return
	if not _ok(_school_legal("blood_burn","convert").is_empty(),"second copy cannot bypass once per ACTION"): return
	_school_fixture("needle",["needle_hidden","needle_hidden","needle_rain","tf_step","tf_guard","tf_change","tf_probe"])
	await _frames(2)
	var hand_before: int=ui.snap.hand.size()
	if not await _ui_action(_school_legal("needle_hidden","draw")): return
	if not _ok(ui.snap.hand.size()>=hand_before and ui.snap.hand.size()>5,"draw usage leaves an overflowing hand visible"): return
	if not await _click_action("hand_next"): return
	if not _ok(ui.hand_page==1,"more button exposes hand cards beyond the first five"): return
	var sixth: Dictionary=ui.snap.hand[5]
	if not await _click_action("card:"+ui._uid(sixth)): return
	if not _ok(not ui.usage_choices.is_empty(),"sixth hand card still opens its branches through a real click"): return
	await _save_capture("wuxue-overflow-branch.png")
	if not await _click_action("cancel"): return
	await _save_capture("wuxue-overflow-hand.png")
	_school_fixture("ember",["ember_fire","ember_burst"])
	ui.model.statuses.add(0,"focus",2)
	ui.model.statuses.add(0,"qi_seal",1)
	ui.model.statuses.add(1,"scorch",2)
	ui._sync()
	await _frames(2)
	if not _ok("凝势×2" in ui._status_labels(ui.snap.actors[0]) and "封气×1" in ui._status_labels(ui.snap.actors[0]) and "灼痕×2" in ui._status_labels(ui.snap.actors[1]),"three V3 statuses render Chinese labels and stacks"): return
	ui.mouse=Vector2(1300,320)
	await _save_capture("wuxue-status-clock.png")
	var events_before: int=ui.model.state.events.size()
	ui.model.state.mode="TIMELINE"
	ui.model.turns.advance_time(100)
	var events: Array=ui.model.state.events.slice(events_before)
	ui._consume({"success":true,"events":events})
	var has_scorch_text: bool=false
	for effect in ui.effects:
		if str(effect.text).begins_with("灼痕"): has_scorch_text=true
	if not _ok(has_scorch_text,"real SCORCH_TICK event creates Chinese floating damage text"): return
	await _save_capture("wuxue-scorch-tick.png")
	_school_fixture("ember",["ember_fire"])
	for actor in ui.model.state.actors:
		actor.hp_u=10000
		actor.stats.hp_regen_u_per_100=0
		ui.model.statuses.add(actor.id,"scorch",2)
	ui.model.state.mode="TIMELINE"
	ui.model.turns.advance_time(100)
	ui._sync()
	await _frames(2)
	if not _ok(ui.snap.outcome=="draw" and ui.snap.winner_id==-1,"same-tick scorch deaths reach the draw result view"): return
	await _save_capture("wuxue-draw.png")
	if not await _click_action("restart"): return
	ui.next_decision=1.0e30
	await _drain()
	if not _ok(ui.snap.outcome=="playing" and ui.snap.terrain==original_terrain,"draw result restart restores selected schools on the original map"): return
	print("PASS: ",checks," wuxue real-UI checks (school selection, root, condition, range, blood, overflow, status clocks, scorch, draw)")
	ui.get_tree().quit(0)

func _school_fixture(school: String, wanted: Array, enemy_cell: Vector2i=Vector2i(7,4)) -> void:
	ui.school_settings={0:school,1:"tingfeng"}
	ui.model.reset(2026,0,"tingfeng",{"schools":ui.school_settings.duplicate(true)})
	ui.started=true
	ui.next_decision=1.0e30
	ui.presentation_left=0
	ui.movements.clear()
	ui.effects.clear()
	ui.notice=""
	ui.notice_left=0
	ui.hand_page=0
	for actor in ui.model.state.actors:
		actor.qi_u=actor.max_qi_u
		actor.cell=Vector2i(6,4) if actor.id==0 else enemy_cell
		actor.hand.clear()
		actor.draw_pile.clear()
		actor.discard_pile.clear()
		actor.resolving.clear()
		var remaining: Array=wanted.duplicate() if actor.id==0 else []
		for uid in ui.model.cards.instances:
			var instance: Dictionary=ui.model.cards.instances[uid]
			if int(instance.get("owner_actor_id",-1))!=actor.id: continue
			var index: int=remaining.find(str(instance.get("definition_id","")))
			if index>=0:
				actor.hand.append(uid)
				remaining.remove_at(index)
			else: actor.draw_pile.append(uid)
		if actor.id==0:
			var pending: Array=actor.hand.duplicate()
			actor.hand.clear()
			for definition in wanted:
				for uid in pending:
					if str(ui.model.cards.instances[uid].get("definition_id",""))==str(definition):
						actor.hand.append(uid)
						pending.erase(uid)
						break
		ui.model.visibility.refresh_intel(actor.id,true)
	ui.model.state.animation_pending=false
	ui._clear_selection()
	ui._sync()

func _definition_card(definition: String) -> Dictionary:
	for card in ui.snap.hand:
		if str(card.get("definition_id",""))==definition: return card
	return {}

func _school_legal(definition: String, usage: String) -> Dictionary:
	for req in ui.model.legal_actions(0):
		if str(req.kind)!="PLAY_CARD" or str(req.get("usage_id",""))!=usage: continue
		var card: Dictionary=ui.model.cards.instance(str(req.get("card_uid","")))
		if str(card.get("definition_id",""))==definition: return req.duplicate(true)
	return {}

func _ok(condition: bool, label: String) -> bool:
	checks+=1
	if not condition:
		printerr("FAIL: WUXUE_UI ",label," phase=",ui.snap.get("phase")," active=",ui.snap.get("active_id")," priority=",ui._decision_actor()," mode=",ui.mode)
		ui.get_tree().quit(1)
	return condition
