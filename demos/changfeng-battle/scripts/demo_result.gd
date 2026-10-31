extends Node2D
## Small demo completion interface; all progression is owned by GameSession.
const PAPER=Color("ede7d7")
const INK=Color("243b3b")
const JADE=Color("37766e")
const GOLD=Color("b8965d")
## The retry path must never reopen deprecated 2D party combat.
const ACTIVE_BATTLE_SCENE := "res://battle_hd2d.tscn"
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
			if session.retry_encounter(): call_deferred("_go", session.scene_for("battle"))
		"menu":
			session.return_to_menu()
			call_deferred("_go",session.scene_for("menu"))
		"continue":
			if session.advance_chapter(): call_deferred("_go", session.scene_for("story"))
		"finish":
			session.finish_demo()
			queue_redraw()
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
	var chapter: Dictionary=session.chapter_definition()
	var heading: String=str(chapter.get("scene",{}).get("title","序章 · 雨夜残镖"))
	draw_string(font,Vector2(270,183),heading,HORIZONTAL_ALIGNMENT_LEFT,-1,46,INK)
	draw_string(font,Vector2(270,310),result_title,HORIZONTAL_ALIGNMENT_LEFT,-1,40,JADE if success else Color("a95d4c"))
	draw_string(font,Vector2(270,392),"剧情线索：《太虚引气残篇》" if session.items.has("taixu_fragment") else "尚无残篇线索",HORIZONTAL_ALIGNMENT_LEFT,-1,24,INK)
	var hero=session.character("shen_changfeng")
	if hero!=null:
		var powders: int=int(hero.inventory.stacks.get("healing_powder",0))
		var pills: int=int(hero.inventory.stacks.get("breath_pill",0))
		var gear: String="已装备" if hero.inventory.equipped.has("weapon") else "未装备"
		draw_string(font,Vector2(270,553),"随身药囊：金疮药 %d  /  回气丹 %d  /  长剑 %s" % [powders,pills,gear],HORIZONTAL_ALIGNMENT_LEFT,-1,22,INK)
	var decision: String="你曾试着救治镖头。" if bool(session.flags.get("helped_escort",false)) else "你曾追问劫镖真相。"
	draw_string(font,Vector2(270,446),decision,HORIZONTAL_ALIGNMENT_LEFT,-1,23,INK)
	draw_string(font,Vector2(270,505),"断桥前路仍有余波，队伍与物品状态会沿章节延续。",HORIZONTAL_ALIGNMENT_LEFT,-1,22,INK)
	if session.phase=="complete":
		draw_string(font,Vector2(270,589),"两幕试玩完成",HORIZONTAL_ALIGNMENT_LEFT,-1,30,GOLD)
		_button(Rect2(270,678,380,66),"返回主菜单","new")
	else:
		if session.can_advance_chapter():
			_button(Rect2(270,650,380,66),"进入下一幕","continue")
		else:
			_button(Rect2(270,650,380,66),"结束试玩","finish")
		_button(Rect2(688,650,360,66),"重新挑战","retry")
		_button(Rect2(1082,650,300,66),"主菜单","menu")
