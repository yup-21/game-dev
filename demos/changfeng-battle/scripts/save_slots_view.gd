extends Node2D
## Save desk: three local versioned slots, corruption feedback, safe scene continuation.
const Saves=preload("res://scripts/save_system.gd")
const BG=Color("e9e5d6")
const INK=Color("30443f")
const GOLD=Color("b68d4e")
const JADE=Color("397d71")
var font: SystemFont
var buttons: Array=[]
var saves=Saves.new()
var feedback: String=""

func _ready() -> void:
	font=SystemFont.new()
	font.font_names=PackedStringArray(["KaiTi","Noto Sans CJK SC","Microsoft YaHei"])

func _session():
	return get_node_or_null("/root/GameSession")

func _go(path: String) -> void:
	var error: int=get_tree().change_scene_to_file(path)
	if error!=OK:
		feedback="场景无法打开："+path

func _act(code: String) -> void:
	var session=_session()
	if session==null: return
	if code=="back":
		call_deferred("_go",session.management_return)
		return
	if code=="resume":
		call_deferred("_go",session.resume_scene())
		return
	var command: PackedStringArray=code.split(":")
	if command.size()!=2: return
	var slot: int=int(command[1])
	match str(command[0]):
		"save":
			feedback="第%d档：%s" % [slot,"保存成功" if session.save_game(slot) else session.save_message]
		"load":
			if session.load_game(slot):
				feedback="读取成功"
				call_deferred("_go",session.resume_scene())
			else: feedback=session.save_message
		"delete":
			feedback="第%d档已删除" % slot if saves.delete(slot) else "删除失败"
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE: _act("back")
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		for entry in buttons:
			if entry.rect.has_point(event.position):
				_act(str(entry.action))
				return

func _button(rect: Rect2,label: String,action: String,enabled: bool=true) -> void:
	draw_rect(rect,JADE if enabled else Color("a5afa3"))
	draw_rect(rect,GOLD,false,2)
	draw_string(font,rect.position+Vector2(15,rect.size.y/2.0+7),label,HORIZONTAL_ALIGNMENT_LEFT,-1,19,BG)
	if enabled: buttons.append({"rect":rect,"action":action})

func _draw() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1600,1000),Color("304a43"))
	draw_rect(Rect2(120,84,1360,830),BG)
	draw_rect(Rect2(136,100,1328,797),GOLD,false,2)
	draw_string(font,Vector2(194,189),"江湖行箧 · 存档管理",44,INK)
	draw_string(font,Vector2(194,230),"存档在本机 user://saves/ 下。战斗进行中不可保存，以免破坏行动与连锁状态。",19,INK)
	var session=_session()
	for i in range(3):
		var slot: int=i+1
		var pos: Vector2=Vector2(185,280+i*177)
		var rect: Rect2=Rect2(pos,1230,156)
		draw_rect(rect,Color("f9f5e9"))
		draw_rect(rect,GOLD,false,2)
		var info: Dictionary=saves.info(slot)
		var state: String=str(info.get("state","empty"))
		var title: String="空档" if state=="empty" else ("存档损坏/版本不兼容" if state=="corrupt" else "《雨夜残镖》 · "+str(info.get("phase","")))
		draw_string(font,pos+Vector2(24,58),"第 %d 档" % slot,HORIZONTAL_ALIGNMENT_LEFT,-1,30,JADE)
		draw_string(font,pos+Vector2(24,105),title,HORIZONTAL_ALIGNMENT_LEFT,-1,20,INK)
		var save_ok: bool=session!=null and session.phase in ["story","aftermath","complete"]
		_button(Rect2(pos.x+570,pos.y+49,180,59),"写入存档","save:"+str(slot),save_ok)
		_button(Rect2(pos.x+764,pos.y+49,180,59),"读取存档","load:"+str(slot),state=="ready")
		_button(Rect2(pos.x+957,pos.y+49,180,59),"删除","delete:"+str(slot),state!="empty")
	_button(Rect2(191,844,262,52),"返回  Esc","back")
	if session!=null and session.phase in ["story","aftermath","complete"]:
		_button(Rect2(493,844,298,52),"继续当前进度","resume")
	if not feedback.is_empty(): draw_string(font,Vector2(190,820),feedback,HORIZONTAL_ALIGNMENT_LEFT,-1,19,INK)
