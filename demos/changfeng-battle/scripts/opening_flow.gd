extends Node2D
## Data-driven title screen, ink-wash prologue, walkable vignette and classic wuxia dialogue.
## Presentation only: chapter flow is in OpeningStory; existing battles are separate scenes.
const Story = preload("res://scripts/opening_story.gd")
const CharacterArt = preload("res://scripts/hd2d_illustrated_factory.gd")
const PAPER = Color("eee9dc")
const INK = Color("233c3c")
const JADE = Color("3a8178")
const GOLD = Color("c5a16b")
const RED = Color("aa5548")
const ESCORT = Vector2(1110, 530)
var story = Story.new()
var ui_font: SystemFont
var title_font: SystemFont
var clock: float = 0.0
var cinematic_elapsed: float = 0.0
var visible_characters: float = 0.0
var player_pos: Vector2 = Vector2(405, 593)
var mouse_pos: Vector2 = Vector2(-100, -100)
var buttons: Array = []
var message: String = ""
var message_left: float = 0.0

func _ready() -> void:
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
		"hd2d": call_deferred("_change_scene","res://battle_hd2d.tscn")
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

func _polygon(vertices: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(vertices),color)

func _panel(rect: Rect2, bg: Color, border: Color = Color.TRANSPARENT) -> void:
	draw_rect(Rect2(rect.position+Vector2(4,6),rect.size),Color(0.09,0.12,0.11,0.19))
	draw_rect(rect,bg)
	if border.a > 0: draw_rect(rect,border,false,2)
	draw_line(rect.position+Vector2(14,12),rect.position+Vector2(rect.size.x-14,12),Color(GOLD,0.36),1)

func _button(rect: Rect2, caption: String, action: String, dark: bool = false) -> void:
	var hovered: bool=rect.has_point(mouse_pos)
	var color: Color=(Color("264842") if dark else Color("ede8d7"))
	if hovered: color=color.lightened(0.12)
	_panel(rect,color,GOLD if hovered else Color("a79b7c"))
	# Clean vector-styled command strip; no small pixel button texture.
	draw_rect(Rect2(rect.position+Vector2(8,8),Vector2(4,rect.size.y-16)),Color(GOLD,0.84))
	draw_line(rect.position+Vector2(21,rect.size.y-9),
		rect.position+Vector2(rect.size.x-16,rect.size.y-9),Color(GOLD,0.18),1)
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
	var top: Color=Color("263b3b") if bleak else Color("5d7772")
	var bottom: Color=Color("a1afa0") if bleak else Color("d0d1b5")
	for y in range(0,1000,8):
		draw_rect(Rect2(0,y,1600,8),top.lerp(bottom,float(y)/1000.0))
	draw_circle(Vector2(1230+sin(t*.08)*16.0,218),80,Color(0.96,0.83,0.57,0.40 if bleak else 0.68))
	for layer in range(4):
		var vertices: Array=[Vector2(0,1000)]
		for i in range(18):
			var x: float=float(i)*100.0
			var ridge: float=390.0+float(layer)*86.0+sin(i*1.18+layer*0.57)*34.0+cos(i*0.57)*32.0
			vertices.append(Vector2(x,ridge))
		vertices.append(Vector2(1600,1000))
		_polygon(vertices,Color(0.12,0.29,0.28,0.20+float(layer)*0.095))
	# Slow parallax clouds, independent of battle RNG.
	for i in range(8):
		var x: float=fmod(float(i)*243.0+t*(6.0+i*1.7),1850.0)-100.0
		var y: float=190.0+float(i%4)*90.0
		draw_ellipse_ink(Vector2(x,y),Vector2(115,20),Color(0.91,0.93,0.85,0.10))
	# Paper scratches provide motion while keeping the title readable.
	for i in range(62):
		var x: float=float((i*149+23)%1600)
		var y: float=float((i*91+41)%1000)
		draw_line(Vector2(x,y),Vector2(x+float(8+i%5),y),Color(0.87,0.80,0.65,0.035),1)

func draw_ellipse_ink(pos: Vector2, radius: Vector2, color: Color) -> void:
	draw_set_transform(pos,0,Vector2(1.0,radius.y/maxf(1.0,radius.x)))
	draw_circle(Vector2.ZERO,radius.x,color)
	draw_set_transform(Vector2.ZERO)

func _rain(t: float, density: int = 145) -> void:
	for i in range(density):
		var x: float=fmod(float((i*159)%1703)+t*170.0*(1.0+float(i%3)*0.12),1640.0)-20.0
		var y: float=fmod(float((i*317)%1191)+t*370.0,1040.0)-20.0
		draw_line(Vector2(x,y),Vector2(x-9,y+28),Color(0.79,0.91,0.88,0.09+float(i%4)*0.04),1.0)

func _paint_pavilion(pos: Vector2, scale_factor: float = 1.0) -> void:
	draw_set_transform(pos,0,Vector2(scale_factor,scale_factor))
	_polygon([Vector2(-140,-85),Vector2(-90,-126),Vector2(73,-121),Vector2(145,-86),Vector2(93,-97),Vector2(-96,-101)],Color("263e3d"))
	_polygon([Vector2(-97,-97),Vector2(90,-96),Vector2(89,32),Vector2(-97,32)],Color("58625a"))
	draw_rect(Rect2(-82,-89,40,121),Color("303d3b"))
	draw_rect(Rect2(43,-89,40,121),Color("303d3b"))
	draw_rect(Rect2(-27,-68,54,100),Color("202f30"))
	draw_line(Vector2(-146,-84),Vector2(144,-84),Color("a58d69"),3)
	draw_line(Vector2(-111,32),Vector2(109,32),Color("b1a28a"),6)
	draw_set_transform(Vector2.ZERO)

func _carriage(pos: Vector2) -> void:
	_polygon([pos+Vector2(-113,-14),pos+Vector2(30,-36),pos+Vector2(104,-28),pos+Vector2(99,28),pos+Vector2(-96,36)],Color("5b5546"))
	_polygon([pos+Vector2(-92,-44),pos+Vector2(-48,-82),pos+Vector2(76,-62),pos+Vector2(99,-29)],Color("303f3d"))
	draw_line(pos+Vector2(-110,32),pos+Vector2(127,32),Color("3b332b"),6)
	for x in [-58,65]:
		draw_circle(pos+Vector2(x,40),27,Color("2e3631"))
		draw_circle(pos+Vector2(x,40),15,Color("8b785a"))
		for i in range(6):
			var angle: float=float(i)*TAU/6.0
			draw_line(pos+Vector2(x,40),pos+Vector2(x+cos(angle)*24,40+sin(angle)*24),Color("b8a17a"),2)
	draw_line(pos+Vector2(99,14),pos+Vector2(205,55),Color("765a40"),5)
	draw_circle(pos+Vector2(-91,27),7,Color("a94e47"))

func _portrait(pos: Vector2, old: bool, scale_factor: float = 1.0) -> void:
	# Render the same transparent high-resolution character frames as the battle.
	# The escort uses the warm robe variant; no nearest filtering or pixel grid.
	var sheet: Texture2D = CharacterArt.make_sheet(old)
	var width: float = 158.0 * scale_factor
	var height: float = 198.0 * scale_factor
	draw_ellipse_ink(pos + Vector2(0, 85.0 * scale_factor),
		Vector2(68.0 * scale_factor, 13.0 * scale_factor), Color(0.01, 0.06, 0.06, 0.25))
	draw_texture_rect_region(sheet,
		Rect2(pos - Vector2(width * 0.5, height * 0.58), Vector2(width, height)),
		Rect2(0, 0, CharacterArt.FRAME_W, CharacterArt.FRAME_H))


func _lantern_light(pos: Vector2, t: float) -> void:
	# Warm pooled lantern light and wet-ground reflections against the cool rain.
	var warm: Color = Color("efbf77")
	var flicker: float = 1.0 + sin(t * 4.8) * 0.09
	for layer in range(6, 0, -1):
		var spread: float = float(layer) * 37.0
		draw_circle(pos, spread, Color(warm, 0.0055 * float(7 - layer) * flicker))
	draw_line(pos + Vector2(0, -100), pos + Vector2(0, -19), Color("544438"), 5)
	draw_line(pos + Vector2(-20, -80), pos + Vector2(20, -80), Color("6e5841"), 5)
	_polygon([pos + Vector2(-17, -65), pos + Vector2(17, -65),
		pos + Vector2(13, -24), pos + Vector2(-13, -24)], Color("eac589"))
	draw_rect(Rect2(pos + Vector2(-15, -67), Vector2(30, 45)), Color("6e5142"), false, 3)
	draw_line(pos + Vector2(0, -64), pos + Vector2(0, -25), Color("af754a"), 2)
	for ring in range(4):
		draw_ellipse_ink(pos + Vector2(0, 37 + ring * 13),
			Vector2(15.0 + ring * 14, 3.0 + ring), Color(warm, 0.13 / float(ring + 1)))


func _wet_road(t: float) -> void:
	# Dappled puddles and ripples preserve the original interaction coordinates.
	for i in range(28):
		var x: float = float((i * 167 + 121) % 1540) + 20.0
		var y: float = 686.0 + float((i * 73) % 265)
		var radius: float = 13.0 + float(i % 6) * 7.0
		var phase: float = fposmod(t * 30.0 + float(i * 17), 45.0)
		draw_arc(Vector2(x, y), radius + phase * 0.23,
			0.05, PI - 0.05, 16, Color(0.82, 0.91, 0.85, 0.09 * (1.0 - phase / 45.0)), 1.4)
		if i % 4 == 0:
			draw_line(Vector2(x - 38, y + 5), Vector2(x + 48, y + 3),
				Color(Color("b4c3ae"), 0.12), 2)


func _cinema_bars() -> void:
	draw_rect(Rect2(0, 0, 1600, 75), Color(0.03, 0.08, 0.09, 0.91))
	draw_rect(Rect2(0, 924, 1600, 76), Color(0.03, 0.08, 0.09, 0.91))
	draw_line(Vector2(0, 76), Vector2(1600, 76), Color(GOLD, 0.18), 2)
	draw_line(Vector2(0, 923), Vector2(1600, 923), Color(GOLD, 0.18), 2)

func _draw_menu() -> void:
	_sky(clock)
	draw_rect(Rect2(0,0,650,1000),Color(0.08,0.18,0.17,0.47))
	_paint_pavilion(Vector2(1290,755),1.1)
	_lantern_light(Vector2(1280,711),clock)
	_portrait(Vector2(1010,700),false,2.10)
	draw_circle(Vector2(800,370),105,Color(0.93,0.86,0.67,0.10))
	_text(Vector2(132,250),"MORTAL DAO  /  江 湖 浮 生",19,GOLD)
	_text(Vector2(118,384),"长风浮生录",77,PAPER,true)
	draw_line(Vector2(126,424),Vector2(618,424),GOLD,2)
	_text(Vector2(132,482),"英雄无百岁，刀剑不饶人。",23,Color("e1dcc7"),true)
	_text(Vector2(135,524),"由武入道 · 逆天改命",17,Color("bbcfc3"))
	_button(Rect2(137,595,391,65),"初入江湖 · 新游戏","start",true)
	_button(Rect2(137,672,391,57),"插画立体战场 · HD-2D","hd2d",true)
	_button(Rect2(137,741,391,53),"经典断桥论剑 · 旧版","duel",true)
	_button(Rect2(137,806,391,53),"群侠试炼 · 多人战斗","party",true)
	_button(Rect2(137,871,391,50),"退出游戏","quit",true)
	_text(Vector2(138,960),"序章演示 · 原创非像素插画 · 暮秋雨夜",13,Color("c3c9b6"))

func _draw_cinematic() -> void:
	_sky(clock,true)
	_rain(clock)
	var beat: Dictionary=story.current_beat()
	var duration: float=float(beat.get("duration",4.0))
	var opacity: float=clampf(minf(cinematic_elapsed/1.0,(duration-cinematic_elapsed)/0.7),0.0,1.0)
	var caption: String=str(beat.get("caption",""))
	var body: String=str(beat.get("text",""))
	var drift: float = sin(cinematic_elapsed * 0.55) * 13.0
	_paint_pavilion(Vector2(1120 + drift,752),0.98)
	_carriage(Vector2(800+sin(clock*.24)*7.0,743))
	_lantern_light(Vector2(1250 + drift,724),clock)
	if story.cinematic_index >= 1:
		_portrait(Vector2(315 - drift,730),false,1.80)
	if story.cinematic_index >= 2:
		_portrait(Vector2(1400,753),true,1.40)
	draw_rect(Rect2(0,0,1600,1000),Color(0.05,0.11,0.12,0.43))
	_cinema_bars()
	_center(Vector2(800,382),caption,32,Color(GOLD,opacity),true)
	_center(Vector2(800,484),body,27,Color(PAPER,opacity))
	_center(Vector2(800,556),"——  风雨入局  ——",18,Color(0.89,0.83,0.64,opacity))
	for index in range(story.data.cinematic.size()):
		draw_circle(Vector2(765+(index-1)*35,875),4,GOLD if index==story.cinematic_index else Color(0.79,0.82,0.76,0.36))
	_button(Rect2(1339,45,202,44),"跳过过场  Esc","skip",true)
	_text(Vector2(621,939),"空格 / 点击继续",15,Color("dadbd1"))

func _draw_explore() -> void:
	_sky(clock,true)
	_rain(clock,114)
	draw_rect(Rect2(0,0,1600,125),Color("203d3b"))
	_text(Vector2(62,72),"第一幕 · 雨夜残镖",36,PAPER,true)
	_text(Vector2(1090,67),"荒道破庙 / 暮秋 · 三更",17,GOLD)
	# Ground plane, wet path and scattered stones.
	_polygon([Vector2(0,650),Vector2(530,570),Vector2(1220,580),Vector2(1600,680),Vector2(1600,1000),Vector2(0,1000)],Color("515d54"))
	_polygon([Vector2(0,760),Vector2(465,666),Vector2(1130,676),Vector2(1600,776),Vector2(1600,1000),Vector2(0,1000)],Color(0.25,0.29,0.25,0.40))
	for i in range(45):
		var px: float=float((i*137+62)%1550)
		var py: float=678+float((i*41)%293)
		draw_line(Vector2(px,py),Vector2(px+16,py-2),Color(0.68,0.74,0.65,0.13),1)
	_wet_road(clock)
	_paint_pavilion(Vector2(1280,570),0.9)
	_carriage(Vector2(837,625))
	_lantern_light(Vector2(1233,574),clock)
	_portrait(ESCORT+Vector2(0,10),true)
	_portrait(player_pos,false)
	var near: bool=player_pos.distance_to(ESCORT)<175.0
	if near:
		draw_arc(ESCORT+Vector2(0,-15),100,0,TAU,48,Color(GOLD,0.65+sin(clock*3.0)*0.20),2,true)
		_button(Rect2(882,366,426,55),"E  与受伤镖头交谈","talk",true)
	else:
		_text(Vector2(843,370),"老镖头  ·  似乎还有气息",18,Color("e1d2ac"))
	_panel(Rect2(76,837,1448,125),Color(0.13,0.22,0.20,0.91),Color(GOLD,0.75))
	_text(Vector2(112,881),"沿官道走近镖车，查探伤者。",23,PAPER,true)
	_text(Vector2(114,920),"WASD / 方向键移动    靠近后按 E 交谈    ·    这是序章中的可操作叙事场景",15,Color("d5c8aa"))
	if message_left>0: _text(Vector2(120,809),message,18,GOLD)

func _draw_dialogue() -> void:
	_draw_explore_backdrop()
	var node: Dictionary=story.current_dialogue()
	var speaker: String=str(node.get("speaker",""))
	var full_text: String=str(node.get("text",""))
	draw_rect(Rect2(0,0,1600,1000),Color(0.07,0.12,0.12,0.29))
	_panel(Rect2(124,665,1352,292),Color("eae3cf"),GOLD)
	# Classic wuxia character frame / nameplate.
	_panel(Rect2(153,574,227,308),Color("38534c"),GOLD)
	_portrait(Vector2(266,738),speaker=="老镖头",1.18)
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
	_polygon([Vector2(0,665),Vector2(600,600),Vector2(1200,610),Vector2(1600,720),Vector2(1600,1000),Vector2(0,1000)],Color("525e56"))
	_wet_road(clock)
	_paint_pavilion(Vector2(1270,580),0.9)
	_carriage(Vector2(822,628))
	_lantern_light(Vector2(1225,582),clock)
	_portrait(ESCORT+Vector2(0,10),true)
	_portrait(player_pos,false)

func _draw_complete() -> void:
	_sky(clock,true)
	_rain(clock,90)
	_carriage(Vector2(1090,650))
	draw_rect(Rect2(0,0,1600,1000),Color(0.05,0.12,0.12,0.40))
	_panel(Rect2(235,180,1130,696),Color("e9e4d6"),GOLD)
	_center(Vector2(800,290),"江 湖 初 入",39,INK,true)
	draw_line(Vector2(446,324),Vector2(1154,324),Color(GOLD,0.55),2)
	_center(Vector2(800,400),"《太虚引气残篇》",32,RED,true)
	_center(Vector2(800,470),"一卷无名绢帛，一场未完的血案。",24,INK,true)
	_center(Vector2(800,525),"你尚不知道，它将牵出多少江湖恩怨。",20,INK)
	_center(Vector2(800,579),"远处的马蹄声越来越近……",19,Color("846d4e"))
	_button(Rect2(430,639,742,70),"迎战追兵 · 继续序章","story_battle",true)
	_button(Rect2(430,734,350,58),"插画战斗场景预览","hd2d",true)
	_button(Rect2(822,734,350,58),"群侠战斗试玩","party",true)
	_button(Rect2(626,810,350,49),"返回主菜单","menu",true)

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
