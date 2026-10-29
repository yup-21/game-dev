extends Node2D
## Data-driven title screen, ink-wash prologue, walkable vignette and classic wuxia dialogue.
## Presentation only: chapter flow is in OpeningStory; existing battles are separate scenes.
const Story = preload("res://scripts/opening_story.gd")
const Pixel = preload("res://scripts/ink_pixel_art.gd")
const PAPER = Color("eee9dc")
const INK = Color("233c3c")
const JADE = Color("3a8178")
const GOLD = Color("c5a16b")
const RED = Color("aa5548")
const ESCORT = Vector2(1110, 530)
var story = Story.new()
var pixel = Pixel.new()
var ui_font: SystemFont
var title_font: SystemFont
var clock: float = 0.0
var cinematic_elapsed: float = 0.0
var visible_characters: float = 0.0
var player_pos: Vector2 = Vector2(405, 593)
var player_walking: bool = false
var player_facing_left: bool = false
var player_direction: int = 0
var mouse_pos: Vector2 = Vector2(-100, -100)
var buttons: Array = []
var message: String = ""
var message_left: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ui_font = SystemFont.new()
	ui_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Segoe UI"])
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["KaiTi", "STKaiti", "Microsoft YaHei"])
	DisplayServer.window_set_min_size(Vector2i(1050, 680))
	if not story.load_error.is_empty():
		push_error(story.load_error)
		return
	print("CHANGFENG_OPENING_READY chapter=", story.data.id)
	if "--opening-visual-check" in OS.get_cmdline_user_args():
		call_deferred("_run_visual_check")

func _run_visual_check() -> void:
	var check=load("res://checks/opening_visual_check.gd").new()
	await check.run(self)

func _process(delta: float) -> void:
	clock += delta
	player_walking = false
	if message_left > 0: message_left = maxf(0.0, message_left-delta)
	match story.phase:
		"cinematic":
			cinematic_elapsed += delta
			if cinematic_elapsed >= float(story.current_beat().get("duration", 4.0)):
				_advance_cinematic()
		"explore":
			var vector: Vector2 = Vector2.ZERO
			if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): vector.y -= 1
			if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): vector.y += 1
			if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): vector.x -= 1
			if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): vector.x += 1
			if vector.length_squared() > 0:
				player_walking = true
				if not is_zero_approx(vector.x): player_facing_left = vector.x < 0.0
				player_direction=(2 if vector.x<0 else 3) if absf(vector.x)>=absf(vector.y) else (1 if vector.y<0 else 0)
				player_pos = (player_pos+vector.normalized()*195.0*delta).clamp(Vector2(155,345),Vector2(1415,755))
		"dialogue":
			var line: Dictionary = story.current_dialogue()
			visible_characters = minf(float(str(line.get("text", "")).length()),visible_characters+delta*29.0)
	queue_redraw()

func _session():
	return get_node_or_null("/root/GameSession")

func _enter_new_game() -> void:
	var session=_session()
	if session!=null: session.start_new_game()
	story.begin()
	cinematic_elapsed = 0.0
	visible_characters = 0.0
	player_pos = Vector2(405,593)
	player_walking = false
	player_facing_left = false
	player_direction = 0
	message = ""

func _advance_cinematic() -> void:
	story.next_beat()
	cinematic_elapsed = 0.0

func _start_dialogue() -> void:
	if story.interact():
		visible_characters = 0.0

func _dialogue_next() -> void:
	if story.phase != "dialogue": return
	var node: Dictionary=story.current_dialogue()
	if visible_characters < float(str(node.get("text","")).length()):
		visible_characters = float(str(node.text).length())
		return
	if node.get("choices", []).is_empty() and story.advance_dialogue():
		_sync_story_events()
		visible_characters = 0.0

func _dialogue_choice(index: int) -> void:
	if story.phase != "dialogue": return
	var node: Dictionary=story.current_dialogue()
	if visible_characters < float(str(node.get("text","")).length()): return
	var session=_session()
	if session!=null: session.record_choice(story.dialogue_id,index)
	if story.choose(index):
		_sync_story_events()
		visible_characters=0.0

func _sync_story_events() -> void:
	var session=_session()
	if session!=null and story.obtained_fragment: session.record_story_event("obtain_fragment")

func _change_scene(path: String) -> void:
	var err: int = get_tree().change_scene_to_file(path)
	if err != OK:
		message = "场景加载失败：" + path
		message_left = 4.0
		push_error(message)

func _action(action: String) -> void:
	match action:
		"start": _enter_new_game()
		"duel": call_deferred("_change_scene","res://battle.tscn")
		"story_battle":
			var session=_session()
			if session!=null and session.begin_encounter():
				call_deferred("_change_scene","res://party_battle.tscn")
			else:
				message="尚未获得残篇，无法进入剧情遭遇"
				message_left=3.0
		"party": call_deferred("_change_scene","res://party_battle.tscn")
		"quit": get_tree().quit()
		"menu":
			story.reset()
			var session=_session()
			if session!=null: session.return_to_menu()
		"skip": story.skip_cinematic()
		"continue": _advance_cinematic()
		"talk": _start_dialogue()
		"next": _dialogue_next()
		_:
			if action.begins_with("choice:"): _dialogue_choice(int(action.substr(7)))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion: mouse_pos = event.position
	if event is InputEventKey and event.pressed and not event.echo:
		match story.phase:
			"menu":
				if event.keycode in [KEY_ENTER, KEY_SPACE]: _action("start")
			"cinematic":
				if event.keycode in [KEY_ESCAPE, KEY_S]: _action("skip")
				elif event.keycode in [KEY_ENTER,KEY_SPACE]: _action("continue")
			"explore":
				if event.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]:
					if player_pos.distance_to(ESCORT) < 175.0: _action("talk")
					else:
						message = "靠近受伤的镖头，再按 E 交谈。"
						message_left = 2.3
			"dialogue":
				if event.keycode in [KEY_E,KEY_ENTER,KEY_SPACE]:
					if story.current_dialogue().get("choices", []).is_empty(): _dialogue_next()
					elif visible_characters < float(str(story.current_dialogue().get("text","")).length()):
						visible_characters = float(str(story.current_dialogue().text).length())
				if event.keycode in [KEY_1,KEY_2,KEY_3]:
					_dialogue_choice(int(event.keycode-KEY_1))
			"complete":
				if event.keycode in [KEY_ENTER,KEY_SPACE]: _action("story_battle")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for button in buttons:
			if button.rect.has_point(event.position):
				_action(str(button.action))
				return
		match story.phase:
			"cinematic": _action("continue")
			"explore":
				if event.position.distance_to(ESCORT) < 90.0 and player_pos.distance_to(ESCORT) < 175.0: _action("talk")
			"dialogue": _dialogue_next()

func _text(pos: Vector2, value: String, size: int = 19, color: Color = INK, calligraphy: bool = false) -> void:
	draw_string(title_font if calligraphy else ui_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _center(pos: Vector2, value: String, size: int, color: Color = INK, calligraphy: bool = false) -> void:
	var font: Font=title_font if calligraphy else ui_font
	var width: float=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	_text(pos-Vector2(width/2.0,0),value,size,color,calligraphy)

func _seal(center: Vector2, label: String, size: int = 15) -> void:
	draw_set_transform(center,-0.055,Vector2.ONE)
	draw_rect(Rect2(-27,-27,54,54),Color("984b43",0.94))
	draw_rect(Rect2(-22,-22,44,44),Color("e9d8b8"),false,2)
	for x in [-16,16]:
		draw_rect(Rect2(x-2,-20,4,40),Color("c48669",0.58))
	_center(Vector2(0,size*0.34),label,size,Color("f1dfc0"),true)
	draw_set_transform(Vector2.ZERO)

func _polygon(vertices: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(vertices),color)

func _panel(rect: Rect2, bg: Color, border: Color = Color.TRANSPARENT) -> void:
	var accent: Color = border if border.a > 0.0 else GOLD
	pixel.panel(self,rect,bg.get_luminance()<0.43,accent)
	draw_rect(rect.grow(-7.0),bg)
	if border.a > 0.0: draw_rect(rect.grow(-1.0),border,false,1.0)
	draw_rect(Rect2(rect.position+Vector2(13,10),Vector2(7,7)),accent)
	draw_rect(Rect2(rect.position+Vector2(rect.size.x-20,10),Vector2(7,7)),accent)

func _button(rect: Rect2, caption: String, action: String, dark: bool = false) -> void:
	var hovered: bool=rect.has_point(mouse_pos)
	var color: Color=(Color("264842") if dark else Color("ede8d7"))
	if hovered: color=color.lightened(0.12)
	_panel(rect,color,GOLD if hovered else Color("a79b7c"))
	_center(rect.position+Vector2(rect.size.x/2,rect.size.y/2+8),caption,22,PAPER if dark else INK,true)
	if hovered: draw_rect(rect.grow(3),Color(GOLD,0.47),false,1.5)
	buttons.append({"rect":rect,"action":action})

func _wrapped(value: String, pos: Vector2, max_width: float, size: int, color: Color, line_gap: float = 37.0) -> void:
	var line: String=""
	var row: int=0
	for ch in value:
		if ch == "\n":
			_text(pos+Vector2(0,row*line_gap),line,size,color)
			line=""
			row+=1
			continue
		if not line.is_empty() and ui_font.get_string_size(line+ch,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>max_width:
			_text(pos+Vector2(0,row*line_gap),line,size,color)
			line=""
			row+=1
		line+=ch
	if not line.is_empty(): _text(pos+Vector2(0,row*line_gap),line,size,color)

func _sky(t: float, bleak: bool = false) -> void:
	pixel.landscape(self,Rect2(0,0,1600,1000),t,bleak)
	# Sparse paper flecks keep the illustration tactile without obscuring its ink layers.
	for i in range(116):
		var x: float=float((i*149+23)%1600)
		var y: float=float((i*91+41)%1000)
		var alpha: float=0.035 if not bleak else 0.045
		draw_rect(Rect2(x,y,2,2),Color("e8e0cd",alpha))

func draw_ellipse_ink(pos: Vector2, radius: Vector2, color: Color) -> void:
	draw_set_transform(pos,0,Vector2(1.0,radius.y/maxf(1.0,radius.x)))
	draw_circle(Vector2.ZERO,radius.x,color)
	draw_set_transform(Vector2.ZERO)

func _rain(t: float, density: int = 145) -> void:
	for i in range(density):
		var x: float=fmod(float((i*159)%1703)+t*170.0*(1.0+float(i%3)*0.12),1640.0)-20.0
		var y: float=fmod(float((i*317)%1191)+t*370.0,1040.0)-20.0
		var rain_color: Color=Color(0.79,0.91,0.88,0.09+float(i%4)*0.04)
		draw_rect(Rect2(roundf(x),roundf(y),2,6),rain_color)
		draw_rect(Rect2(roundf(x-3),roundf(y+6),2,6),rain_color)

func _paint_pavilion(pos: Vector2, scale_factor: float = 1.0) -> void:
	draw_set_transform(pos,0,Vector2(scale_factor,scale_factor))
	# Broken mountain-temple silhouette, built from hard-edged tile-like bands.
	_polygon([Vector2(-155,-86),Vector2(-110,-98),Vector2(-84,-138),Vector2(-34,-119),Vector2(20,-142),Vector2(68,-117),Vector2(119,-131),Vector2(158,-82),Vector2(105,-98),Vector2(-105,-98)],Color("202f30"))
	_polygon([Vector2(-104,-98),Vector2(108,-98),Vector2(103,35),Vector2(-106,35)],Color("4d5b53"))
	draw_rect(Rect2(-88,-87,38,122),Color("293b39"))
	draw_rect(Rect2(49,-87,38,122),Color("293b39"))
	draw_rect(Rect2(-29,-69,59,104),Color("172a2b"))
	draw_rect(Rect2(-27,-66,8,19),Color("b69a69",0.42))
	draw_rect(Rect2(20,-42,8,18),Color("b69a69",0.30))
	draw_rect(Rect2(-139,-91,57,8),Color("202f30"))
	draw_rect(Rect2(99,-100,55,7),Color("202f30"))
	for x in range(-126,136,18):
		draw_rect(Rect2(x,-101+int(abs(x)/36)%2*4,10,4),Color("6d7063",0.65))
	draw_rect(Rect2(-151,-86,301,6),Color("b4a17e"))
	draw_rect(Rect2(-111,34,226,7),Color("8a8068"))
	# A small cracked vermilion temple plaque.
	draw_rect(Rect2(-9,-91,36,18),Color("8d4b42"))
	draw_rect(Rect2(-5,-87,28,10),Color("c49b66"))
	draw_rect(Rect2(1,-85,4,6),Color("7b4139"))
	draw_rect(Rect2(11,-85,4,6),Color("7b4139"))
	draw_set_transform(Vector2.ZERO)

func _carriage(pos: Vector2) -> void:
	_polygon([pos+Vector2(-111,-13),pos+Vector2(31,-34),pos+Vector2(103,-27),pos+Vector2(99,26),pos+Vector2(-98,33)],Color("554b3d"))
	_polygon([pos+Vector2(-94,-44),pos+Vector2(-48,-78),pos+Vector2(75,-61),pos+Vector2(97,-27)],Color("2b3e3d"))
	draw_rect(Rect2(pos+Vector2(-103,-10),Vector2(194,5)),Color("a48b65"))
	draw_rect(Rect2(pos+Vector2(-82,-42),Vector2(6,36)),Color("b59b70"))
	draw_rect(Rect2(pos+Vector2(71,-36),Vector2(6,33)),Color("b59b70"))
	draw_rect(Rect2(pos+Vector2(-110,31),Vector2(237,6)),Color("302f2a"))
	for x in [-58,65]:
		var wheel: Vector2=pos+Vector2(x,40)
		for i in range(12):
			var angle: float=float(i)*TAU/12.0
			var spoke: Vector2=wheel+Vector2(roundf(cos(angle)*20.0/4.0)*4.0,roundf(sin(angle)*20.0/4.0)*4.0)
			draw_rect(Rect2(spoke,Vector2(6,6)),Color("302f2a"))
		draw_rect(Rect2(wheel-Vector2(9,9),Vector2(18,18)),Color("97815e"))
		draw_rect(Rect2(wheel-Vector2(3,3),Vector2(6,6)),Color("3f3930"))
	draw_rect(Rect2(pos+Vector2(95,15),Vector2(112,5)),Color("74593e"))
	draw_rect(Rect2(pos+Vector2(184,39),Vector2(12,12)),Color("a94e47"))

func _portrait(pos: Vector2, old: bool) -> void:
	var variant: int=1 if old else 0
	var pose: String="hurt" if old else ("walk" if player_walking else "idle")
	var flip: bool=false if old else player_facing_left
	var tint: Color=Color("d3b89c") if old else Color.WHITE
	pixel.character(self,pos,variant,clock,pose,5.0,flip,tint,-1 if old else player_direction)

func _draw_menu() -> void:
	_sky(clock)
	# A broad blank-paper scroll anchors the title while leaving the mountains exposed.
	_panel(Rect2(52,49,605,902),Color("e9e1cc"),Color("948267"))
	draw_rect(Rect2(72,69,565,862),Color("e6ddc7"))
	draw_rect(Rect2(91,89,4,815),Color("c4b496",0.66))
	draw_rect(Rect2(610,91,3,810),Color("c4b496",0.50))
	_paint_pavilion(Vector2(1290,755),1.1)
	_text(Vector2(132,250),"MORTAL DAO  /  江 湖 浮 生",19,Color("766348"))
	_text(Vector2(118,384),"长风浮生录",77,INK,true)
	draw_rect(Rect2(126,414,492,3),Color("a78a5f"))
	draw_rect(Rect2(126,422,196,2),Color("a78a5f",0.45))
	_text(Vector2(132,482),"英雄无百岁，刀剑不饶人。",23,Color("544e42"),true)
	_text(Vector2(135,524),"由武入道 · 逆天改命",17,Color("62736a"))
	_seal(Vector2(558,155),"卷一",16)
	_button(Rect2(137,602,391,67),"初入江湖 · 新游戏","start",true)
	_button(Rect2(137,689,391,59),"断桥论剑 · 战斗试玩","duel",true)
	_button(Rect2(137,766,391,59),"群侠试炼 · 多人战斗","party",true)
	_button(Rect2(137,844,391,56),"退出游戏","quit",true)
	_text(Vector2(138,930),"序章演示 · 水墨像素武侠 · 暮秋雨夜",13,Color("766b56"))

func _draw_cinematic() -> void:
	_sky(clock,true)
	_rain(clock)
	var beat: Dictionary=story.current_beat()
	var duration: float=float(beat.get("duration",4.0))
	var opacity: float=clampf(minf(cinematic_elapsed/1.0,(duration-cinematic_elapsed)/0.7),0.0,1.0)
	var caption: String=str(beat.get("caption",""))
	var body: String=str(beat.get("text",""))
	_paint_pavilion(Vector2(1120,752),0.98)
	_carriage(Vector2(800+sin(clock*.24)*7.0,743))
	draw_rect(Rect2(0,0,1600,1000),Color(0.05,0.11,0.12,0.28))
	_panel(Rect2(242,318,1116,326),Color("e8e0cc"),Color("9b8058"))
	_center(Vector2(800,383),caption,32,Color(INK,opacity),true)
	_center(Vector2(800,484),body,27,Color("394441",opacity))
	_center(Vector2(800,556),"——  风雨入局  ——",18,Color("92734d",opacity))
	_seal(Vector2(1280,365),"夜雨",14)
	for index in range(story.data.cinematic.size()):
		var mark: Vector2=Vector2(765+(index-1)*35,875)
		draw_rect(Rect2(mark-Vector2(5,5),Vector2(10,10)),GOLD if index==story.cinematic_index else Color("b4ad9a",0.72))
	_button(Rect2(1339,45,202,44),"跳过过场  Esc","skip",true)
	_text(Vector2(621,939),"空格 / 点击继续",15,Color("e3ddcb"))

func _draw_explore() -> void:
	_sky(clock,true)
	_rain(clock,114)
	_panel(Rect2(43,28,1514,96),Color("e7dfcb"),Color("887957"))
	_text(Vector2(74,87),"第一幕 · 雨夜残镖",36,INK,true)
	_seal(Vector2(515,75),"第一",12)
	_text(Vector2(1090,83),"荒道破庙 / 暮秋 · 三更",17,Color("625c4c"))
	# Wet path and dark ground planes lead the eye toward the ruined temple.
	_polygon([Vector2(0,645),Vector2(354,600),Vector2(628,565),Vector2(1055,577),Vector2(1398,620),Vector2(1600,670),Vector2(1600,1000),Vector2(0,1000)],Color("354644"))
	_paint_explore_terrain()
	_polygon([Vector2(225,1000),Vector2(571,742),Vector2(799,673),Vector2(985,684),Vector2(1261,1000)],Color("68756a",0.72))
	_polygon([Vector2(0,825),Vector2(369,723),Vector2(497,747),Vector2(690,1000),Vector2(0,1000)],Color("263738",0.62))
	_polygon([Vector2(1115,1000),Vector2(1260,748),Vector2(1398,713),Vector2(1600,810),Vector2(1600,1000)],Color("263738",0.62))
	_paint_explore_puddles()
	for i in range(45):
		var px: float=float((i*137+62)%1550)
		var py: float=678+float((i*41)%293)
		draw_rect(Rect2(px,py,12+float(i%4)*3,2),Color(0.68,0.74,0.65,0.13))
	for i in range(22):
		var puddle_x: float=float((i*173+88)%1540)
		var puddle_y: float=694+float((i*67)%275)
		draw_rect(Rect2(puddle_x,puddle_y,14+float(i%5)*5,3),Color("9ba996",0.27))
	_paint_pavilion(Vector2(1280,570),0.9)
	_carriage(Vector2(837,625))
	_portrait(ESCORT,true)
	_portrait(player_pos,false)
	var near: bool=player_pos.distance_to(ESCORT)<175.0
	if near:
		var pulse: float=0.60+sin(clock*3.0)*0.12
		var c: Color=Color(GOLD,pulse)
		for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			var base: Vector2=ESCORT+Vector2(corner.x*55,corner.y*91)
			draw_rect(Rect2(base+Vector2(0 if corner.x<0 else -20,0 if corner.y<0 else -3),Vector2(20,3)),c)
			draw_rect(Rect2(base+Vector2(0 if corner.x<0 else -3,0 if corner.y<0 else -18),Vector2(3,18)),c)
		_button(Rect2(882,366,426,55),"E  与受伤镖头交谈","talk",true)
	else:
		_text(Vector2(843,370),"老镖头  ·  似乎还有气息",18,Color("e1d2ac"))
	_panel(Rect2(76,837,1448,125),Color("e7dfcb"),Color("927c58"))
	_text(Vector2(112,881),"沿官道走近镖车，查探伤者。",23,INK,true)
	_text(Vector2(114,920),"WASD / 方向键移动    靠近后按 E 交谈    ·    序章可操作叙事场景",15,Color("625d4d"))
	if message_left>0: _text(Vector2(120,809),message,18,RED)

func _draw_dialogue() -> void:
	_draw_explore_backdrop()
	var node: Dictionary=story.current_dialogue()
	var speaker: String=str(node.get("speaker",""))
	var full_text: String=str(node.get("text",""))
	draw_rect(Rect2(0,0,1600,1000),Color(0.07,0.12,0.12,0.22))
	_panel(Rect2(124,665,1352,292),Color("eae3cf"),GOLD)
	# Paper dialogue scroll and a red ink signet anchor the speaker portrait.
	_panel(Rect2(153,574,227,308),Color("38534c"),GOLD)
	var portrait_variant: int=1 if speaker=="老镖头" else 0
	pixel.portrait(self,Rect2(190,668,152,152),portrait_variant)
	_seal(Vector2(266,633),"镖",14)
	_seal(Vector2(1431,709),"残",13)
	_panel(Rect2(385,628,264,63),Color("25483f"),GOLD)
	_center(Vector2(517,671),speaker,27,PAPER,true)
	var clipped: String=full_text.substr(0,mini(full_text.length(),int(visible_characters)))
	_wrapped(clipped,Vector2(419,740),983,25,INK,39)
	if int(visible_characters)>=full_text.length():
		var choices: Array=node.get("choices",[])
		if choices.is_empty():
			_button(Rect2(1241,886,201,50),"继续  ▶","next",true)
			_text(Vector2(422,922),"空格 / 回车 / 点击继续",15,Color("8b795b"))
		else:
			for i in range(choices.size()):
				_button(Rect2(784,864+i*55,642,48),"%d  %s" % [i+1,str(choices[i].text)],"choice:"+str(i),true)
	else:
		_text(Vector2(1281,911),"点击显示全文  ▸",16,Color("968262"))

func _draw_explore_backdrop() -> void:
	# The world remains visible behind the dialogue, with motion softened.
	_sky(clock,true)
	_rain(clock,80)
	_polygon([Vector2(0,645),Vector2(354,600),Vector2(628,565),Vector2(1055,577),Vector2(1398,620),Vector2(1600,670),Vector2(1600,1000),Vector2(0,1000)],Color("354644"))
	_paint_explore_terrain()
	_polygon([Vector2(225,1000),Vector2(571,742),Vector2(799,673),Vector2(985,684),Vector2(1261,1000)],Color("68756a",0.72))
	_paint_explore_puddles()
	_paint_pavilion(Vector2(1270,580),0.9)
	_carriage(Vector2(822,628))
	_portrait(ESCORT,true)
	_portrait(player_pos,false)

func _paint_explore_terrain() -> void:
	# The tiles stay deterministic; only their shallow water glints follow the scene clock.
	for row in range(5):
		for column in range(10):
			var kind: String="grass"
			if row<2 and column in [0,9]: kind="bamboo"
			elif row>=2 and column in [2,7] and row%2==0: kind="rock"
			var center: Vector2=Vector2(80+column*160,704+row*64)
			pixel.terrain(self,center,Vector2(160,64),kind,row*19+column*7,clock)

func _paint_explore_puddles() -> void:
	pixel.terrain(self,Vector2(488,884),Vector2(132,34),"water",37,clock)
	pixel.terrain(self,Vector2(1180,826),Vector2(118,32),"water",53,clock)

func _draw_complete() -> void:
	_sky(clock,true)
	_rain(clock,90)
	_carriage(Vector2(1090,650))
	draw_rect(Rect2(0,0,1600,1000),Color(0.05,0.12,0.12,0.22))
	_panel(Rect2(235,180,1130,696),Color("e9e1cc"),Color("9a8058"))
	_center(Vector2(800,290),"江 湖 初 入",39,INK,true)
	draw_rect(Rect2(446,322,708,3),Color("a88b5d",0.68))
	_seal(Vector2(1285,243),"卷终",14)
	_center(Vector2(800,400),"《太虚引气残篇》",32,RED,true)
	_center(Vector2(800,470),"一卷无名绢帛，一场未完的血案。",24,INK,true)
	_center(Vector2(800,525),"你尚不知道，它将牵出多少江湖恩怨。",20,INK)
	_center(Vector2(800,579),"远处的马蹄声越来越近……",19,Color("846d4e"))
	_button(Rect2(430,639,742,70),"迎战追兵 · 继续序章","story_battle",true)
	_button(Rect2(430,734,350,58),"进入群侠战斗试玩","party",true)
	_button(Rect2(822,734,350,58),"返回主菜单","menu",true)

func _draw() -> void:
	if ui_font==null or story.load_error!="": return
	buttons.clear()
	match story.phase:
		"menu": _draw_menu()
		"cinematic": _draw_cinematic()
		"explore": _draw_explore()
		"dialogue": _draw_dialogue()
		"complete": _draw_complete()
		_: _draw_menu()
