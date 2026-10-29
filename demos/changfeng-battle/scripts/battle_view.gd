extends Node2D
## Presentation consumes the observer projection; all gameplay enters request/submit.
const Model = preload("res://scripts/battle_model.gd")
const AI = preload("res://scripts/enemy_ai.gd")
const Navigation = preload("res://scripts/demo_navigation.gd")
const Art = preload("res://scripts/battle_art.gd")
const PAPER = Color("ede9dc")
const INK = Color("273f3f")
const MUTED = Color("718077")
const JADE = Color("387c75")
const GOLD = Color("b48b50")
const RED = Color("b95b4c")
const BOARD = Rect2(24, 206, 1124, 454)
const ORIGIN = Vector2(78, 252)
const TILE = Vector2(70, 39)
var model = Model.new()
var enemy_ai = AI.new()
var player_policy = AI.new()
var art = Art.new()
var snap: Dictionary = {}
var legals: Array = []
var body_font: SystemFont
var title_font: SystemFont
var started = false
var paused_ui: bool=false
var help_open = false
var selected_card = ""
var selected_usage = ""
var usage_choices: Array = []
var usage_card: Dictionary = {}
var displayed_revision = -1
var mode = "move"
var mouse = Vector2.ZERO
var hover_cell = Vector2i(-1,-1)
var buttons: Array = []
var notice = ""
var notice_left = 0.0
var wall = 0.0
var presentation_left = 0.0
var next_decision = 0.0
var effects: Array = []
var combat_cues: Array = []
var selected_ability: Dictionary = {}
var ability_entries: Array = []
var movements: Dictionary = {}
var log_scroll = 0
var check_mode = false
var qa_auto = false
var qa_failed = false
var qa_requests = 0
var passive_settings: Dictionary = {0:{"insight":0,"conceal":0},1:{"insight":0,"conceal":0}}
var school_settings: Dictionary = {0:"tingfeng",1:"tingfeng"}
var school_picker_actor = -1
var hand_page = 0

func _ready() -> void:
	body_font = SystemFont.new()
	body_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Segoe UI"])
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["KaiTi", "STKaiti", "Microsoft YaHei"])
	DisplayServer.window_set_min_size(Vector2i(1040,650))
	model.reset(2026,0,"tingfeng",{"passives":passive_settings,"schools":school_settings})
	_sync()
	check_mode = "--tingfeng-visual-check" in OS.get_cmdline_user_args() or "--wuxue-visual-check" in OS.get_cmdline_user_args() or "--ink-visual-check" in OS.get_cmdline_user_args()
	print("TINGFENG_DUEL_READY seed=",snap.seed," board=15x10 mode=",snap.get("mode","ACTION"))
	if "--ink-visual-check" in OS.get_cmdline_user_args():
		call_deferred("_ink_visual_check")
	elif "--wuxue-visual-check" in OS.get_cmdline_user_args():
		call_deferred("_wuxue_visual_check")
	elif check_mode:
		call_deferred("_tingfeng_visual_check")

func _sync() -> void:
	var previous = [snap.get("active_id",-1),snap.get("phase",""),snap.get("responder_id",-1)]
	snap = model.snapshot(0)
	if previous != [snap.active_id,snap.phase,snap.responder_id]:
		_clear_selection()
	legals = model.legal_actions(0)
	if not selected_card.is_empty() and _find_hand(selected_card).is_empty():
		_clear_selection()

func _clear_selection() -> void:
	selected_card = ""
	selected_usage = ""
	selected_ability.clear()
	usage_choices.clear()
	mode = "move"

func _decision_actor() -> int:
	return int(snap.get("clash",{}).get("priority_actor_id",snap.responder_id)) if snap.phase == "CLASH" else int(snap.active_id)

func _process(delta: float) -> void:
	if paused_ui:
		queue_redraw()
		return
	wall += delta
	notice_left = maxf(0,notice_left-delta)
	for i in range(effects.size()-1,-1,-1):
		effects[i].left -= delta
		if effects[i].left <= 0: effects.remove_at(i)
	for i in range(combat_cues.size()-1,-1,-1):
		combat_cues[i].left -= delta
		if combat_cues[i].left <= 0: combat_cues.remove_at(i)
	for id in movements.keys():
		movements[id].elapsed += delta
		if movements[id].elapsed >= movements[id].duration: movements.erase(id)
	if started and not help_open and school_picker_actor<0:
		presentation_left = maxf(0,presentation_left-delta)
		if snap.animation_pending and presentation_left <= 0:
			_consume(model.acknowledge_animation(snap.ticket))
		elif not snap.animation_pending and snap.outcome == "playing" and wall >= next_decision:
			var who = _decision_actor()
			if who == 1 or qa_auto:
				var chooser = enemy_ai if who == 1 else player_policy
				var req: Dictionary = chooser.choose_action(model.decision_context(who))
				if not req.is_empty():
					_consume(model.submit(req))
					qa_requests += 1
				next_decision = wall+(0.015 if check_mode else 0.65)
	hover_cell = screen_to_cell(mouse) if BOARD.has_point(mouse) else Vector2i(-1,-1)
	queue_redraw()

func _consume(result: Dictionary) -> void:
	if not result.get("success",false):
		_toast(str(result.get("message","指令未执行")))
		return
	for event in result.get("events",[]):
		var kind: String=str(event.get("type",""))
		var cue_kind: String=""
		var cue_target: int=int(event.get("defender_id",event.get("target_id",event.get("actor_id",-1))))
		match kind:
			"ATTACK_DECLARED": cue_kind="attack"
			"DAMAGE": cue_kind="damage"
			"SHIELD", "INTERCEPT_JUDGED": cue_kind="guard"
			"COMBO_TRIGGERED": cue_kind="combo"
			"MOVE": cue_kind="evade"
		if not cue_kind.is_empty() and cue_target>=0 and cue_target<snap.get("actors",[]).size():
			combat_cues.append({"kind":cue_kind,"target_id":cue_target,"source_id":int(event.get("actor_id",-1)),"left":0.65,"duration":0.65})
			if combat_cues.size()>24: combat_cues.pop_front()
		match kind:
			"MOVE":
				var points: Array = [cell_to_screen(event["from"])]
				for cell in event.get("path",[event["to"]]): points.append(cell_to_screen(cell))
				if points.size()>1: movements[event.actor_id] = {"points":points,"elapsed":0.0,"duration":0.04 if check_mode else maxf(0.20,(points.size()-1)*0.18)}
			"DAMAGE": effects.append({"actor_id":event.get("defender_id",event.get("actor_id",0)),"left":0.85,"text":"−%.1f" % float(event.get("hp_damage",0)),"color":RED})
			"SHIELD": effects.append({"actor_id":event.actor_id,"left":0.85,"text":"护体","color":JADE})
			"COMBO_TRIGGERED": effects.append({"actor_id":event.actor_id,"left":1.2,"text":str(event.get("name","连携")),"color":GOLD})
			"SCORCH_TICK": effects.append({"actor_id":event.actor_id,"left":1.2,"text":"灼痕 −%.1f" % float(event.get("damage",0)),"color":RED})
	if not result.get("events",[]).is_empty():
		presentation_left = 0.02 if check_mode else 0.28
		for movement in movements.values(): presentation_left = maxf(presentation_left,movement.duration-movement.elapsed)
		log_scroll = 0
	_sync()

func _can_player() -> bool:
	return started and not help_open and school_picker_actor<0 and snap.outcome == "playing" and not snap.animation_pending and _decision_actor()==0

func _submit(kind: String, params: Dictionary = {}) -> void:
	if not _can_player():
		_toast("等待动作表现完成或对方交还优先权。")
		return
	_consume(model.submit(model.request(kind,0,params)))

func _submit_legal(req: Dictionary) -> void:
	var params: Dictionary = {}
	for key in ["card_uid","card_id","usage_id","technique_id","node_id","target_cell","target_id","link_id"]:
		if req.has(key): params[key] = req[key]
	_submit(str(req.kind),params)

func _toast(value: String) -> void:
	notice = value
	notice_left = 3.2

func _restart(_profile: String = "tingfeng") -> void:
	model.reset(int(snap.get("seed",2026)),0,"tingfeng",{"passives":passive_settings.duplicate(true),"schools":school_settings.duplicate(true)})
	enemy_ai = AI.new()
	player_policy = AI.new()
	_clear_selection()
	movements.clear()
	effects.clear()
	combat_cues.clear()
	presentation_left = 0
	next_decision = wall+0.65
	started = true
	help_open = false
	school_picker_actor = -1
	hand_page = 0
	log_scroll = 0
	_sync()
	_toast("已应用双方流派与观势 / 藏锋等级，按相同种子重新集气。")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion: mouse = event.position
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F10:
			call_deferred("_return_to_title")
			return
		if event.keycode==KEY_P:
			paused_ui=not paused_ui
			return
		if paused_ui: return
		if school_picker_actor>=0 and event.keycode not in [KEY_H,KEY_ESCAPE]: return
		match event.keycode:
			KEY_H,KEY_ESCAPE:
				if school_picker_actor>=0: school_picker_actor=-1
				elif not usage_choices.is_empty(): usage_choices.clear()
				else: help_open = not help_open
				return
			KEY_R: _restart(); return
			KEY_ENTER:
				if not started: started = true
				else: _advance()
				return
		if not _can_player(): return
		match event.keycode:
			KEY_SPACE: _advance()
			KEY_Q: _submit("BASIC_ATTACK",{"target_id":1})
			KEY_G: _submit("BASIC_GUARD")
			KEY_M: _button_action("move")
			KEY_C: _button_action("pitch")
			KEY_1,KEY_2,KEY_3,KEY_4,KEY_5:
				var index: int = event.keycode-KEY_1
				if index < snap.hand.size(): _choose_card(snap.hand[index])
	if event is InputEventMouseButton and event.pressed:
		if paused_ui: return
		mouse = event.position
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and Rect2(1170,766,406,204).has_point(mouse):
			log_scroll = clampi(log_scroll+(2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -2),0,maxi(0,_visible_logs().size()-6))
			return
		if event.button_index==MOUSE_BUTTON_RIGHT:
			if school_picker_actor>=0: school_picker_actor=-1; return
			if not usage_choices.is_empty() or mode in ["card","link","pitch","ability","ability_link"]:
				_clear_selection(); _toast("已取消选择。")
				return
		if event.button_index==MOUSE_BUTTON_LEFT:
			for button in buttons:
				if button.rect.has_point(mouse):
					if button.enabled: _button_action(button.action)
					else: _toast(button.get("reason","当前时机或资源不允许"))
					return
		if help_open or school_picker_actor>=0 or not usage_choices.is_empty() or not _can_player(): return
		if BOARD.has_point(mouse):
			var cell = screen_to_cell(mouse)
			if Rect2(_unit_pos(1)+Vector2(-24,-45),Vector2(48,64)).has_point(mouse): cell = snap.actors[1].cell
			if not snap.terrain.has(cell): return
			if mode=="card":
				for req in _usage_actions(selected_card,selected_usage):
					if (req.has("target_cell") and req.target_cell==cell) or (req.has("target_id") and int(req.target_id)>=0 and int(req.target_id)<snap.actors.size() and cell==snap.actors[int(req.target_id)].cell):
						_submit_legal(req); return
				_toast("该目标不合法，请选择高亮落点或敌人。")
			elif mode=="ability":
				for req in _ability_actions(str(selected_ability.get("technique_id","")),str(selected_ability.get("node_id",""))):
					if (req.has("target_cell") and req.target_cell==cell) or (req.has("target_id") and int(req.target_id)>=0 and int(req.target_id)<snap.actors.size() and cell==snap.actors[int(req.target_id)].cell):
						_submit_legal(req); return
				_toast("请点击合法的招式目标或落点。")
			elif mode in ["link","ability_link"]: _toast("请点击右侧连锁中高亮的敌方响应。")
			elif cell==snap.actors[1].cell and event.button_index==MOUSE_BUTTON_RIGHT: _submit("BASIC_ATTACK",{"target_id":1})
			else: _submit("MOVE",{"target_cell":cell})

func _return_to_title() -> void:
	Navigation.back_to_menu(get_tree())

func _advance() -> void:
	_submit("PASS_REACTION" if snap.phase=="CLASH" else "END_ACTION")

func _button_action(action: String) -> void:
	match action:
		"start": started = true
		"restart": _restart()
		"menu": call_deferred("_return_to_title")
		"help": help_open = not help_open
		"advance": _advance()
		"attack": _submit("BASIC_ATTACK",{"target_id":1})
		"guard": _submit("BASIC_GUARD")
		"move": _clear_selection(); _toast("选择高亮格普通移动；每格消耗气，预算随敏捷变化。")
		"pitch": _clear_selection(); mode="pitch"; _toast("点击要弃置的手牌回气。")
		"cancel": _clear_selection()
		"school_cancel": school_picker_actor=-1
		"hand_prev": hand_page=maxi(0,hand_page-1)
		"hand_next": hand_page=mini(maxi(0,ceili(snap.hand.size()/5.0)-1),hand_page+1)
		_:
			if action.begins_with("school_open:"):
				_clear_selection()
				school_picker_actor=int(action.substr(12))
			elif action.begins_with("school_set:"):
				school_settings[school_picker_actor]=action.substr(11)
				school_picker_actor=-1
				_toast("流派已选择；点击「应用并重开」生效。")
			elif action.begins_with("card:"):
				if displayed_revision==snap.revision: _choose_card(_find_hand(action.substr(5)))
			elif action.begins_with("usage:"):
				usage_choices.clear()
				_apply_usage(usage_card,action.substr(6))
			elif action.begins_with("ability_slot:"):
				var slot: int=int(action.substr(13))
				if displayed_revision==snap.revision and slot>=0 and slot<ability_entries.size():
					_choose_ability(str(ability_entries[slot].technique_id),str(ability_entries[slot].node_id))
			elif action.begins_with("link:"):
				var candidates: Array=_ability_actions(str(selected_ability.get("technique_id","")),str(selected_ability.get("node_id",""))) if mode=="ability_link" else _usage_actions(selected_card,selected_usage)
				for req in candidates:
					if str(req.get("link_id",""))==action.substr(5): _submit_legal(req); return
			elif action.begins_with("passive:"):
				var parts = action.split(":")
				var who = int(parts[1])
				passive_settings[who][parts[2]] = (int(passive_settings[who][parts[2]])+1)%3
				_toast("等级已调整；点击「应用并重开」生效。")

func _uid(card: Dictionary) -> String:
	return str(card.get("uid",card.get("card_id","")))

func _find_hand(id: String) -> Dictionary:
	for card in snap.hand:
		if _uid(card)==id: return card
	return {}

func _usage(card: Dictionary, id: String) -> Dictionary:
	for usage in card.get("usages",[]):
		if str(usage.id)==id: return usage
	return {}

func _usage_actions(uid: String, usage_id: String) -> Array:
	var result: Array = []
	for req in legals:
		if req.kind=="PLAY_CARD" and str(req.get("card_uid",req.get("card_id","")))==uid and str(req.get("usage_id",""))==usage_id: result.append(req)
	return result

func _ability_actions(technique_id: String, node_id: String) -> Array:
	var actions: Array=[]
	for req in legals:
		if str(req.get("kind",""))=="USE_ABILITY" and str(req.get("technique_id",""))==technique_id and str(req.get("node_id",""))==node_id: actions.append(req)
	return actions

func _choose_ability(technique_id: String, node_id: String) -> void:
	if not _can_player(): return
	var actions: Array=_ability_actions(technique_id,node_id)
	if actions.is_empty():
		_toast("当前无可用阶段：检查内息、目标与出招时机。")
		return
	_clear_selection()
	selected_ability={"technique_id":technique_id,"node_id":node_id}
	if actions[0].has("link_id"):
		mode="ability_link"
		_toast("选择连锁中的合法响应目标。")
	elif actions[0].has("target_cell") or actions[0].has("target_id"):
		mode="ability"
		_toast("选择此式的合法目标或落点；右键取消。")
	else:
		_submit_legal(actions[0])

func _draw_ability_tray() -> bool:
	ability_entries.clear()
	var states: Dictionary=snap.actors[0].get("technique_states",{})
	if states.is_empty(): return false
	var ids: Array=states.keys()
	ids.sort()
	_text(Vector2(237,708),"武学续式",14,GOLD)
	for i in range(mini(3,ids.size())):
		var id: String=str(ids[i])
		var node_id: String=str(states[id].get("node",""))
		var label: String=node_id
		for node in model.techniques.definitions.get(id,{}).get("nodes",[]):
			if str(node.get("id",""))==node_id:
				label=str(node.get("name",node_id))
				break
		var title: String=_trim(label,135,12)
		ability_entries.append({"technique_id":id,"node_id":node_id})
		_small_button(Rect2(342+i*170,681,162,36),title,"ability_slot:"+str(i),not _ability_actions(id,node_id).is_empty())
	return true

func _choose_card(card: Dictionary) -> void:
	if card.is_empty() or not _can_player(): return
	if mode=="pitch":
		_submit("PITCH_CARD",{"card_uid":_uid(card)})
		_clear_selection()
		return
	usage_card = card.duplicate(true)
	usage_choices = card.get("usages",[]).duplicate(true)
	if usage_choices.is_empty(): _toast("这张牌没有可展示的用法。")

func _apply_usage(card: Dictionary, usage_id: String) -> void:
	var choices = _usage_actions(_uid(card),usage_id)
	if choices.is_empty(): _toast(_usage_reason(card,_usage(card,usage_id))); return
	selected_card = _uid(card)
	selected_usage = usage_id
	if choices[0].has("link_id"):
		mode = "link"
		_toast("截势：选择右侧高亮响应层；从栈顶开始逆序结算。")
	elif choices[0].has("target_cell") or choices[0].has("target_id"):
		mode = "card"
		_toast("%s：选择棋盘高亮目标；右键取消。" % _usage(card,usage_id).get("name",card.name))
	else: _submit_legal(choices[0])

func _card_enabled(card: Dictionary) -> bool:
	return _can_player() and (mode!="pitch" or _kind_legal("PITCH_CARD"))

func _kind_legal(kind: String) -> bool:
	for req in legals:
		if req.kind==kind: return true
	return false

func _usage_reason(card: Dictionary, usage: Dictionary) -> String:
	if not started: return "进入战场后可操作"
	if snap.animation_pending: return "动作表现中"
	if _decision_actor()!=0: return "等待优先权"
	if not _usage_actions(_uid(card),str(usage.get("id",""))).is_empty(): return "合法 · 点击选择"
	var cost = _quoted_cost(usage)
	if float(snap.actors[0].qi)<float(cost.get("qi",0)): return "气不足（需 %.1f）" % float(cost.get("qi",0))
	if float(snap.actors[0].hp)<=float(cost.get("hp",0)): return "气血不足"
	if usage.get("once_per_action",false): return "每次行动限一次；或时机 / 距离 / 目标不合法"
	return "当前时机 / 距离 / 响应目标不合法"

func _reason(card: Dictionary) -> String:
	if not _can_player(): return "等待优先权或动作完成"
	for usage in card.get("usages",[]):
		if not _usage_actions(_uid(card),str(usage.id)).is_empty(): return "点击展开用法"
	for usage in card.get("usages",[]):
		var reason = _usage_reason(card,usage)
		if reason.begins_with("气不足"): return reason
	return "可查看分支 · 目前无合法用法"

func _draw() -> void:
	if body_font==null or snap.is_empty(): return
	displayed_revision = snap.revision
	buttons.clear()
	art.backdrop(self,wall)
	_draw_header()
	_draw_timeline()
	_draw_board()
	_draw_actors()
	var fx_positions: Array=[]
	for actor in snap.actors: fx_positions.append(_unit_pos(int(actor.id)))
	art.burst(self,snap,combat_cues,fx_positions,wall)
	_draw_hand()
	_draw_sidebar()
	_draw_status_tooltip()
	for effect in effects:
		var color: Color = effect.color
		color.a = clampf(effect.left/0.85,0,1)
		_center(_unit_pos(effect.actor_id)+Vector2(0,-48-(0.85-effect.left)*25),effect.text,25,color)
	if notice_left>0 and started and snap.outcome=="playing":
		_panel(Rect2(172,621,830,28),Color("254e46"))
		_center(Vector2(587,641),notice,14,PAPER)
	_text(Vector2(30,991),"右键移动 / 攻击   1–5 查看用法   Q 攻击   G 格挡   C 弃牌   M 移动   Space / Enter 结束行动或 Pass   H 帮助   R 重开   P 暂停   F10 菜单",13,MUTED)
	if not started: _draw_intro()
	elif snap.outcome!="playing": _draw_result()
	if help_open: _draw_help()
	if not usage_choices.is_empty(): _draw_usage_picker()
	if school_picker_actor>=0: _draw_school_picker()
	if paused_ui: Navigation.draw_pause(self,title_font)

func _draw_header() -> void:
	draw_rect(Rect2(0,0,1600,126),Color("173f3d"))
	draw_line(Vector2(24,126),Vector2(1576,126),GOLD,2)
	art.header(self,wall)
	_panel(Rect2(34,28,42,62),RED)
	_center(Vector2(55,54),"长",23,PAPER,true)
	_center(Vector2(55,80),"风",23,PAPER,true)
	_text(Vector2(94,67),"长风浮生录",43,PAPER,true)
	_text(Vector2(98,96),"断桥论剑  /  十一门武学 · 自由行动",14,Color("aebfb1"))
	for who in range(2):
		var chosen: String=str(school_settings[who])
		var current: String=str(snap.actors[who].get("school_id","tingfeng"))
		var label: String=("我方 " if who==0 else "敌方 ")+_school_name(chosen)
		_small_button(Rect2(460+who*222,29,210,43),label+" ▾","school_open:%d" % who,true,true)
		_text(Vector2(466+who*222,95),("当前流派" if current==chosen else "待应用 · 当前 "+_school_name(current)),12,Color("aebfb1"))
	_text(Vector2(940,57),"行动 %d" % int(snap.get("action_no",1)),22,PAPER,true)
	_text(Vector2(940,88),"tick %d  /  种子 %d" % [int(snap.get("global_tick",0)),snap.seed],13,Color("aebfb1"))
	_small_button(Rect2(1200,35,168,48),"H  武学规则","help",true,true)
	_small_button(Rect2(1388,35,168,48),"R  同种子重开","restart",true,true)

func _draw_timeline() -> void:
	for i in range(2):
		var actor: Dictionary = snap.actors[i]
		var rect = Rect2(24+i*566,146,558,48)
		_panel(rect,Color("e1e5d7"),JADE if snap.active_id==i else Color("cbd1bf"))
		_text(rect.position+Vector2(12,21),_trim("%s / %s · 集气 %.0f" % [actor.name,actor.get("school_name","听风五式"),float(actor.get("gauge",0))],282,14),14,INK)
		_text(rect.position+Vector2(300,21),"速度 %.1f" % float(actor.get("charge_speed",0)),14,MUTED)
		_text(rect.position+Vector2(404,21),"此局终了" if snap.outcome!="playing" else ("交锋停表" if snap.phase=="CLASH" else ("自由行动" if snap.active_id==i else "等待集气")),14,GOLD)
		_bar(Rect2(rect.position+Vector2(12,32),Vector2(530,6)),float(actor.get("gauge",0))/10000.0,JADE if i==0 else RED)

func _draw_hand() -> void:
	_panel(Rect2(24,678,1124,292),Color("f7f4e9"),Color("c9d1c0"))
	_text(Vector2(44,709),str(snap.actors[0].get("school_name","听风五式")),17,GOLD)
	if not _draw_ability_tray():
		_text(Vector2(240,709),"手牌 %d  抽牌 %d  弃牌 %d  结算 %d · 一张牌只选一种用法" % [int(snap.actors[0].hand_count),int(snap.actors[0].draw_count),int(snap.actors[0].discard_count),int(snap.actors[0].resolving_count)],13,MUTED)
	var pages: int=maxi(1,ceili(snap.hand.size()/5.0))
	hand_page=clampi(hand_page,0,pages-1)
	if pages>1:
		_small_button(Rect2(878,687,42,29),"‹","hand_prev",hand_page>0)
		_center(Vector2(991,708),"第 %d / %d 页" % [hand_page+1,pages],13,JADE)
		_small_button(Rect2(1065,687,60,29),"更多 ›","hand_next",hand_page<pages-1)
	else: _text(Vector2(870,709),"选牌弃置回气" if mode=="pitch" else "点牌展开全部分支",14,JADE)
	for slot in range(5):
		var i: int=hand_page*5+slot
		var rect = Rect2(40+slot*220,731,207,188)
		if i>=snap.hand.size():
			_panel(rect,Color("e8e9de")); _center(rect.position+Vector2(rect.size.x/2,100),"空",26,MUTED,true); continue
		var card: Dictionary = snap.hand[i]
		var enabled = _card_enabled(card)
		art.card_frame(self,rect,i,_uid(card)==selected_card,enabled,card,wall)
		_text(rect.position+Vector2(14,25),"%d  %s · %d 用法" % [i+1,("衍生" if bool(card.get("generated",false)) else "招式"),card.get("usages",[]).size()],13,GOLD)
		_text(rect.position+Vector2(14,65),_trim(str(card.name),rect.size.x-28,25),25,INK if enabled else MUTED,true)
		var usages: Array = card.get("usages",[])
		for u in range(mini(3,usages.size())):
			var usage: Dictionary = usages[u]
			var usable = not _usage_actions(_uid(card),str(usage.id)).is_empty()
			var cost: Dictionary=_quoted_cost(usage)
			var cost_text: String="%.1f气" % float(cost.get("qi",0))
			if float(cost.get("hp",0))>0: cost_text+=" / %.1f血" % float(cost.hp)
			_text(rect.position+Vector2(14,95+u*22),_trim("%s  %s" % [usage.get("name",usage.id),cost_text],rect.size.x-30,12),12,JADE if usable else MUTED)
		_text(rect.position+Vector2(14,173),_trim(_reason(card),rect.size.x-25,12),12,GOLD)
		buttons.append({"rect":rect,"action":"card:"+_uid(card),"enabled":enabled,"reason":_reason(card)})
	for i in range(4):
		var who = i/2
		var talent = "insight" if i%2==0 else "conceal"
		var label = ("我方" if who==0 else "敌方")+("观势" if talent=="insight" else "藏锋")
		_small_button(Rect2(40+i*209,932,198,29),"%s  %d  ↻" % [label,int(passive_settings[who][talent])],"passive:%d:%s" % [who,talent],true)
	_small_button(Rect2(881,932,248,29),"应用流派与等级并重开","restart",true)

func _draw_sidebar() -> void:
	for i in range(2):
		var actor: Dictionary = snap.actors[i]
		var rect = Rect2(1170,146+i*124,406,112)
		var color = JADE if i==0 else RED
		_panel(rect,Color("f7f4e9"),color)
		_text(rect.position+Vector2(14,25),"%s · %s  %s" % [actor.name,"你" if i==0 else "对手",actor.get("danger","")],21,color,true)
		_text(rect.position+Vector2(245,24),"护体 %.1f" % float(actor.shield),14,GOLD)
		_bar(Rect2(rect.position+Vector2(15,36),Vector2(245,5)),float(actor.hp)/maxf(1,float(actor.get("max_hp",20))),color)
		_text(rect.position+Vector2(270,43),"%.1f / %.1f" % [float(actor.hp),float(actor.get("max_hp",20))],13,color)
		_text(rect.position+Vector2(15,63),"气 %.1f / %.1f · 移动余 %d · 手牌 %d" % [float(actor.qi),float(actor.get("max_qi",6)),maxi(0,int(actor.get("move_budget",2))-int(actor.get("normal_moves_used",0))),int(actor.hand_count)],13,MUTED)
		var attrs: Dictionary = actor.get("attributes",{})
		_text(rect.position+Vector2(15,83),"力 %s  敏 %s  体 %s  意 %s  ·  速度 %.1f" % [attrs.get("STR",10),attrs.get("AGI",10),attrs.get("CON",10),attrs.get("MND",10),float(actor.get("charge_speed",0))],12,MUTED)
		var details: PackedStringArray = []
		if i==1:
			for card in actor.get("observed_hand",[]): details.append(str(card.get("name","未知")) if card.get("known",false) else "·")
		else:
			details.append("观势 %s / 藏锋 %s" % [actor.get("passives",{}).get("insight",0),actor.get("passives",{}).get("conceal",0)])
		var status_line: String=" / ".join(_status_labels(actor))
		_text(rect.position+Vector2(15,103),_trim(status_line+" · 悬停查看时钟" if not status_line.is_empty() else ("已知敌牌："+" / ".join(details) if i==1 else " / ".join(details)),374,12),12,GOLD)
	_panel(Rect2(1170,394,406,170),Color("e4e9dd"),Color("c3cebc"))
	var clash: Dictionary = snap.get("clash",{})
	var is_clash: bool = snap.phase=="CLASH"
	_text(Vector2(1189,421),"此局终了" if snap.outcome!="playing" else (("你的优先权" if _decision_actor()==0 else "对手优先权") if is_clash else ("你的自由行动" if snap.active_id==0 else "对手自由行动")),23,JADE if _can_player() else GOLD,true)
	_text(Vector2(1189,443),"LIFO 逆序 · 我%d/2 敌%d/2 · Pass %d/2" % [int(clash.get("counts",{}).get(0,0)),int(clash.get("counts",{}).get(1,0)),int(clash.get("consecutive_passes",0))] if is_clash else "移动、攻防、出牌可自由穿插；结束行动后集气。",12,MUTED)
	var stack: Array = clash.get("stack",[])
	for i in range(mini(4,stack.size())):
		var link: Dictionary = stack[stack.size()-1-i]
		var id = str(link.get("link_id",link.get("id","")))
		var legal_link = false
		if mode in ["link","ability_link"]:
			var candidate_links: Array=_ability_actions(str(selected_ability.get("technique_id","")),str(selected_ability.get("node_id",""))) if mode=="ability_link" else _usage_actions(selected_card,selected_usage)
			for req in candidate_links:
				if str(req.get("link_id",""))==id: legal_link=true
		var rect = Rect2(1189,451+i*17,368,16)
		if legal_link: draw_rect(rect,Color("c9d8bd"))
		_text(rect.position+Vector2(3,13),_trim("%s %s · %s%s" % ["顶" if i==0 else "↑","我" if int(link.get("actor_id",-1))==0 else "敌",link.get("name",link.get("usage_id","响应"))," [已取消]" if link.get("canceled",false) else ""],360,12),12,GOLD if legal_link else MUTED)
		if legal_link: buttons.append({"rect":rect,"action":"link:"+id,"enabled":true})
	_small_button(Rect2(1189,527,368,29),"Pass · 交还优先权  Space" if is_clash else "结束自由行动  Space","advance",_can_player() and _kind_legal("PASS_REACTION" if is_clash else "END_ACTION"))
	_panel(Rect2(1170,578,406,174),Color("f7f4e9"),Color("c9d1c0"))
	_text(Vector2(1190,604),"基 础 行 动",14,GOLD)
	var controls = [["M 移动 · 1气/格","move","MOVE"],["Q 攻击 · 1气","attack","BASIC_ATTACK"],["G 格挡 · 1气","guard","BASIC_GUARD"],["C 弃牌 · 回1气","pitch","PITCH_CARD"]]
	for i in range(4):
		_small_button(Rect2(1189+(i%2)*190,618+(i/2)*53,178,43),controls[i][0],controls[i][1],_can_player() and _kind_legal(controls[i][2]))
	_panel(Rect2(1170,766,406,204),Color("f7f4e9"),Color("c9d1c0"))
	_text(Vector2(1190,796),"交 锋 记 录",14,GOLD)
	_text(Vector2(1440,796),"滚轮翻阅",12,MUTED)
	var entries: Array = _visible_logs()
	log_scroll = clampi(log_scroll,0,maxi(0,entries.size()-6))
	var end: int = maxi(0,entries.size()-log_scroll)
	var begin: int = maxi(0,end-6)
	for i in range(begin,end):
		_text(Vector2(1189,823+(i-begin)*23),_trim(str(entries[i].get("text","")),364,12),12,MUTED)

func _small_button(rect: Rect2, title: String, action: String, enabled: bool, dark: bool = false) -> void:
	var hovered: bool=rect.has_point(mouse) and enabled
	var base_color: Color=Color("254b46") if dark else (JADE if enabled else Color("dce0d4"))
	if hovered: base_color=base_color.lightened(0.12)
	draw_rect(Rect2(rect.position+Vector2(1,3),rect.size),Color(0.13,0.24,0.20,0.12))
	_panel(rect,base_color,GOLD if hovered else Color("acb7a8"))
	if hovered: draw_rect(rect.grow(1),Color(GOLD,0.48),false,1.5)
	_center(rect.position+Vector2(rect.size.x/2,rect.size.y/2+6),title,14,PAPER if enabled else MUTED)
	buttons.append({"rect":rect,"action":action,"enabled":enabled,"reason":"当前时机、距离、气或移动预算不足"})

func _draw_usage_picker() -> void:
	# Modal buttons supersede all underlying input regions.
	buttons.clear()
	draw_rect(Rect2(0,126,1600,874),Color(.08,.20,.17,.5))
	var height: float=118+usage_choices.size()*128
	var rect = Rect2(310,maxf(168,496-height/2),780,height)
	_panel(rect,PAPER,GOLD)
	_text(rect.position+Vector2(26,42),"选择「%s」的用法" % usage_card.name,28,INK,true)
	for i in range(usage_choices.size()):
		var usage: Dictionary = usage_choices[i]
		var usable = not _usage_actions(_uid(usage_card),str(usage.id)).is_empty() and _can_player()
		var cost: Dictionary = _quoted_cost(usage)
		var label = "%s  ·  %.1f气%s%s" % [usage.get("name",usage.id),float(cost.get("qi",0))," / %.1f气血" % float(cost.get("hp",0)) if float(cost.get("hp",0))>0 else ""," · 每次行动限一次" if usage.get("once_per_action",false) else ""]
		_small_button(Rect2(rect.position+Vector2(26,66+i*128),Vector2(728,43)),label,"usage:"+str(usage.id),usable)
		buttons.back().reason = _usage_reason(usage_card,usage)
		var summary: String=_usage_summary(usage)
		var lines: PackedStringArray=_wrap_text(summary,712,13)
		for line in range(mini(2,lines.size())): _text(rect.position+Vector2(31,128+i*128+line*19),lines[line],13,JADE if usable else MUTED)
		_text(rect.position+Vector2(31,168+i*128),_usage_reason(usage_card,usage),13,JADE if usable else RED)
	_small_button(Rect2(rect.position+Vector2(575,rect.size.y-40),Vector2(180,28)),"取消  右键 / Esc","cancel",true)

func _draw_intro() -> void:
	buttons.clear()
	draw_rect(Rect2(0,126,1600,874),Color(.08,.20,.17,.48))
	_panel(Rect2(337,247,926,505),Color("f4f0e1"),Color("b7bda7"))
	_text(Vector2(382,297),"断 桥 论 剑  /  十 一 门 武 学",15,GOLD)
	_text(Vector2(379,359),"一式多变，听风而动。",44,INK,true)
	var lines = ["集气到达阈值后自由行动：走位、出招、护身不再分阶段。","点一张手牌，选择合法分支；游身选择落点，截势选择响应层。","攻击触发 CLASH：守方先手，双方轮流响应或 Pass。","连锁后入先出；连续两次 Pass 开始结算，交锋期间全局停表。","顶部选双方流派，牌区下方调观势 / 藏锋，应用并重开后生效。"]
	for i in range(lines.size()): _text(Vector2(384,414+i*40),lines[i],17,INK if i<3 else MUTED)
	_small_button(Rect2(625,653,350,54),"进入战场  Enter","start",true)
	_center(Vector2(800,735),"15 × 10 断桥  ·  四维属性决定能力与速度  ·  R 同种子重开",13,MUTED)

func _draw_result() -> void:
	draw_rect(BOARD,Color(.08,.20,.17,.58))
	_panel(Rect2(240,280,720,310),Color("f4f0e1"),Color("b7bda7"))
	_center(Vector2(600,345),"两败俱伤 · 平局" if snap.outcome=="draw" else ("此役告捷" if snap.outcome=="victory" else "棋差一着"),46,GOLD if snap.outcome=="draw" else (JADE if snap.outcome=="victory" else RED),true)
	_center(Vector2(600,397),"%s 对 %s · 此局终了" % [snap.actors[0].get("school_name","听风五式"),snap.actors[1].get("school_name","听风五式")],21,INK,true)
	_center(Vector2(600,437),"气血：你 %.1f / 对手 %.1f  ·  tick %d" % [float(snap.actors[0].hp),float(snap.actors[1].hp),int(snap.get("global_tick",0))],17,MUTED)
	_small_button(Rect2(330,486,250,54),"相同种子再战  R","restart",true)
	_small_button(Rect2(630,486,270,54),"主菜单  F10","menu",true)

func _draw_help() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1600,1000),Color(.06,.14,.13,.72))
	_panel(Rect2(295,175,1010,665),Color("f4f0e1"),Color("b7bda7"))
	_text(Vector2(340,231),"十一门武学 · 自由行动与连锁",36,INK,true)
	var lines = ["集气阈值 10000；速度取决于敏捷。内息随全局逻辑时间恢复。","获得行动后自由移动、出牌、攻防；Space / Enter 结束行动。","攻击声明进入 CLASH，防御方先获得优先权；双方轮流响应或 Pass。","每方最多响应 2 张、总共 4 张；连续两次 Pass 后，从栈顶逆序结算。","游身可主动移动或响应避锋；变锋截势需选择敌方某一层响应。","卡牌先展开分支，灰色用法显示气不足、时机或目标限制，不扣资源。","四维属性、集气速度、气血、内息与移动预算显示在角色栏。","观势严格高于对方藏锋才识破；明牌覆盖藏锋，已见手牌保留记忆。","敌方手牌仅显示已知事实；危表示高威胁牌，？表示危险提示被隐藏。","远程按正交直线计算最小 / 最大距离；分支显示血费与每行动限次。","凝势强化下次根攻击，封气减慢自然回气；灼痕按时钟扣血，可同时倒下。","1–5 选牌，更多手牌点翻页；Q 攻击 / G 格挡 / C 弃牌 / M 移动；H 关闭；续式按钮在手牌上方。"]
	for i in range(lines.size()): _text(Vector2(340,280+i*40),lines[i],16,INK if i<5 else MUTED)
	_small_button(Rect2(625,742,350,48),"返回战场  H / Esc","help",true)

func _draw_board() -> void:
	_panel(BOARD, Color("dfe5d7"), Color("bfcbbc"))
	for cell in snap.terrain:
		var terrain: String = snap.terrain[cell]
		var pos = cell_to_screen(cell)
		var noise = sin(cell.x*14.1+cell.y*31.7)*0.018
		var color = Color(0.81+noise,0.84+noise,0.75+noise)
		if terrain == "water": color = Color("7daba9")
		elif terrain == "bridge": color = Color("bfa47a")
		elif terrain == "ford": color = Color("a2b9a6")
		_tile(cell,color,Color(0.34,0.46,0.36,0.13))
		if terrain == "water":
			for i in range(2):
				var offset = Vector2(sin(wall*.7+cell.y+i)*6,(i-.5)*12)
				draw_line(pos+offset+Vector2(-16,0),pos+offset+Vector2(16,0),Color(.87,.96,.90,.4),1,true)
		elif terrain == "bridge":
			for i in range(-2,3): draw_line(pos+Vector2(i*11,-15),pos+Vector2(i*11,15),Color("8c7150"),2)
		elif terrain == "ford":
			for i in range(3): draw_circle(pos+Vector2((i-1)*18,sin(i*2.0)*6),6,Color("cbd0b8"))
		elif terrain == "rock": _draw_rock(pos,cell.x+cell.y)
		elif terrain == "bamboo": _draw_bamboo(pos,cell.x+cell.y)
	art.battlefield(self,snap,wall)
	_draw_attack_area()
	if _can_player():
		for req in legals:
			var selected: bool = (mode=="card" and req.kind=="PLAY_CARD" and str(req.get("card_uid",req.get("card_id","")))==selected_card and str(req.get("usage_id",""))==selected_usage) or (mode=="ability" and req.kind=="USE_ABILITY" and str(req.get("technique_id",""))==str(selected_ability.get("technique_id","")) and str(req.get("node_id",""))==str(selected_ability.get("node_id","")))
			if (mode=="move" and req.kind=="MOVE") or selected:
				if req.has("target_cell"):
					if snap.phase=="CLASH":
						var target_rect = Rect2(cell_to_screen(req.target_cell)-TILE*0.5+Vector2(6,6),TILE-Vector2(12,12))
						draw_rect(target_rect,Color(.28,.56,.48,.20))
						draw_rect(target_rect,JADE,false,2)
					else: _tile(req.target_cell,Color(.28,.56,.48,.13),JADE,1.5)
				elif req.get("target_id",-1)==1: _tile(snap.actors[1].cell,Color(.73,.34,.25,.1),RED,2)
	if snap.terrain.has(hover_cell):
		if snap.phase=="CLASH":
			var hover_rect = Rect2(cell_to_screen(hover_cell)-TILE*0.5+Vector2(9,9),TILE-Vector2(18,18))
			draw_rect(hover_rect,GOLD,false,1.5)
		else: _tile(hover_cell,Color(1,.98,.79,.13),GOLD,2)
	_text(Vector2(44,641),"朱框：本击锁定区 · 碧框：合法落点 · 离开朱框可闪避，变锋可扩区" if snap.phase=="CLASH" else "江南驿道 / 四向移动 · 高亮为合法目标 · CLASH 游身可选择闪避落点",13,MUTED)


func cell_to_screen(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell) * TILE

func screen_to_cell(point: Vector2) -> Vector2i:
	var local = (point - ORIGIN) / TILE
	return Vector2i(roundi(local.x), roundi(local.y))

func _unit_pos(id: int) -> Vector2:
	if movements.has(id):
		var movement = movements[id]
		var points: Array = movement.points
		var progress = clampf(movement.elapsed / movement.duration, 0.0, 0.9999) * (points.size()-1)
		var index = int(progress)
		return points[index].lerp(points[index+1], progress-index)
	return cell_to_screen(snap.actors[id].cell)

func _tile(cell: Vector2i, fill: Color, border: Color = Color.TRANSPARENT, width: float = 1.0) -> void:
	var rect = Rect2(cell_to_screen(cell)-TILE*0.5+Vector2(1,1),TILE-Vector2(2,2))
	draw_rect(rect,fill)
	if border.a > 0: draw_rect(rect,border,false,width)

func _draw_actors() -> void:
	for actor in snap.actors:
		var pos = _unit_pos(actor.id)
		var color = JADE if actor.id==0 else RED
		var taking_hit: bool=false
		for cue in combat_cues:
			if str(cue.get("kind",""))=="damage" and int(cue.get("target_id",-1))==int(actor.id): taking_hit=true
		art.combatant(self,pos,actor,wall,int(snap.active_id)==int(actor.id),taking_hit)
		_bar(Rect2(pos+Vector2(-28,-59),Vector2(56,5)),float(actor.hp)/maxf(1,float(actor.get("max_hp",20))),color)
		if actor.shield>0:
			draw_arc(pos,34,-PI*.9,-PI*.1,24,Color("d2ad69"),3,true)
		_center(pos+Vector2(0,37),"%s  %.1f" % [actor.name,float(actor.hp)],14,color.darkened(.15))
		var status_labels: PackedStringArray=_status_labels(actor)
		if not status_labels.is_empty(): _center(pos+Vector2(0,54)," / ".join(status_labels),12,GOLD)
	if not snap.attack.is_empty():
		var a = snap.attack
		draw_line(_unit_pos(a.attacker_id)+Vector2(0,-16),_unit_pos(a.defender_id)+Vector2(0,-16),Color(GOLD,.8),3,true)

func _panel(rect: Rect2, color: Color, border: Color = Color.TRANSPARENT) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1 if border.a>0 else 0)
	style.set_corner_radius_all(6)
	draw_style_box(style,rect)

func _text(pos: Vector2, value: String, size: int = 18, color: Color = INK, calligraphy: bool = false) -> void:
	draw_string(title_font if calligraphy else body_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _center(pos: Vector2, value: String, size: int, color: Color = INK, calligraphy: bool = false) -> void:
	var font = title_font if calligraphy else body_font
	_text(pos-Vector2(font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x/2,0),value,size,color,calligraphy)

func _trim(value: String, max_width: float, size: int) -> String:
	var result = value
	while result.length()>0 and body_font.get_string_size(result,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>max_width: result=result.substr(0,result.length()-1)
	return result+("…" if result!=value else "")

func _bar(rect: Rect2, fraction: float, color: Color) -> void:
	_panel(rect,Color("d9ded3"))
	if fraction>0: _panel(Rect2(rect.position,Vector2(maxf(3,rect.size.x*clampf(fraction,0,1)),rect.size.y)),color)

func _draw_rock(pos: Vector2, seed_value: int) -> void:
	var points = PackedVector2Array([pos+Vector2(-24,11),pos+Vector2(-22,-8),pos+Vector2(-9,-19),pos+Vector2(15,-16),pos+Vector2(28,0),pos+Vector2(22,12)])
	draw_colored_polygon(points,Color("89978c"))
	draw_colored_polygon(PackedVector2Array([points[1],points[2],points[3],pos+Vector2(4,1)]),Color("abb6a6"))
	if seed_value%2==0: draw_circle(pos+Vector2(-15,10),6,Color("7c9473"))

func _draw_bamboo(pos: Vector2, seed_value: int) -> void:
	for i in range(4):
		var x = (i-1.5)*10
		var tip = pos+Vector2(x+sin(seed_value+i)*6,-23-(i%2)*11)
		draw_line(pos+Vector2(x,10),tip,Color("5e8064"),3,true)
		for j in range(2):
			var leaf=tip+Vector2(0,j*13)
			draw_line(leaf,leaf+Vector2(-12,-6),Color("628468"),3,true)
			draw_line(leaf,leaf+Vector2(13,-4),Color("628468"),3,true)

func _send_key(key: Key) -> void:
	var event=InputEventKey.new()
	event.keycode=key
	event.pressed=true
	get_viewport().push_input(event,true)

func _click(point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event=InputEventMouseButton.new()
	event.position=point
	event.button_index=button
	event.pressed=true
	get_viewport().push_input(event,true)

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	var error = get_viewport().get_texture().get_image().save_png("res://captures/"+filename)
	print("DUEL_CAPTURE ",filename," result=",error)


func _tingfeng_visual_check() -> void:
	var check = load("res://checks/tingfeng_visual_check.gd").new()
	await check.run(self)

func _ink_visual_check() -> void:
	var check = load("res://checks/ink_visual_check.gd").new()
	await check.run(self)

func _wuxue_visual_check() -> void:
	var check = load("res://checks/wuxue_visual_check.gd").new()
	await check.run(self)

func _school_name(id: String) -> String:
	for school in snap.get("school_catalog",[]):
		if str(school.id)==id: return str(school.name)
	return "听风五式" if id=="tingfeng" else id

func _draw_school_picker() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1600,1000),Color(.06,.14,.13,.72))
	_panel(Rect2(320,145,960,705),PAPER,GOLD)
	_text(Vector2(354,195),("我方" if school_picker_actor==0 else "敌方")+" · 选择武学流派",30,INK,true)
	_text(Vector2(354,225),"选择后点击底部「应用流派与等级并重开」；双方独立选择。",14,MUTED)
	var schools: Array=snap.get("school_catalog",[])
	for i in range(schools.size()):
		var school: Dictionary=schools[i]
		var x: float=354+(i%2)*452
		var y: float=248+floori(i/2.0)*85
		var selected: bool=str(school_settings[school_picker_actor])==str(school.id)
		_small_button(Rect2(x,y,420,42),("✓ " if selected else "")+str(school.name),"school_set:"+str(school.id),true)
		_text(Vector2(x+8,y+64),_trim(str(school.get("identity","")),405,12),12,MUTED)
	_small_button(Rect2(1050,793,194,34),"取消  Esc / 右键","school_cancel",true)

func _status_name(id: String) -> String:
	return {"opening":"露隙","hand_exposed":"明牌","focus":"凝势","qi_seal":"封气","scorch":"灼痕"}.get(id,id)

func _status_labels(actor: Dictionary) -> PackedStringArray:
	var labels: PackedStringArray=[]
	for id in actor.get("statuses",{}):
		var entry=actor.statuses[id]
		labels.append(_status_name(str(id))+"×%d" % int(entry.get("stacks",1)) if entry is Dictionary else _status_name(str(id)))
	return labels

func _draw_status_tooltip() -> void:
	if snap.outcome!="playing" or help_open or not usage_choices.is_empty() or school_picker_actor>=0: return
	for i in range(2):
		var actor: Dictionary=snap.actors[i]
		if actor.get("statuses",{}).is_empty(): continue
		if not Rect2(1170,146+i*124,406,112).has_point(mouse) and mouse.distance_to(_unit_pos(i))>43: continue
		var rows: Array=[]
		for id in actor.statuses:
			var entry=actor.statuses[id]
			var expiry: int=int(entry.get("expiry",-1)) if entry is Dictionary else int(entry)
			var text: String=_status_name(str(id))+" · %d层" % int(entry.get("stacks",1) if entry is Dictionary else 1)
			text+=" · 剩余%d tick" % maxi(0,expiry-int(snap.global_tick)) if expiry>=0 else " · 持续"
			if entry is Dictionary and entry.has("next_tick"): text+=" · 下次结算%d tick" % maxi(0,int(entry.next_tick)-int(snap.global_tick))
			rows.append(text)
			var description: String={"focus":"下次根攻击宣告消耗，每层伤害 +1；落空不返还。","qi_seal":"自然回气减半；主动回气保持原值。","scorch":"每100 tick按层扣血，绕过护体，再减少1层。"}.get(str(id),"")
			if not description.is_empty(): rows.append(description)
		_panel(Rect2(690,467,450,48+rows.size()*25),PAPER,GOLD)
		_text(Vector2(707,497),"%s · 状态时钟" % actor.name,16,INK)
		for r in range(rows.size()): _text(Vector2(707,524+r*25),str(rows[r]),13,GOLD)

func _usage_summary(usage: Dictionary) -> String:
	var result: PackedStringArray = []
	result.append({"ACTION":"自由行动","ATTACK_REACTION":"进攻响应","DEFENSE_REACTION":"防御响应"}.get(str(usage.get("timing","")),""))
	var target: Dictionary=usage.get("target",{})
	var profile: Dictionary=usage.get("attack_profile",{})
	if target.get("kind","")=="enemy_actor" and (profile.has("range") or target.has("max_distance")):
		result.append("正交直线 %d–%d格" % [int(target.get("min_distance",profile.get("min_range",1))),int(profile.get("range",target.get("max_distance",1)))])
	for effect in usage.get("effects",[]):
		match str(effect.get("type","")):
			"deal_damage":
				result.append("基础伤害 %.1f" % float(effect.get("amount",0)))
				var condition: Dictionary=effect.get("conditional_bonus",{})
				if condition.has("if_target_status"): result.append("敌有%s伤害+%s" % [_status_name(str(condition.if_target_status)),condition.get("bonus",0)])
				if condition.has("bonus_per_target_status"): result.append("敌每层%s伤害+%s" % [_status_name(str(condition.bonus_per_target_status)),condition.get("bonus_each",0)])
				if condition.has("if_self_shield_gt"): result.append("自身护体>%s时伤害+%s" % [condition.if_self_shield_gt,condition.get("bonus",0)])
				if condition.has("if_self_hp_pct_lt_after_cost"): result.append("付费后气血<%.0f%%伤害+%s" % [float(condition.if_self_hp_pct_lt_after_cost)*100,condition.get("bonus",0)])
				if not str(condition.get("consume_on_hit","")).is_empty(): result.append("命中消耗%s" % _status_name(str(condition.consume_on_hit).replace("_all","")))
			"move": result.append("移动 ≤%d 格" % int(effect.get("max_distance",1)))
			"force_move": result.append(("击退" if effect.get("direction","")=="away_from_attacker" else "拉近")+"≤%d格" % int(effect.get("max_distance",1)))
			"gain_qi": result.append("回气 +%s" % effect.get("amount",0))
			"apply_status": result.append("%s%s +%d层" % ["自身" if effect.get("target","")=="self" else "目标",_status_name(str(effect.get("status_id",""))),int(effect.get("stacks",1))])
			"consume_status": result.append("消耗%s" % _status_name(str(effect.get("status_id",""))))
			"draw_cards": result.append("抽%d张牌" % int(effect.get("count",1)))
			"add_shield": result.append("护体 +%.1f" % float(effect.get("amount",0)))
			"modify_pending_damage":
				var change: float=float(effect.get("flat_delta",-float(effect.get("reduction",0))))
				result.append("本击伤害 %s%.1f" % ["+" if change>=0 else "−",absf(change)])
			"modify_attack_area": result.append("扩展攻击区域")
			"cancel_chain_link": result.append("取消选定敌方响应")
			"contest_intercept": result.append("迎击判定，成功中断攻击")
			"on_attack_hit": result.append("命中："+_nested_effect_summary(effect))
			"on_attack_miss": result.append("落空："+_nested_effect_summary(effect))
	return " / ".join(result)

func _nested_effect_summary(effect: Dictionary) -> String:
	var children: Dictionary={"effects":effect.get("effects",effect.get("on_hit",[]))}
	return _usage_summary(children).trim_prefix(" / ")

func _wrap_text(value: String, width: float, size: int) -> PackedStringArray:
	var lines: PackedStringArray=[]
	var line: String=""
	for character in value:
		if body_font.get_string_size(line+character,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
			lines.append(line)
			line=""
		line+=character
	if not line.is_empty(): lines.append(line)
	return lines





func _visible_logs() -> Array:
	var entries: Array=[]
	for entry in snap.get("logs",[]):
		if not str(entry.get("text","")).strip_edges().is_empty(): entries.append(entry)
	return entries

func _quoted_cost(usage: Dictionary) -> Dictionary:
	return usage.get("quoted_cost",usage.get("cost",{}))

func _attack_cells() -> Array:
	return snap.get("attack",{}).get("affected_cells",[]) if snap.get("phase","")=="CLASH" else []

func _draw_attack_area() -> void:
	for cell in _attack_cells():
		if snap.terrain.has(cell): _tile(cell,Color(.72,.28,.22,.12),RED,2.5)
