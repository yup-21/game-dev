extends Node2D
## Multi-combatant tactics view: all commands use BattleModel.request/submit.
## The same EnemyAI policy drives allied NPCs and hostile NPCs.
const Model = preload("res://scripts/battle_model.gd")
const AI = preload("res://scripts/enemy_ai.gd")
const Navigation = preload("res://scripts/demo_navigation.gd")
const Art = preload("res://scripts/battle_art.gd")
const Sfx = preload("res://scripts/demo_sfx.gd")
const INK = Color("213939")
const PAPER = Color("e9e8da")
const JADE = Color("3a8980")
const RED = Color("b36358")
const GOLD = Color("b38c52")
const BOARD = Rect2(30,155,1038,625)
const ORIGIN = Vector2(61,184)
const TILE = Vector2(68,55)
const COMMANDS = Rect2(1090,155,474,800)
var model = Model.new()
var policy = AI.new()
var art = Art.new()
var sound = Sfx.new()
var paused_ui: bool=false
var font: SystemFont
var title_font: SystemFont
var snap: Dictionary = {}
var legal: Array=[]
var groups: Array=[]
var buttons: Array=[]
var selected_key: String=""
var page: int=0
var left: float=0.0
var tick: float=0.0
var ai_delay: float=0.0
var cue: Array=[]
var mouse: Vector2=Vector2(-100,-100)
var feedback: String=""
var story_encounter: bool=false

func _session():
	return get_node_or_null("/root/GameSession")

func _reset_battle() -> void:
	var session=_session()
	story_encounter=session!=null and session.phase=="battle"
	if story_encounter:
		model.reset(session.encounter_seed(),0,"tingfeng",session.encounter_options())
		if bool(session.flags.get("studied_fragment",false)) and model.state.outcome=="playing":
			var player=model.state.get_actor(0)
			if player!=null:
				var uid: String=model.cards.create_instance(player,"taixu_open","hand")
				if uid.is_empty(): push_error("Demo Taixu entry card not registered")
	else:
		model.reset(2026,0,"tingfeng",{"combatants":_roster()})
	policy=AI.new()
	cue.clear()
	selected_key=""
	_sync()

func _go(path: String) -> void:
	var err: int=get_tree().change_scene_to_file(path)
	if err!=OK: push_error("Unable to open scene: "+path)

func _go_result() -> void:
	if story_encounter and snap.outcome!="playing":
		call_deferred("_go","res://demo_result.tscn")

func _go_menu() -> void:
	var session=_session()
	if session!=null: session.return_to_menu()
	call_deferred("_go","res://opening.tscn")

func _roster() -> Array:
	return [
		{"id":0,"name":"沈长风","team_id":0,"controller":"PLAYER","cell":[6,4]},
		{"id":2,"name":"顾清霜","team_id":0,"controller":"PLAYER","cell":[5,5]},
		{"id":3,"name":"青衫客","team_id":0,"controller":"AI","cell":[5,3]},
		{"id":1,"name":"拦江客","team_id":1,"controller":"AI","cell":[8,4]},
		{"id":4,"name":"铁衣卫","team_id":1,"controller":"AI","cell":[9,5]},
		{"id":5,"name":"夜行刀","team_id":1,"controller":"AI","cell":[9,3]}
	]

func _ready() -> void:
	add_child(sound)
	font=SystemFont.new()
	font.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC","Segoe UI"])
	title_font=SystemFont.new()
	title_font.font_names=PackedStringArray(["KaiTi","STKaiti","Microsoft YaHei"])
	DisplayServer.window_set_min_size(Vector2i(1100,750))
	_reset_battle()
	print("PARTY_BATTLE_READY actors=",snap.actors.size()," player_units=2 allied_ai=1 enemy_ai=3")

func _current_id() -> int:
	if snap.get("phase","")=="CLASH": return int(snap.get("responder_id",-1))
	return int(snap.get("active_id",-1))

func _current_actor() -> Dictionary:
	for a in snap.get("actors",[]):
		if int(a.id)==_current_id(): return a
	return {}

func _human_turn() -> bool:
	var actor: Dictionary=_current_actor()
	return not actor.is_empty() and str(actor.get("controller","AI"))=="PLAYER" and snap.get("outcome","playing")=="playing" and not snap.get("animation_pending",false)

func _sync() -> void:
	var previous: int=_current_id() if not snap.is_empty() else -1
	var prior_phase: String=str(snap.get("phase",""))
	snap=model.snapshot(_current_id() if not snap.is_empty() and model.state.get_actor(_current_id())!=null else 0)
	var actor_id: int=_current_id()
	if previous!=actor_id or prior_phase!=str(snap.phase):
		selected_key=""
		page=0
	if model.state.get_actor(actor_id)!=null:
		# Legal actions are the only source of command buttons or targets.
		legal=model.legal_actions(actor_id)
	else: legal=[]
	groups.clear()
	var seen: Dictionary={}
	for action in legal:
		var key: String=_key(action)
		if not seen.has(key):
			seen[key]=true
			groups.append({"key":key,"label":_label(action)})
	page=clampi(page,0,maxi(0,ceili(groups.size()/11.0)-1))
	var session=_session()
	if story_encounter and snap.outcome!="playing" and session!=null and session.phase=="battle":
		session.capture_battle_progress(model)
		session.report_battle(str(snap.outcome),int(snap.get("winning_team",-1)))
	if not selected_key.is_empty() and _candidates().is_empty(): selected_key=""

func _key(action: Dictionary) -> String:
	var kind: String=str(action.get("kind",""))
	if kind=="PLAY_CARD": return kind+":"+str(action.get("card_uid",""))+":"+str(action.get("usage_id",""))
	if kind=="USE_ABILITY": return kind+":"+str(action.get("technique_id",""))+":"+str(action.get("node_id",""))
	if kind=="PITCH_CARD": return kind+":"+str(action.get("card_uid",""))
	if kind=="RESET_TECHNIQUE": return kind+":"+str(action.get("technique_id",""))
	return kind

func _label(action: Dictionary) -> String:
	var kind: String=str(action.kind)
	match kind:
		"END_ACTION": return "收势 · 结束本次行动"
		"PASS_REACTION": return "不追加应变 · Pass"
		"MOVE": return "移步 · 选择高亮格"
		"BASIC_ATTACK": return "普通攻击 · 选择敌人"
		"BASIC_GUARD": return "护体防守 · 1气"
		"PITCH_CARD": return "弃牌调息 · "+str(model.cards.canonical_definition(str(action.card_uid)).get("name",""))
		"USE_ITEM": return "使用丹药 · "+str(model.inventory.item(str(action.item_id)).get("name",""))
		"PLAY_CARD":
			var d: Dictionary=model.cards.canonical_definition(str(action.card_uid))
			var u: Dictionary=model.cards.usage(str(action.card_uid),str(action.usage_id))
			return str(d.get("name","卡牌"))+" · "+str(u.get("name",action.usage_id))
		"USE_ABILITY": return "武学续式 · "+str(action.node_id)
		"RESET_TECHNIQUE": return "收招复位 · "+str(action.technique_id)
	return kind

func _candidates() -> Array:
	var entries: Array=[]
	for a in legal:
		if _key(a)==selected_key: entries.append(a)
	return entries

func _submit(action: Dictionary) -> void:
	var id: int=_current_id()
	var response: Dictionary=model.submit(model.request(str(action.kind),id,action))
	if not response.get("success",false):
		feedback=str(response.get("message","无法执行"))
		return
	for e in response.get("events",[]):
		var kind: String=str(e.get("type",""))
		sound.cue(kind)
		if kind in ["DAMAGE","ATTACK_DECLARED","ATTACK_MISSED","SHIELD","COMBO_TRIGGERED","MOVE"]:
			var who: int=int(e.get("defender_id",e.get("target_id",e.get("actor_id",-1))))
			cue.append({"id":who,"kind":kind,"left":0.55})
	feedback=str(action.kind)+" · "+str(model.state.get_actor(id).name)
	left=0.16
	selected_key=""
	_sync()

func _process(delta: float) -> void:
	if paused_ui:
		queue_redraw()
		return
	tick+=delta
	for i in range(cue.size()-1,-1,-1):
		cue[i].left-=delta
		if cue[i].left<=0: cue.remove_at(i)
	if not snap.is_empty():
		if snap.animation_pending:
			left-=delta
			if left<=0:
				model.acknowledge_animation(snap.ticket)
				_sync()
		elif snap.outcome=="playing" and not _human_turn():
			ai_delay-=delta
			if ai_delay<=0:
				var id: int=_current_id()
				if model.state.get_actor(id)!=null:
					var move: Dictionary=policy.choose_action(model.decision_context(id))
					if not move.is_empty(): _submit(move)
				ai_delay=0.22
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion: mouse=event.position
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F10:
			_go_menu()
			return
		if event.keycode==KEY_P:
			paused_ui=not paused_ui
			return
		if paused_ui: return
		if event.keycode==KEY_R:
			var session=_session()
			if story_encounter and session!=null and session.phase=="aftermath": session.retry_encounter()
			_reset_battle()
			return
		if event.keycode==KEY_ESCAPE and snap.outcome!="playing":
			_go_menu()
			return
		if event.keycode in [KEY_ENTER,KEY_SPACE] and snap.outcome!="playing":
			_go_result()
			return
		if not _human_turn(): return
		if event.keycode==KEY_ESCAPE: selected_key=""; return
		if event.keycode in [KEY_SPACE,KEY_ENTER]:
			for action in legal:
				if action.kind in ["END_ACTION","PASS_REACTION"]:
					_submit(action)
					return
	if paused_ui: return
	if not event is InputEventMouseButton: return
	if not event.pressed: return
	if snap.outcome!="playing":
		if event.button_index==MOUSE_BUTTON_LEFT:
			for button in buttons:
				if button.rect.has_point(event.position):
					if str(button.action)=="story_result": _go_result()
					elif str(button.action)=="menu": _go_menu()
					return
		return
	if not _human_turn(): return
	if event.button_index==MOUSE_BUTTON_RIGHT:
		selected_key=""
		return
	if event.button_index!=MOUSE_BUTTON_LEFT: return
	for button in buttons:
		if button.rect.has_point(event.position):
			var action: String=str(button.action)
			if action=="prev": page=maxi(0,page-1); return
			if action=="next": page=mini(maxi(0,ceili(groups.size()/11.0)-1),page+1); return
			if action.begins_with("link:"):
				for option in _candidates():
					if int(option.get("link_id",-1))==int(action.substr(5)):
						_submit(option)
						break
			else:
				_choose(action)
			return
	if selected_key.is_empty() or not BOARD.has_point(event.position): return
	var cell: Vector2i=screen_to_cell(event.position)
	for option in _candidates():
		if (option.has("target_cell") and option.target_cell==cell) or (option.has("target_id") and model.state.get_actor(int(option.target_id))!=null and model.state.get_actor(int(option.target_id)).cell==cell):
			_submit(option)
			return
	feedback="请选择高亮目标或合法落点"

func _choose(key: String) -> void:
	selected_key=key
	var available: Array=_candidates()
	if available.is_empty(): return
	if available[0].has("target_id") or available[0].has("target_cell") or available[0].has("link_id"):
		feedback="选择地图目标或右侧响应层"
		return
	_submit(available[0])

func cell_to_screen(cell: Vector2i) -> Vector2:
	return ORIGIN+Vector2(cell)*TILE

func screen_to_cell(pos: Vector2) -> Vector2i:
	var x: int=roundi((pos.x-ORIGIN.x)/TILE.x)
	var y: int=roundi((pos.y-ORIGIN.y)/TILE.y)
	return Vector2i(x,y)

func _text(pos: Vector2, value: String, size: int=16, color: Color=INK, title: bool=false) -> void:
	draw_string(title_font if title else font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _tile(cell: Vector2i,color: Color) -> void:
	var rect: Rect2=Rect2(cell_to_screen(cell)-TILE*.5+Vector2(1,1),TILE-Vector2(2,2))
	draw_rect(rect,color)
	draw_rect(rect,Color(0.22,0.40,0.34,0.11),false,1)

func _draw() -> void:
	if snap.is_empty(): return
	buttons.clear()
	art.backdrop(self,tick)
	draw_rect(Rect2(0,0,1600,123),Color("163e3e"))
	_text(Vector2(36,64),"长风浮生录 · 断桥群战",36,Color("f3e9d5"),true)
	_text(Vector2(41,95),"同一套 CTB / 交锋 / 武学规则 · 多阵营战斗验证",14,Color("c0d4c2"))
	_text(Vector2(1110,59),"t=%d  行动 %d" % [int(snap.global_tick),int(snap.action_no)],20,Color("e6cf96"))
	_text(Vector2(1110,88),"R 重开  |  P 暂停  |  F10 主菜单  |  空格收势 / Pass",14,Color("c0d4c2"))
	draw_rect(BOARD,Color("dfe7dc"))
	for cell in snap.terrain:
		var terrain: String=str(snap.terrain[cell])
		var color: Color=Color("e1dfcc")
		if terrain=="water": color=Color("88b7b2")
		elif terrain=="bridge": color=Color("beac84")
		elif terrain=="ford": color=Color("b1c4ad")
		elif terrain=="bamboo": color=Color("729383")
		elif terrain=="rock": color=Color("929b8e")
		_tile(cell,color)
		if terrain=="water":
			var pos: Vector2=cell_to_screen(cell)
			for i in range(2):
				var offset: float=sin(tick*.65+cell.y+i)*5
				draw_line(pos+Vector2(-15+offset,-7+i*11),pos+Vector2(15+offset,-7+i*11),Color(1,1,1,.26),1.2)
		elif terrain=="bridge":
			for i in range(4):
				draw_line(cell_to_screen(cell)+Vector2(-28+i*17,-19),cell_to_screen(cell)+Vector2(-28+i*17,19),Color(0.36,0.27,0.18,.32),1)
	for option in _candidates():
		if option.has("target_cell"):
			draw_rect(Rect2(cell_to_screen(option.target_cell)-TILE*.5+Vector2(4,4),TILE-Vector2(8,8)),Color(JADE,.27),false,3)
		elif option.has("target_id"):
			var target=model.state.get_actor(int(option.target_id))
			if target!=null: draw_arc(cell_to_screen(target.cell),32,0,TAU,36,GOLD,3,true)
	for actor in snap.actors:
		var pos: Vector2=cell_to_screen(actor.cell)
		var alive: bool=float(actor.hp)>0
		var player_team: bool=int(actor.team_id)==0
		var base: Color=JADE if player_team else RED
		if not alive: base=Color("777d7d")
		art.combatant(self,pos,actor,tick,int(actor.id)==_current_id(),false)
		if str(actor.controller)=="PLAYER":
			draw_circle(pos+Vector2(18,-18),5,GOLD)
		_text(pos+Vector2(-30,48),str(actor.name),14,INK)
		draw_rect(Rect2(pos+Vector2(-25,-42),Vector2(50,6)),Color("c0c2b9"))
		draw_rect(Rect2(pos+Vector2(-25,-42),Vector2(50*clampf(float(actor.hp)/maxf(1,float(actor.max_hp)),0,1),6)),base)
		for effect in cue:
			if int(effect.id)==int(actor.id):
				var pulse: float=float(effect.left)/.55
				draw_arc(pos,32+(1-pulse)*35,0,TAU,32,Color(GOLD,pulse*.7),3,true)
	_text(Vector2(38,815),"● 金印：手动角色    ● 青色：友军    ● 朱色：敌军    ● 发光圆环：当前行动 / 应变角色",16,INK)
	for i in range(snap.actors.size()):
		var actor: Dictionary=snap.actors[i]
		var col: int=i%3
		var row: int=i/3
		var x: float=34+col*344
		var y: float=841+row*52
		draw_rect(Rect2(x,y,333,44),Color("f9f5e7"),false,1)
		_text(Vector2(x+7,y+17),str(actor.name)+" · "+("友" if int(actor.team_id)==0 else "敌")+" · "+("手动" if str(actor.controller)=="PLAYER" else "AI"),14,JADE if int(actor.team_id)==0 else RED)
		var natural_max: float=float(actor.get("base_max_hp",actor.max_hp))
		var hp_label: String="HP %.0f/%.0f" % [float(actor.hp),float(actor.max_hp)]
		if float(actor.max_hp)<natural_max: hp_label+=" (基础%.0f)" % natural_max
		_text(Vector2(x+7,y+35),"%s 气%.1f 集气%d" % [hp_label,float(actor.qi),int(actor.gauge)],12,INK)
	if paused_ui:
		Navigation.draw_pause(self,title_font)
		return
	draw_rect(COMMANDS,Color("f7f3e6"))
	draw_rect(COMMANDS,GOLD,false,2)
	var current: Dictionary=_current_actor()
	if current.is_empty(): return
	_text(Vector2(1108,193),"当前优先权 · "+str(current.name),24,JADE if int(current.team_id)==0 else RED,true)
	_text(Vector2(1108,223),("手动操作" if str(current.controller)=="PLAYER" else "AI 自动行动")+"  ·  "+str(snap.phase),16,INK)
	if snap.outcome!="playing":
		_text(Vector2(1110,290),"战斗结束："+str(snap.outcome),26,GOLD,true)
		_text(Vector2(1110,332),"获胜阵营："+str(snap.get("winning_team",-1)),17,INK)
		if story_encounter:
			var rect: Rect2=Rect2(1110,390,421,57)
			draw_rect(rect,JADE)
			_text(Vector2(1128,428),"查看剧情结算  Enter",21,Color("ffffff"))
			buttons.append({"rect":rect,"action":"story_result"})
		var back: Rect2=Rect2(1110,468,421,49)
		draw_rect(back,Color("c7c9b6"))
		_text(Vector2(1128,501),"返回主菜单  Esc",18,INK)
		buttons.append({"rect":back,"action":"menu"})
		return
	if not _human_turn():
		_text(Vector2(1110,285),"其他角色正在使用相同的规则自主行动。",15,INK)
		return
	_text(Vector2(1108,256),"可执行动作  %d 种 · 点击选择" % groups.size(),15,GOLD)
	var from: int=page*11
	var until: int=mini(groups.size(),from+11)
	for index in range(from,until):
		var entry: Dictionary=groups[index]
		var y: float=270+(index-from)*49
		var rect: Rect2=Rect2(1106,y,439,42)
		var active: bool=str(entry.key)==selected_key
		draw_rect(rect,JADE if active else Color("e1e8dc"))
		draw_rect(rect,GOLD if active or rect.has_point(mouse) else Color("a8b6a9"),false,2 if active else 1)
		_text(Vector2(rect.position.x+12,rect.position.y+27),str(entry.label),16,Color("fff7e5") if active else INK)
		buttons.append({"rect":rect,"action":str(entry.key)})
	if groups.size()>11:
		for button_id in ["prev","next"]:
			var pos: Vector2=Vector2(1110 if button_id=="prev" else 1350,833)
			var rect: Rect2=Rect2(pos,Vector2(184,40))
			draw_rect(rect,JADE)
			_text(pos+Vector2(20,26),"上一页" if button_id=="prev" else "下一页",16,Color("ffffff"))
			buttons.append({"rect":rect,"action":button_id})
	_text(Vector2(1110,905),"目标选择：地图高亮格 / 敌人头像",14,GOLD)
	if not feedback.is_empty(): _text(Vector2(1110,932),feedback.substr(0,28),14,INK)
	if selected_key!="":
		for option in _candidates():
			if option.has("link_id"):
				var link: int=int(option.link_id)
				var rect: Rect2=Rect2(1110,950-42*(link%3+1),400,36)
				draw_rect(rect,Color("ddd5b9"))
				_text(rect.position+Vector2(8,24),"应变链 L%d · 点击选择" % link,15,INK)
				buttons.append({"rect":rect,"action":"link:"+str(link)})

