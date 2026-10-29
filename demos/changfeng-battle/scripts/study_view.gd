extends Node2D
## Fragment study: a small real progression step before the story combat.
const PAPER=Color("eee8db")
const INK=Color("293f3d")
const GOLD=Color("c09a5c")
const JADE=Color("397e73")
var font: SystemFont
var buttons: Array=[]

func _ready() -> void:
	font=SystemFont.new()
	font.font_names=PackedStringArray(["KaiTi","Noto Sans CJK SC","Microsoft YaHei"])
	if get_node_or_null("/root/GameSession")==null: push_error("GameSession autoload required")

func _session():
	return get_node_or_null("/root/GameSession")

func _go(path: String) -> void:
	var err: int=get_tree().change_scene_to_file(path)
	if err!=OK: push_error("Scene load failed: "+path)

func _act(id: String) -> void:
	var session=_session()
	if session==null: return
	match id:
		"study": session.study_fragment()
		"battle":
			if session.begin_encounter(): call_deferred("_go","res://party_battle.tscn")
		"menu":
			session.return_to_menu()
			call_deferred("_go","res://opening.tscn")
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		for b in buttons:
			if b.rect.has_point(event.position):
				_act(str(b.id))
				break
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ENTER or event.keycode==KEY_SPACE:
			var session=_session()
			_act("battle" if session!=null and bool(session.flags.get("studied_fragment",false)) else "study")
		elif event.keycode==KEY_ESCAPE: _act("menu")

func _button(rect: Rect2,label: String,id: String) -> void:
	draw_rect(rect,JADE)
	draw_rect(rect,GOLD,false,2)
	draw_string(font,rect.position+Vector2(22,39),label,HORIZONTAL_ALIGNMENT_LEFT,-1,25,PAPER)
	buttons.append({"rect":rect,"id":id})

func _draw() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1600,1000),Color("30443c"))
	for i in range(5):
		var x: float=80+i*340
		draw_line(Vector2(x,125),Vector2(x+450,880),Color(0.75,0.66,0.48,0.065),2)
	draw_rect(Rect2(175,110,1250,780),PAPER)
	draw_rect(Rect2(189,124,1222,752),GOLD,false,2)
	draw_string(font,Vector2(285,226),"雨 夜 残 镖 · 太 虚 参 悟",42,INK)
	draw_line(Vector2(300,266),Vector2(1300,266),GOLD,2)
	draw_string(font,Vector2(300,351),"你展开浸血绢帛，行气文字似在雨中缓缓浮现。",25,INK)
	draw_string(font,Vector2(300,417),"《太虚引气残篇》",35,JADE)
	var session=_session()
	if session==null: return
	var studied: bool=bool(session.flags.get("studied_fragment",false))
	if not studied:
		draw_string(font,Vector2(300,506),"参悟残篇，可在接下来的战斗中使用「起手·探脉」。",23,INK)
		draw_string(font,Vector2(300,550),"命中后衍生「续式·流云」，再命中可得到「收势·断空」。",21,INK)
		_button(Rect2(300,664,508,65),"参悟残篇 · 解锁套路","study")
	else:
		draw_string(font,Vector2(300,506),"武学已领悟：探脉 → 流云 → 断空",26,JADE)
		draw_string(font,Vector2(300,550),"后两式是临时衍生卡，可跨行动保留，使用后移除。",21,INK)
		_button(Rect2(300,664,508,65),"迎战追兵 · 进入战斗","battle")
	_button(Rect2(855,664,390,65),"返回主菜单","menu")
	draw_string(font,Vector2(309,805),"按 Enter 参悟或继续；Esc 返回菜单",17,Color("897a64"))
