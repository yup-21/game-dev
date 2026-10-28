extends Node2D
## Presentation consumes the observer projection; all gameplay enters request/submit.
const Model = preload("res://scripts/battle_model.gd")
const AI = preload("res://scripts/enemy_ai.gd")
const PAPER = Color("eeeade")
const INK = Color("243f3e")
const MUTED = Color("718279")
const JADE = Color("2f7770")
const GOLD = Color("ad8047")
const RED = Color("b45d50")
const BOARD = Rect2(24, 206, 1124, 454)
const ORIGIN = Vector2(78, 252)
const TILE = Vector2(70, 39)
var model = Model.new()
var enemy_ai = AI.new()
var player_policy = AI.new()
var snap: Dictionary = {}
var legals: Array = []
var body_font: SystemFont
var title_font: SystemFont
var started = false
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
var movements: Dictionary = {}
var log_scroll = 0
var check_mode = false
var qa_auto = false
var qa_failed = false
var qa_requests = 0
var passive_settings: Dictionary = {0:{"insight":0,"conceal":0},1:{"insight":0,"conceal":0}}

func _ready() -> void:
	body_font = SystemFont.new()
	body_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Segoe UI"])
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["KaiTi", "STKaiti", "Microsoft YaHei"])
	DisplayServer.window_set_min_size(Vector2i(1040,650))
	model.reset(2026,0,"tingfeng",{"passives":passive_settings})
	_sync()
	check_mode = "--tingfeng-visual-check" in OS.get_cmdline_user_args()
	print("TINGFENG_DUEL_READY seed=",snap.seed," board=15x10 mode=",snap.get("mode","ACTION"))
	if check_mode:
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
	usage_choices.clear()
	mode = "move"

func _decision_actor() -> int:
	return int(snap.get("clash",{}).get("priority_actor_id",snap.responder_id)) if snap.phase == "CLASH" else int(snap.active_id)

func _process(delta: float) -> void:
	wall += delta
	notice_left = maxf(0,notice_left-delta)
	for i in range(effects.size()-1,-1,-1):
		effects[i].left -= delta
		if effects[i].left <= 0: effects.remove_at(i)
	for id in movements.keys():
		movements[id].elapsed += delta
		if movements[id].elapsed >= movements[id].duration: movements.erase(id)
	if started and not help_open:
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
		match str(event.get("type","")):
			"MOVE":
				var points: Array = [cell_to_screen(event["from"])]
				for cell in event.get("path",[event["to"]]): points.append(cell_to_screen(cell))
				if points.size()>1: movements[event.actor_id] = {"points":points,"elapsed":0.0,"duration":0.04 if check_mode else maxf(0.20,(points.size()-1)*0.18)}
			"DAMAGE": effects.append({"actor_id":event.get("defender_id",event.get("actor_id",0)),"left":0.85,"text":"−%.1f" % float(event.get("hp_damage",0)),"color":RED})
			"SHIELD": effects.append({"actor_id":event.actor_id,"left":0.85,"text":"护体","color":JADE})
			"COMBO_TRIGGERED": effects.append({"actor_id":event.actor_id,"left":1.2,"text":str(event.get("name","连携")),"color":GOLD})
	if not result.get("events",[]).is_empty():
		presentation_left = 0.02 if check_mode else 0.28
		for movement in movements.values(): presentation_left = maxf(presentation_left,movement.duration-movement.elapsed)
		log_scroll = 0
	_sync()

func _can_player() -> bool:
	return started and not help_open and snap.outcome == "playing" and not snap.animation_pending and _decision_actor()==0

func _submit(kind: String, params: Dictionary = {}) -> void:
	if not _can_player():
		_toast("等待动作表现完成或对方交还优先权。")
		return
	_consume(model.submit(model.request(kind,0,params)))

func _submit_legal(req: Dictionary) -> void:
	var params: Dictionary = {}
	for key in ["card_uid","card_id","usage_id","target_cell","target_id","link_id"]:
		if req.has(key): params[key] = req[key]
	_submit(str(req.kind),params)

func _toast(value: String) -> void:
	notice = value
	notice_left = 3.2

func _restart(_profile: String = "tingfeng") -> void:
	model.reset(int(snap.get("seed",2026)),0,"tingfeng",{"passives":passive_settings.duplicate(true)})
	enemy_ai = AI.new()
	player_policy = AI.new()
	_clear_selection()
	movements.clear()
	effects.clear()
	presentation_left = 0
	next_decision = wall+0.65
	started = true
	help_open = false
	log_scroll = 0
	_sync()
	_toast("已应用双方观势 / 藏锋等级，按相同种子重新集气。")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion: mouse = event.position
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_H,KEY_ESCAPE:
				if not usage_choices.is_empty(): usage_choices.clear()
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
		mouse = event.position
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and Rect2(1170,766,406,204).has_point(mouse):
			log_scroll = clampi(log_scroll+(2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -2),0,maxi(0,_visible_logs().size()-6))
			return
		if event.button_index==MOUSE_BUTTON_RIGHT:
			if not usage_choices.is_empty() or mode in ["card","link","pitch"]:
				_clear_selection(); _toast("已取消选择。")
				return
		if event.button_index==MOUSE_BUTTON_LEFT:
			for button in buttons:
				if button.rect.has_point(mouse):
					if button.enabled: _button_action(button.action)
					else: _toast(button.get("reason","当前时机或资源不允许"))
					return
		if help_open or not usage_choices.is_empty() or not _can_player(): return
		if BOARD.has_point(mouse):
			var cell = screen_to_cell(mouse)
			if Rect2(_unit_pos(1)+Vector2(-24,-45),Vector2(48,64)).has_point(mouse): cell = snap.actors[1].cell
			if not snap.terrain.has(cell): return
			if mode=="card":
				for req in _usage_actions(selected_card,selected_usage):
					if (req.has("target_cell") and req.target_cell==cell) or (req.has("target_id") and int(req.target_id)>=0 and int(req.target_id)<snap.actors.size() and cell==snap.actors[int(req.target_id)].cell):
						_submit_legal(req); return
				_toast("该目标不合法，请选择高亮落点或敌人。")
			elif mode=="link": _toast("请点击右侧连锁中高亮的敌方响应。")
			elif cell==snap.actors[1].cell and event.button_index==MOUSE_BUTTON_RIGHT: _submit("BASIC_ATTACK",{"target_id":1})
			else: _submit("MOVE",{"target_cell":cell})

func _advance() -> void:
	_submit("PASS_REACTION" if snap.phase=="CLASH" else "END_ACTION")

func _button_action(action: String) -> void:
	match action:
		"start": started = true
		"restart": _restart()
		"help": help_open = not help_open
		"advance": _advance()
		"attack": _submit("BASIC_ATTACK",{"target_id":1})
		"guard": _submit("BASIC_GUARD")
		"move": _clear_selection(); _toast("选择高亮格普通移动；每格消耗气，预算随敏捷变化。")
		"pitch": _clear_selection(); mode="pitch"; _toast("点击要弃置的手牌回气。")
		"cancel": _clear_selection()
		_:
			if action.begins_with("card:"):
				if displayed_revision==snap.revision: _choose_card(_find_hand(action.substr(5)))
			elif action.begins_with("usage:"):
				usage_choices.clear()
				_apply_usage(usage_card,action.substr(6))
			elif action.begins_with("link:"):
				for req in _usage_actions(selected_card,selected_usage):
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
	draw_rect(Rect2(0,0,1600,1000),PAPER)
	_draw_header()
	_draw_timeline()
	_draw_board()
	_draw_actors()
	_draw_hand()
	_draw_sidebar()
	for effect in effects:
		var color: Color = effect.color
		color.a = clampf(effect.left/0.85,0,1)
		_center(_unit_pos(effect.actor_id)+Vector2(0,-48-(0.85-effect.left)*25),effect.text,25,color)
	if notice_left>0 and started and snap.outcome=="playing":
		_panel(Rect2(172,621,830,28),Color("254e46"))
		_center(Vector2(587,641),notice,14,PAPER)
	_text(Vector2(30,991),"右键移动 / 攻击   1–5 查看用法   Q 攻击   G 格挡   C 弃牌   M 移动   Space / Enter 结束行动或 Pass   H 帮助   R 重开",13,MUTED)
	if not started: _draw_intro()
	elif snap.outcome!="playing": _draw_result()
	if help_open: _draw_help()
	if not usage_choices.is_empty(): _draw_usage_picker()

func _draw_header() -> void:
	draw_rect(Rect2(0,0,1600,126),Color("173f3d"))
	draw_line(Vector2(24,126),Vector2(1576,126),GOLD,2)
	_panel(Rect2(34,28,42,62),RED)
	_center(Vector2(55,54),"长",23,PAPER,true)
	_center(Vector2(55,80),"风",23,PAPER,true)
	_text(Vector2(94,67),"长风浮生录",43,PAPER,true)
	_text(Vector2(98,96),"断桥论剑  /  听风五式 · 自由行动",14,Color("aebfb1"))
	_text(Vector2(460,57),"听风辨势，见招拆招。",26,Color("ded8be"),true)
	_text(Vector2(462,88),"集气轮转  ·  一牌多用  ·  连锁逆序结算",15,Color("aebfb1"))
	_text(Vector2(940,57),"行动 %d" % int(snap.get("action_no",1)),22,PAPER,true)
	_text(Vector2(940,88),"tick %d  /  种子 %d" % [int(snap.get("global_tick",0)),snap.seed],13,Color("aebfb1"))
	_small_button(Rect2(1200,35,168,48),"H  听风规则","help",true,true)
	_small_button(Rect2(1388,35,168,48),"R  同种子重开","restart",true,true)

func _draw_timeline() -> void:
	for i in range(2):
		var actor: Dictionary = snap.actors[i]
		var rect = Rect2(24+i*566,146,558,48)
		_panel(rect,Color("e1e5d7"),JADE if snap.active_id==i else Color("cbd1bf"))
		_text(rect.position+Vector2(12,21),"%s · 集气 %.0f / 10000" % [actor.name,float(actor.get("gauge",0))],15,INK)
		_text(rect.position+Vector2(300,21),"速度 %.1f" % float(actor.get("charge_speed",0)),14,MUTED)
		_text(rect.position+Vector2(404,21),"交锋停表" if snap.phase=="CLASH" else ("自由行动" if snap.active_id==i else "等待集气"),14,GOLD)
		_bar(Rect2(rect.position+Vector2(12,32),Vector2(530,6)),float(actor.get("gauge",0))/10000.0,JADE if i==0 else RED)

func _draw_hand() -> void:
	_panel(Rect2(24,678,1124,292),Color("f7f4e9"),Color("c9d1c0"))
	_text(Vector2(44,709),"听 风 五 式",17,GOLD)
	_text(Vector2(240,709),"手牌 %d  抽牌 %d  弃牌 %d  结算 %d · 一张牌只选一种用法" % [int(snap.actors[0].hand_count),int(snap.actors[0].draw_count),int(snap.actors[0].discard_count),int(snap.actors[0].resolving_count)],13,MUTED)
	_text(Vector2(870,709),"选牌弃置回气" if mode=="pitch" else "点牌展开全部分支",14,JADE)
	var count: int = maxi(5,snap.hand.size())
	var width: float = 1100.0/count
	for i in range(count):
		var rect = Rect2(40+i*width,731,width-13,188)
		if i>=snap.hand.size():
			_panel(rect,Color("e8e9de")); _center(rect.position+Vector2(rect.size.x/2,100),"空",26,MUTED,true); continue
		var card: Dictionary = snap.hand[i]
		var enabled = _card_enabled(card)
		_panel(rect,Color("faf7eb") if enabled else Color("e5e6dc"),GOLD if _uid(card)==selected_card else Color("c9d1c0"))
		_text(rect.position+Vector2(14,25),"%d  招式 · %d 用法" % [i+1,card.get("usages",[]).size()],13,GOLD)
		_text(rect.position+Vector2(14,65),str(card.name),27,INK if enabled else MUTED,true)
		var usages: Array = card.get("usages",[])
		for u in range(mini(3,usages.size())):
			var usage: Dictionary = usages[u]
			var usable = not _usage_actions(_uid(card),str(usage.id)).is_empty()
			_text(rect.position+Vector2(14,95+u*22),_trim("%s  %.1f气" % [usage.get("name",usage.id),float(_quoted_cost(usage).get("qi",0))],rect.size.x-25,12),12,JADE if usable else MUTED)
		_text(rect.position+Vector2(14,173),_trim(_reason(card),rect.size.x-25,12),12,GOLD)
		buttons.append({"rect":rect,"action":"card:"+_uid(card),"enabled":enabled,"reason":_reason(card)})
	for i in range(4):
		var who = i/2
		var talent = "insight" if i%2==0 else "conceal"
		var label = ("我方" if who==0 else "敌方")+("观势" if talent=="insight" else "藏锋")
		_small_button(Rect2(40+i*209,932,198,29),"%s  %d  ↻" % [label,int(passive_settings[who][talent])],"passive:%d:%s" % [who,talent],true)
	_small_button(Rect2(881,932,248,29),"应用等级并重新开战","restart",true)

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
		_text(rect.position+Vector2(15,103),_trim("已知敌牌："+" / ".join(details) if i==1 else " / ".join(details),374,12),12,GOLD)
	_panel(Rect2(1170,394,406,170),Color("e4e9dd"),Color("c3cebc"))
	var clash: Dictionary = snap.get("clash",{})
	var is_clash: bool = snap.phase=="CLASH"
	_text(Vector2(1189,421),("你的优先权" if _decision_actor()==0 else "对手优先权") if is_clash else ("你的自由行动" if snap.active_id==0 else "对手自由行动"),23,JADE if _can_player() else GOLD,true)
	_text(Vector2(1189,443),"LIFO 逆序 · 我%d/2 敌%d/2 · Pass %d/2" % [int(clash.get("counts",{}).get(0,0)),int(clash.get("counts",{}).get(1,0)),int(clash.get("consecutive_passes",0))] if is_clash else "移动、攻防、出牌可自由穿插；结束行动后集气。",12,MUTED)
	var stack: Array = clash.get("stack",[])
	for i in range(mini(4,stack.size())):
		var link: Dictionary = stack[stack.size()-1-i]
		var id = str(link.get("link_id",link.get("id","")))
		var legal_link = false
		if mode=="link":
			for req in _usage_actions(selected_card,selected_usage):
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
	_panel(rect,Color("264e48") if dark else (JADE if enabled else Color("dce2d5")),GOLD if rect.has_point(mouse) else Color("bbcbb6"))
	_center(rect.position+Vector2(rect.size.x/2,rect.size.y/2+6),title,14,PAPER if enabled else MUTED)
	buttons.append({"rect":rect,"action":action,"enabled":enabled,"reason":"当前时机、距离、气或移动预算不足"})

func _draw_usage_picker() -> void:
	# Modal buttons supersede all underlying input regions.
	buttons.clear()
	draw_rect(Rect2(0,126,1600,874),Color(.08,.20,.17,.5))
	var rect = Rect2(310,305,780,118+usage_choices.size()*82)
	_panel(rect,PAPER,GOLD)
	_text(rect.position+Vector2(26,42),"选择「%s」的用法" % usage_card.name,28,INK,true)
	for i in range(usage_choices.size()):
		var usage: Dictionary = usage_choices[i]
		var usable = not _usage_actions(_uid(usage_card),str(usage.id)).is_empty() and _can_player()
		var cost: Dictionary = _quoted_cost(usage)
		var label = "%s  ·  %.1f气%s" % [usage.get("name",usage.id),float(cost.get("qi",0))," / %.1f气血" % float(cost.get("hp",0)) if float(cost.get("hp",0))>0 else ""]
		_small_button(Rect2(rect.position+Vector2(26,66+i*82),Vector2(728,43)),label,"usage:"+str(usage.id),usable)
		buttons.back().reason = _usage_reason(usage_card,usage)
		_text(rect.position+Vector2(31,128+i*82),_usage_summary(usage)+" · "+_usage_reason(usage_card,usage),13,JADE if usable else RED)
	_small_button(Rect2(rect.position+Vector2(575,rect.size.y-40),Vector2(180,28)),"取消  右键 / Esc","cancel",true)

func _draw_intro() -> void:
	buttons.clear()
	draw_rect(Rect2(0,126,1600,874),Color(.08,.20,.17,.48))
	_panel(Rect2(337,247,926,505),Color("f4f0e1"),Color("b7bda7"))
	_text(Vector2(382,297),"断 桥 论 剑  /  听 风 五 式",15,GOLD)
	_text(Vector2(379,359),"一式多变，听风而动。",44,INK,true)
	var lines = ["集气到达阈值后自由行动：走位、出招、护身不再分阶段。","点一张手牌，选择合法分支；游身选择落点，截势选择响应层。","攻击触发 CLASH：守方先手，双方轮流响应或 Pass。","连锁后入先出；连续两次 Pass 开始结算，交锋期间全局停表。","观势 / 藏锋可在手牌下方设为 0 / 1 / 2 级，然后应用并重开。"]
	for i in range(lines.size()): _text(Vector2(384,414+i*40),lines[i],17,INK if i<3 else MUTED)
	_small_button(Rect2(625,653,350,54),"进入战场  Enter","start",true)
	_center(Vector2(800,735),"15 × 10 断桥  ·  四维属性决定能力与速度  ·  R 同种子重开",13,MUTED)

func _draw_result() -> void:
	draw_rect(BOARD,Color(.08,.20,.17,.58))
	_panel(Rect2(240,280,720,310),Color("f4f0e1"),Color("b7bda7"))
	_center(Vector2(600,345),"此役告捷" if snap.outcome=="victory" else "棋差一着",46,JADE if snap.outcome=="victory" else RED,true)
	_center(Vector2(600,397),"听风五式 · 此局终了",21,INK,true)
	_center(Vector2(600,437),"气血：你 %.1f / 对手 %.1f  ·  tick %d" % [float(snap.actors[0].hp),float(snap.actors[1].hp),int(snap.get("global_tick",0))],17,MUTED)
	_small_button(Rect2(425,486,350,54),"相同种子再战  R","restart",true)

func _draw_help() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1600,1000),Color(.06,.14,.13,.72))
	_panel(Rect2(295,175,1010,665),Color("f4f0e1"),Color("b7bda7"))
	_text(Vector2(340,231),"听风五式 · 自由行动与连锁",36,INK,true)
	var lines = ["集气阈值 10000；速度取决于敏捷。内息随全局逻辑时间恢复。","获得行动后自由移动、出牌、攻防；Space / Enter 结束行动。","攻击声明进入 CLASH，防御方先获得优先权；双方轮流响应或 Pass。","每方最多响应 2 张、总共 4 张；连续两次 Pass 后，从栈顶逆序结算。","游身可主动移动或响应避锋；变锋截势需选择敌方某一层响应。","卡牌先展开分支，灰色用法显示气不足、时机或目标限制，不扣资源。","四维属性、集气速度、气血、内息与移动预算显示在角色栏。","观势严格高于对方藏锋才识破；明牌覆盖藏锋，已见手牌保留记忆。","敌方手牌仅显示已知事实；危表示高威胁牌，？表示危险提示被隐藏。","1–5 选牌；Q 攻击 / G 格挡 / C 弃牌 / M 移动；R 重开；H / Esc 关闭。"]
	for i in range(lines.size()): _text(Vector2(340,280+i*40),lines[i],16,INK if i<5 else MUTED)
	_small_button(Rect2(625,742,350,48),"返回战场  H / Esc","help",true)

func _draw_board() -> void:
	_panel(BOARD, Color("dfe5d7"), Color("bfcbbc"))
	for cell in snap.terrain:
		var terrain: String = snap.terrain[cell]
		var pos = cell_to_screen(cell)
		var noise = sin(cell.x*14.1+cell.y*31.7)*0.018
		var color = Color(0.81+noise,0.84+noise,0.74+noise)
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
	_draw_attack_area()
	if _can_player():
		for req in legals:
			var selected: bool = mode=="card" and req.kind=="PLAY_CARD" and str(req.get("card_uid",req.get("card_id","")))==selected_card and str(req.get("usage_id",""))==selected_usage
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
		draw_set_transform(pos+Vector2(0,7),0,Vector2(1,.4))
		draw_circle(Vector2.ZERO,21,Color(.1,.19,.17,.22))
		draw_set_transform(Vector2.ZERO)
		draw_arc(pos,26,0,TAU,36,color,2.5,true)
		if snap.active_id==actor.id:
			draw_arc(pos,30,wall*.25,wall*.25+TAU*.8,36,Color(color,.5),2,true)
		var robe = Color("497a72") if actor.id==0 else Color("936357")
		draw_colored_polygon(PackedVector2Array([pos+Vector2(-10,-24),pos+Vector2(8,-24),pos+Vector2(17,7),pos+Vector2(0,14),pos+Vector2(-15,6)]),robe)
		draw_colored_polygon(PackedVector2Array([pos+Vector2(-4,-23),pos+Vector2(4,-23),pos+Vector2(8,6),pos+Vector2(-4,10)]),robe.lightened(.18))
		draw_circle(pos+Vector2(0,-31),9,Color("d7ba91"))
		draw_arc(pos+Vector2(0,-32),9,PI,TAU,15,Color("354542"),6,true)
		draw_circle(pos+Vector2(-3,-42),4,Color("354542"))
		var direction = 1 if actor.id==0 else -1
		draw_line(pos+Vector2(10*direction,-15),pos+Vector2(37*direction,-15),Color("f1e9ca"),3,true)
		_bar(Rect2(pos+Vector2(-28,-59),Vector2(56,5)),float(actor.hp)/maxf(1,float(actor.get("max_hp",20))),color)
		if actor.shield>0:
			draw_arc(pos,34,-PI*.9,-PI*.1,24,Color("d2ad69"),3,true)
		_center(pos+Vector2(0,37),"%s  %.1f" % [actor.name,float(actor.hp)],14,color.darkened(.15))
		var status_labels: PackedStringArray=[]
		for status_id in actor.get("statuses",{}):
			status_labels.append({"opening":"露隙","hand_exposed":"明牌"}.get(str(status_id),str(status_id)))
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

func _usage_summary(usage: Dictionary) -> String:
	var result: PackedStringArray = []
	result.append({"ACTION":"自由行动","ATTACK_REACTION":"进攻响应","DEFENSE_REACTION":"防御响应"}.get(str(usage.get("timing","")),""))
	for effect in usage.get("effects",[]):
		match str(effect.get("type","")):
			"deal_damage": result.append("基础伤害 %.1f" % float(effect.get("amount",0)))
			"move": result.append("移动 ≤%d 格" % int(effect.get("max_distance",1)))
			"add_shield": result.append("护体 +%.1f" % float(effect.get("amount",0)))
			"modify_pending_damage": result.append("本击伤害 −%.1f" % float(effect.get("reduction",-float(effect.get("flat_delta",0)))))
			"modify_attack_area": result.append("扩展攻击区域")
			"cancel_chain_link": result.append("取消选定敌方响应")
			"contest_intercept": result.append("迎击判定，成功中断攻击")
			"on_attack_hit": result.append("命中使敌方明牌")
			"on_attack_miss": result.append("落空时自身露隙")
	return " / ".join(result)





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
