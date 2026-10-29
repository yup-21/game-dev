extends Node2D
## Small demo completion interface; all progression is owned by GameSession.
const PAPER=Color("ede7d7")
const INK=Color("243b3b")
const JADE=Color("37766e")
const GOLD=Color("b8965d")
var font: SystemFont
var buttons: Array=[]

func _ready() -> void:
	font=SystemFont.new()
	font.font_names=PackedStringArray(["KaiTi","Noto Sans CJK SC","Microsoft YaHei"])
	if _session()==null: push_error("Demo result requires GameSession autoload")

func _session():
	return get_node_or_null("/root/GameSession")

func _go(path: String) -> void:
	var err: int=get_tree().change_scene_to_file(path)
	if err!=OK: push_error("Scene change failed: "+path)

func _action(id: String) -> void:
	var session=_session()
	if session==null: return
	match id:
		"retry":
			if session.retry_encounter(): call_deferred("_go","res://party_battle.tscn")
		"menu":
			session.return_to_menu()
			call_deferred("_go","res://opening.tscn")
		"rest": session.choose_aftercare("rest")
		"pursue": session.choose_aftercare("pursue")
		"train_str": session.allocate_training_point("STR")
		"train_agi": session.allocate_training_point("AGI")
		"break_taixu": session.breakthrough_taixu()
		"finish": session.finish_demo()
		"new":
			session.return_to_menu()
			call_deferred("_go","res://opening.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE: _action("menu")
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		for button in buttons:
			if button.rect.has_point(event.position):
				_action(str(button.id))
				return

func _button(rect: Rect2, text_value: String, id: String) -> void:
	draw_rect(rect,JADE)
	draw_rect(rect,GOLD,false,2)
	draw_string(font,rect.position+Vector2(23,rect.size.y/2+9),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,25,PAPER)
	buttons.append({"rect":rect,"id":id})

func _draw() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1600,1000),PAPER)
	draw_rect(Rect2(130,95,1340,808),Color("f8f3e6"),false,3)
	draw_line(Vector2(290,220),Vector2(1310,220),GOLD,2)
	var session=_session()
	if session==null: return
	var outcome: String=str(session.battle_outcome)
	var success: bool=outcome=="victory"
	var result_title: String="江湖暂安 · 一战得脱" if success else ("两败俱伤 · 血路未定" if outcome=="draw" else "追兵得势 · 退守破庙")
	var heading: String="序章 · 雨夜残镖"
	draw_string(font,Vector2(270,183),heading,HORIZONTAL_ALIGNMENT_LEFT,-1,46,INK)
	draw_string(font,Vector2(270,310),result_title,HORIZONTAL_ALIGNMENT_LEFT,-1,40,JADE if success else Color("a95d4c"))
	draw_string(font,Vector2(270,392),"获得线索：《太虚引气残篇》" if session.items.has("taixu_fragment") else "尚无残篇线索",HORIZONTAL_ALIGNMENT_LEFT,-1,24,INK)
	var decision: String="你曾试着救治镖头。" if bool(session.flags.get("helped_escort",false)) else "你曾追问劫镖真相。"
	draw_string(font,Vector2(270,446),decision,HORIZONTAL_ALIGNMENT_LEFT,-1,23,INK)
	draw_string(font,Vector2(270,505),"这只是江湖第一幕的开端。更深的阴谋，仍藏在雨幕之后。",HORIZONTAL_ALIGNMENT_LEFT,-1,22,INK)
	var wound_label: String="暗伤：%d层 · 气血上限 -%d" % [int(session.injury_stacks),int(session.injury_stacks)*2] if int(session.injury_stacks)>0 else "暗伤已愈 · 气血上限恢复"
	draw_string(font,Vector2(270,551),wound_label,HORIZONTAL_ALIGNMENT_LEFT,-1,22,INK)
	if session.phase=="complete":
		draw_string(font,Vector2(270,613),"序章试玩完成 · 江湖未完，长风未止。",HORIZONTAL_ALIGNMENT_LEFT,-1,29,GOLD)
		_button(Rect2(270,700,450,65),"返回主菜单","new")
	elif session.aftercare.is_empty():
		draw_string(font,Vector2(270,605),"战后气脉受损，必须决定去留：",HORIZONTAL_ALIGNMENT_LEFT,-1,24,INK)
		_button(Rect2(270,675,510,65),"疗伤休整 · 消除暗伤","rest")
		_button(Rect2(820,675,515,65),"带伤追查 · 气血上限受损","pursue")
	else:
		var consequence: String="你静养疗伤，暗伤尽消，气血上限恢复。" if session.aftercare=="rest" else "你强撑伤势追索线索，暗伤未愈，气血上限仍受限制。"
		draw_string(font,Vector2(270,608),consequence,HORIZONTAL_ALIGNMENT_LEFT,-1,24,INK)
		if bool(session.flags.get("pursuer_token_clue",false)):
			draw_string(font,Vector2(270,643),"得到新线索：追兵令牌",HORIZONTAL_ALIGNMENT_LEFT,-1,20,GOLD)
		_button(Rect2(270,706,440,64),"结束序章","finish")
		_button(Rect2(736,706,340,64),"重新挑战","retry")
		_button(Rect2(1096,706,270,64),"主菜单","menu")
		var record: Dictionary=session.character_records.get(0,{})
		var available: int=int(record.get("unspent_points",0))
		var martial_record: Dictionary=session.martial_records.get(0,{}).get("taixu",{})
		draw_string(font,Vector2(270,811),"可分配属性点：%d · 太虚熟练度：%d · 境界：%d" % [available,int(martial_record.get("xp",0)),int(martial_record.get("rank",1))],HORIZONTAL_ALIGNMENT_LEFT,-1,19,INK)
		if available>0:
			_button(Rect2(270,829,260,50),"修炼力道 +1","train_str")
			_button(Rect2(555,829,260,50),"修炼身法 +1","train_agi")
		if not martial_record.is_empty() and session.martial_records[0]["taixu"].xp>=50 and int(martial_record.rank)==1:
			_button(Rect2(850,829,350,50),"突破太虚 · 熟练","break_taixu")
