extends Node2D
## Multi-combatant tactics view: all commands use BattleModel.request/submit.
## The same EnemyAI policy drives allied NPCs and hostile NPCs.
const Model = preload("res://scripts/battle_model.gd")
const AI = preload("res://scripts/enemy_ai.gd")
const Pixel = preload("res://scripts/ink_pixel_art.gd")
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
var pixel = Pixel.new()
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
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
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
	_queue_events(response.get("events",[]))
	feedback=str(action.kind)+" · "+str(model.state.get_actor(id).name)
	left=0.16
	selected_key=""
	_sync()

func _queue_events(events: Array) -> void:
	for event in events:
		var kind: String=""
		var label: String=""
		var source: int=int(event.get("actor_id",-1))
		var target: int=int(event.get("defender_id",event.get("target_id",source)))
		match str(event.get("type","")):
			"ATTACK_DECLARED": kind="attack"
			"DAMAGE":
				var damage: float=float(event.get("hp_damage",0))
				kind="damage" if damage>0 else "guard"
				label="−%.1f" % damage if damage>0 else "格挡"
			"SHIELD", "INTERCEPT_JUDGED":
				kind="guard"
				target=source
				label="护御"
			"ATTACK_MISSED":
				kind="evade"
				label="落空"
			"MOVE":
				kind="evade"
				target=source
			"COMBO_TRIGGERED":
				kind="combo"
				target=source
				label=str(event.get("name","连携"))
			"SCORCH_TICK":
				kind="damage"
				target=source
				label="灼痕 −%.1f" % float(event.get("damage",0))
		if kind.is_empty() or target<0: continue
		cue.append({"source_id":source,"target_id":target,"kind":kind,"text":label,"left":0.55,"duration":0.55})
		if cue.size()>32: cue.pop_front()

func _process(delta: float) -> void:
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

func _corners(rect: Rect2, color: Color, width: float = 2.0) -> void:
	for point in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
		var inward: Vector2=Vector2(1 if point.x==rect.position.x else -1,1 if point.y==rect.position.y else -1)
		draw_line(point,point+Vector2(inward.x*10,0),color,width)
		draw_line(point,point+Vector2(0,inward.y*10),color,width)

func _center(pos: Vector2, value: String, size: int, color: Color) -> void:
	_text(pos-Vector2(font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x*.5,0),value,size,color)

func _pose(actor_id: int, alive: bool) -> String:
	if not alive: return "dead"
	var result: String="idle"
	for effect in cue:
		var kind: String=str(effect.kind)
		if kind=="attack" and int(effect.source_id)==actor_id: result="attack"
		if int(effect.target_id)!=actor_id: continue
		if kind=="damage": result="hurt"
		elif kind=="guard": result="guard"
		elif kind=="evade": result="walk"
	return result

func _draw_combatant(actor: Dictionary, pos: Vector2) -> void:
	var friendly: bool=int(actor.team_id)==0
	var alive: bool=float(actor.hp)>0
	var accent: Color=JADE if friendly else RED
	var tint: Color=Color.WHITE if alive else Color(0.55,0.58,0.55,0.56)
	draw_rect(Rect2((pos+Vector2(-20,7)).round(),Vector2(40,8)),Color(INK,0.18))
	draw_rect(Rect2((pos+Vector2(-22,13)).round(),Vector2(44,3)),accent if alive else Color("777d7d"))
	if int(actor.id)==_current_id() and alive:
		_corners(Rect2(pos+Vector2(-29,-36),Vector2(58,55)),GOLD,3)
		draw_rect(Rect2(pos+Vector2(-3,18),Vector2(6,4)),GOLD)
	pixel.character(self,pos+Vector2(0,12),int(actor.id),tick,_pose(int(actor.id),alive),3.0,not friendly,tint)
	if float(actor.get("shield",0))>0:
		pixel.badge(self,Rect2(pos+Vector2(-29,-28),Vector2(14,14)),"guard",GOLD)

func _draw_combatant_hud(actor: Dictionary, pos: Vector2) -> void:
	var accent: Color=JADE if int(actor.team_id)==0 else RED
	if float(actor.hp)<=0: accent=Color("777d7d")
	var hp: float=clampf(float(actor.hp)/maxf(1,float(actor.max_hp)),0,1)
	draw_rect(Rect2(pos+Vector2(-27,-45),Vector2(54,7)),INK)
	draw_rect(Rect2(pos+Vector2(-26,-44),Vector2(52,5)),Color("d0cfba"))
	if hp>0: draw_rect(Rect2(pos+Vector2(-26,-44),Vector2(maxf(1,floorf(52*hp)),5)),accent)
	var manual: bool=str(actor.controller)=="PLAYER"
	draw_rect(Rect2(pos+Vector2(17,-30),Vector2(14,14)),GOLD if manual else accent)
	_text(pos+Vector2(18,-19),"手" if manual else "AI",10 if manual else 8,PAPER)
	pixel.panel(self,Rect2(pos+Vector2(-34,22),Vector2(68,17)),false,accent)
	_center(pos+Vector2(0,35),str(actor.name),12,accent.darkened(0.2))

func _draw_combat_cues(positions: Dictionary) -> void:
	for effect in cue:
		var target: int=int(effect.target_id)
		if not positions.has(target): continue
		var progress: float=clampf(1.0-float(effect.left)/maxf(0.01,float(effect.duration)),0,1)
		var kind: String=str(effect.kind)
		var pos: Vector2=positions[target]+Vector2(0,-11)
		var source: int=int(effect.source_id)
		if kind=="attack" and positions.has(source):
			var start: Vector2=positions[source]+Vector2(0,-11)
			pixel.effect(self,start.lerp(pos,clampf(progress*2.0,0,1)),kind,progress,0.9)
		pixel.effect(self,pos,kind,progress,0.9)
		if not str(effect.text).is_empty():
			var color: Color=RED if kind=="damage" else (JADE if kind=="guard" else GOLD)
			var label_pos: Vector2=pos+Vector2(0,-43-progress*23)
			_center(label_pos+Vector2(1,1),str(effect.text),17,Color(PAPER,1.0-progress))
			_center(label_pos,str(effect.text),17,Color(color,1.0-progress))

func _draw() -> void:
	if snap.is_empty(): return
	buttons.clear()
	pixel.landscape(self,Rect2(0,0,1600,1000),tick)
	pixel.panel(self,Rect2(0,0,1600,123),true,GOLD)
	_text(Vector2(36,64),"长风浮生录 · 断桥群战",36,Color("f3e9d5"),true)
	_text(Vector2(41,95),"江南断桥 · 点选招式后选择地图目标",14,Color("c0d4c2"))
	_text(Vector2(1110,59),"t=%d  行动 %d" % [int(snap.global_tick),int(snap.action_no)],20,Color("e6cf96"))
	_text(Vector2(1110,88),"R 重开  |  右键取消  |  空格收势 / Pass",14,Color("c0d4c2"))
	pixel.panel(self,BOARD,false,JADE)
	for cell in snap.terrain:
		pixel.terrain(self,cell_to_screen(cell),TILE,str(snap.terrain[cell]),int(cell.x)+int(cell.y)*Model.COLS,tick)
	for option in _candidates():
		if option.has("target_cell"):
			var rect: Rect2=Rect2(cell_to_screen(option.target_cell)-TILE*.5+Vector2(4,4),TILE-Vector2(8,8))
			draw_rect(rect,Color(JADE,.16))
			_corners(rect,JADE,3)
		elif option.has("target_id"):
			var target=model.state.get_actor(int(option.target_id))
			if target!=null:
				var rect: Rect2=Rect2(cell_to_screen(target.cell)-TILE*.5+Vector2(3,2),TILE-Vector2(6,4))
				draw_rect(rect,Color(RED,.13))
				_corners(rect,GOLD,3)
	var positions: Dictionary={}
	for actor in snap.actors:
		positions[int(actor.id)]=cell_to_screen(actor.cell)
		_draw_combatant(actor,positions[int(actor.id)])
	_draw_combat_cues(positions)
	for actor in snap.actors: _draw_combatant_hud(actor,positions[int(actor.id)])
	_text(Vector2(38,815),"金印：手动角色    青：友军    朱：敌军    金角框：当前行动 / 应变角色",16,PAPER)
	for i in range(snap.actors.size()):
		var actor: Dictionary=snap.actors[i]
		var col: int=i%3
		var row: int=i/3
		var x: float=34+col*344
		var y: float=841+row*52
		var accent: Color=JADE if int(actor.team_id)==0 else RED
		pixel.panel(self,Rect2(x,y,333,44),false,GOLD if int(actor.id)==_current_id() else accent)
		draw_rect(Rect2(x,y,4,44),accent)
		pixel.character(self,Vector2(x+24,y+36),int(actor.id),tick,"idle" if float(actor.hp)>0 else "dead",1.5,int(actor.team_id)!=0)
		_text(Vector2(x+45,y+17),str(actor.name)+" · "+("友" if int(actor.team_id)==0 else "敌")+" · "+("手动" if str(actor.controller)=="PLAYER" else "AI"),13,accent)
		_text(Vector2(x+45,y+35),"HP %.1f  气 %.1f  集气 %d" % [float(actor.hp),float(actor.qi),int(actor.gauge)],12,INK)
	pixel.panel(self,COMMANDS,false,GOLD)
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
		_text(Vector2(1110,285),"静候对手出招，观其攻守。",15,INK)
		return
	_text(Vector2(1108,256),"可执行动作  %d 种 · 点击选择" % groups.size(),15,GOLD)
	var from: int=page*11
	var until: int=mini(groups.size(),from+11)
	for index in range(from,until):
		var entry: Dictionary=groups[index]
		var y: float=270+(index-from)*49
		var rect: Rect2=Rect2(1106,y,439,42)
		var active: bool=str(entry.key)==selected_key
		pixel.panel(self,rect,active,GOLD if active else JADE)
		if active: draw_rect(Rect2(rect.position,Vector2(4,rect.size.y)),GOLD)
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

