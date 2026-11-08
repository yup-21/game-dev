extends Node2D
## Data-driven title screen, ink-wash prologue, walkable vignette and classic wuxia dialogue.
## Presentation only: chapter flow is in OpeningStory; existing battles are separate scenes.
const Story = preload("res://scripts/opening_story.gd")
const ArtCatalog = preload("res://scripts/hd2d_art_catalog.gd")
const RoleSprite = preload("res://scripts/opening_role_sprite.gd")
const StoryRoleScene = preload("res://scenes/actors/story_role.tscn")
const StoryNPCScene = preload("res://scenes/actors/story_npc.tscn")
const WorldViewport = preload("res://scripts/world_viewport_offset.gd")
const PAPER = Color("eee9dc")
const INK = Color("233c3c")
const JADE = Color("3a8178")
const GOLD = Color("c5a16b")
const RED = Color("aa5548")
const ESCORT = Vector2(1050, 560)
const TEMPLE_PAINTING = "res://assets/imported/scenes/ruined_temple/legacy/story.webp"
var story = Story.new()
var chapter_scene: Dictionary = {}
var npc_position: Vector2 = ESCORT
var background_path: String = TEMPLE_PAINTING
var scene_art_path: String = ""
var story_art_profile: WuxiaSceneArtProfile
var story_world_size: Vector2i = Vector2i(1600, 1000)
var story_stage_offset: Vector2 = Vector2.ZERO
var npc_character_id: String = "escort_elder"

func _load_chapter_content() -> void:
	var session = _session()
	if session == null or not session.has_method("chapter_definition"):
		return
	var chapter: Dictionary = session.chapter_definition()
	if chapter.is_empty():
		return
	chapter_scene = chapter.get("scene",{}).duplicate(true)
	npc_character_id = str(chapter_scene.get("npc_character_id","escort_elder"))
	npc_position = Vector2(float(chapter_scene.npc_position[0]),float(chapter_scene.npc_position[1]))
	background_path = str(chapter_scene.get("background",TEMPLE_PAINTING))
	scene_art_path = str(chapter_scene.get("scene_art",""))
	var authored_extent: Array = chapter_scene.get("world_size", [1600, 1000])
	story_world_size = Vector2i(int(authored_extent[0]), int(authored_extent[1]))
	player_pos = Vector2(float(chapter_scene.player_position[0]),float(chapter_scene.player_position[1]))
	story = Story.new(str(chapter.story_path))
	if session.phase == "story":
		story.begin()

func _scene_text(key: String, fallback: String) -> String:
	return str(chapter_scene.get(key,fallback))

func _visible_choices() -> Array:
	var session = _session()
	return story.available_choices(session.flags if session != null else {})

func _npcs() -> Array:
	var authored: Variant = chapter_scene.get("npcs",[])
	if authored is Array and not authored.is_empty(): return authored
	return [{"character_id":npc_character_id,"position":[npc_position.x,npc_position.y],
		"talk_label":_scene_text("talk_label","与受伤镖头交谈"),"trigger_id":""}]

func _npc_point(entry: Dictionary) -> Vector2:
	var coordinates: Array = entry.get("position",[npc_position.x,npc_position.y])
	return Vector2(float(coordinates[0]),float(coordinates[1]))

func _nearest_npc() -> Dictionary:
	var nearest: Dictionary = {}
	var distance: float = INF
	for entry in _npcs():
		if not entry is Dictionary: continue
		var candidate: float = player_pos.distance_to(_npc_point(entry))
		if candidate < distance:
			distance = candidate
			nearest = entry
	return nearest

func _npc_distance() -> float:
	var nearest: Dictionary = _nearest_npc()
	return player_pos.distance_to(_npc_point(nearest)) if not nearest.is_empty() else INF

var temple_backdrop: Texture2D
var temple_uses_fallback := false
var temple_picture: TextureRect
var ground_picture: TextureRect
var foreground_picture: TextureRect
var weather_picture: TextureRect
var foreground_clip: Control
var weather_clip: Control
var story_weather_enabled: bool = true
var ui_font: SystemFont
var title_font: SystemFont
var clock: float = 0.0
var cinematic_elapsed: float = 0.0
var visible_characters: float = 0.0
var player_pos: Vector2 = Vector2(350, 705)
var characters_layer: Node2D
var player_sprite: Node2D
var escort_sprite: Node2D
var npc_sprites: Array[Node2D] = []
var message: String = ""
var message_left: float = 0.0
var _dialogue_portrait_speaker: String = ""
var _cinematic_overlay_index := -1

func _ready() -> void:
	_load_chapter_content()
	_load_temple_background()
	_build_temple_picture()
	if temple_backdrop == null:
		return
	ui_font = SystemFont.new()
	ui_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Segoe UI"])
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["KaiTi", "STKaiti", "Microsoft YaHei"])
	DisplayServer.window_set_min_size(Vector2i(1050, 680))
	if not story.load_error.is_empty():
		push_error(story.load_error)
		return
	# In-world roles are actual Sprite2D nodes. Only painted scenery and
	# interface text are still drawn by the opening canvas.
	characters_layer = get_node("StoryCharacters")
	player_sprite = StoryRoleScene.instantiate()
	if not player_sprite.configure("shen_changfeng"):
		push_error("Cannot load Shen Changfeng story sprite")
	characters_layer.add_child(player_sprite)
	npc_sprites.clear()
	for entry in _npcs():
		var npc_sprite: Node2D = StoryNPCScene.instantiate()
		if not npc_sprite.configure_npc(str(entry.get("character_id","")),
				str(entry.get("trigger_id", "")), str(entry.get("talk_label", "交谈"))):
			push_error("Cannot load story NPC sprite: " + str(entry.get("character_id","")))
			npc_sprite.free()
			continue
		npc_sprite.interaction_requested.connect(_start_dialogue)
		characters_layer.add_child(npc_sprite)
		npc_sprites.append(npc_sprite)
	escort_sprite = npc_sprites[0] if not npc_sprites.is_empty() else null
	_sync_story_sprites(Vector2.ZERO,0.0)
	_bind_native_menu()
	_bind_native_story_ui()
	print("CHANGFENG_OPENING_READY chapter=", story.data.id)
	if "--opening-visual-check" in OS.get_cmdline_user_args():
		call_deferred("_run_visual_check")

func _bind_native_menu() -> void:
	# Buttons live in opening.tscn and remain editable in the Inspector.
	for node in $NativeMenuUI/MenuControls.get_children():
		if node is Button:
			var action: String = str(node.get_meta("action", ""))
			if not action.is_empty():
				node.pressed.connect(_action.bind(action))

func _bind_native_story_ui() -> void:
	$ExploreUI/ExploreHUD/TalkButton.pressed.connect(_start_dialogue)
	$DialogueUI/Continue.pressed.connect(_dialogue_next)
	for index in range(3):
		var choice: Button = $DialogueUI.get_node("Choice%d" % (index + 1))
		choice.pressed.connect(_dialogue_choice.bind(index))
	$CompleteUI/BeginBattle.pressed.connect(_action.bind("story_battle"))
	$CompleteUI/BackToMenu.pressed.connect(_action.bind("menu"))
	$CinematicOverlay/CinematicSkip.pressed.connect(_action.bind("skip"))

func _sync_native_story_ui() -> void:
	$ExploreUI.visible = story.phase == "explore"
	$DialogueUI.visible = story.phase == "dialogue"
	$CompleteUI.visible = story.phase == "complete"
	if story.phase == "explore":
		var nearest: Dictionary = _nearest_npc()
		var talk: Button = $ExploreUI/ExploreHUD/TalkButton
		talk.visible = _npc_distance() < 175.0 and not nearest.is_empty()
		if talk.visible:
			talk.text = "E  " + str(nearest.get("talk_label", "交谈"))
		$ExploreUI/ExploreHUD/ChapterName.text = _scene_text("title", "第一幕 · 雨夜残镖")
		$ExploreUI/ExploreHUD/Location.text = _scene_text("place", "荒道破庙 / 暮秋 · 三更")
		$ExploreUI/ExploreHUD/Prompt.text = _scene_text("prompt", "沿官道走近镖车，查探伤者。")
		$ExploreUI/ExploreHUD/Message.text = message if message_left > 0.0 else ""
	elif story.phase == "dialogue":
		var node: Dictionary = story.current_dialogue()
		var speaker: String = str(node.get("speaker", ""))
		$DialogueUI/Speaker.text = speaker
		if _dialogue_portrait_speaker != speaker:
			_dialogue_portrait_speaker = speaker
			$DialogueUI/Portrait.texture = ArtCatalog.portrait(speaker) if not speaker.is_empty() else null
		var whole: String = str(node.get("text", ""))
		$DialogueUI/Body.text = whole.substr(0, mini(whole.length(), int(visible_characters)))
		var complete: bool = int(visible_characters) >= whole.length()
		var choices: Array = _visible_choices() if complete else []
		$DialogueUI/Continue.visible = complete and choices.is_empty()
		$DialogueUI/Hint.text = ("空格 / 回车 / 点击继续" if choices.is_empty() else "选择一项继续") \
			if complete else "点击显示全文  ▸"
		for index in range(3):
			var choice: Button = $DialogueUI.get_node("Choice%d" % (index + 1))
			choice.visible = complete and index < choices.size()
			if choice.visible:
				choice.text = "%d  %s" % [index + 1, str(choices[index].text)]
	elif story.phase == "complete":
		$CompleteUI/Title.text = _scene_text("complete_title", "江 湖 初 入")
		$CompleteUI/Reward.text = _scene_text("reward_label", "《太虚引气残篇》")
		$CompleteUI/Caption.text = _scene_text("complete_caption", "一卷无名绢帛，一场未完的血案。")
		$CompleteUI/Subtitle.text = _scene_text("complete_subtitle", "你尚不知道，它将牵出多少江湖恩怨。")
		$CompleteUI/Notice.text = _scene_text("complete_text", "远处的马蹄声越来越近……")
		$CompleteUI/BeginBattle.text = _scene_text("battle_label", "迎战追兵 · 继续序章")

func _run_visual_check() -> void:
	var check=load("res://checks/opening_visual_check.gd").new()
	await check.run(self)

func _process(delta: float) -> void:
	$NativeMenuUI.visible = story.phase == "menu"
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
				var limits: Array = chapter_scene.get("player_bounds",[155,345,1415,755])
				player_pos = (player_pos+vector.normalized()*195.0*delta).clamp(
					Vector2(float(limits[0]),float(limits[1])),
					Vector2(float(limits[2]),float(limits[3])))
			_sync_story_sprites(vector,delta)
		"dialogue":
			var line: Dictionary = story.current_dialogue()
			visible_characters = minf(float(str(line.get("text", "")).length()),visible_characters+delta*29.0)
	if story.phase != "explore":
		_sync_story_sprites(Vector2.ZERO,delta)
	_sync_cinematic_overlay()
	_sync_native_story_ui()
	if temple_picture != null:
		temple_picture.visible = story.phase in ["explore","dialogue","complete"] or (story.phase=="cinematic" and story.cinematic_index > 0)
	if ground_picture != null:
		ground_picture.visible = temple_picture != null and temple_picture.visible
	if foreground_clip != null:
		foreground_clip.visible = story.phase == "explore"
	if weather_clip != null:
		weather_clip.visible = story.phase == "explore" and story_weather_enabled
	queue_redraw()

func _sync_cinematic_overlay() -> void:
	var overlay: CanvasLayer = $CinematicOverlay
	overlay.visible = story.phase == "cinematic"
	if not overlay.visible:
		_cinematic_overlay_index = -1
		return
	var beat: Dictionary = story.current_beat()
	overlay.get_node("CinematicText/Caption").text = str(beat.get("caption", ""))
	overlay.get_node("CinematicText/Body").text = str(beat.get("text", ""))
	if _cinematic_overlay_index != story.cinematic_index:
		_cinematic_overlay_index = story.cinematic_index
		overlay.get_node("CinematicAnimations").play("fade_in")

## Painted story world, NPCs and gameplay share one scroll offset.
## HUD stays at 1600x1000. Mouse position uses the exact inverse mapping.
func _update_story_camera() -> void:
	if story.phase in ["explore", "dialogue"]:
		story_stage_offset = WorldViewport.world_offset(player_pos, Vector2(story_world_size))
	else:
		story_stage_offset = Vector2.ZERO
	if temple_picture != null:
		temple_picture.position = story_stage_offset
	if ground_picture != null:
		ground_picture.position = story_stage_offset
	for overlay in [foreground_picture, weather_picture]:
		if overlay != null:
			# Clip viewport starts at y=106; cancel its local-space offset.
			overlay.position = story_stage_offset - Vector2(0, 106)
	if characters_layer != null:
		characters_layer.position = story_stage_offset

func _story_screen_to_world(point: Vector2) -> Vector2:
	return WorldViewport.screen_to_world(point, story_stage_offset)

func _sync_story_sprites(motion: Vector2, delta: float) -> void:
	if player_sprite == null or characters_layer == null:
		return
	# Story cinematics and dialogue draw their authored static portraits
	# separately. Do not let in-world sprites paint over dialogue controls.
	var exploring: bool = story.phase == "explore"
	characters_layer.visible = exploring
	player_sprite.position = player_pos
	_update_story_camera()
	player_sprite.set_motion(motion,delta)
	# Tile feet anchor sorting, not fixed painter's layers.
	player_sprite.z_index = clampi(int(player_pos.y/100.0), 0, 10)
	var index: int = 0
	for entry in _npcs():
		if index >= npc_sprites.size(): break
		var position: Vector2 = _npc_point(entry) + Vector2(0,10)
		npc_sprites[index].position = position
		npc_sprites[index].set_motion(Vector2.ZERO,delta)
		npc_sprites[index].z_index = clampi(int(position.y / 100.0), 0, 10)
		index += 1

func _session():
	return get_node_or_null("/root/GameSession")

func _enter_new_game() -> void:
	var session=_session()
	if session!=null:
		session.start_new_game()
		if session.activate_prologue_chase():
			call_deferred("_change_scene", session.scene_for("prologue"))
			return
	_load_chapter_content()
	# Rebind the existing authored nodes; freeing them would destroy their
	# editor-configured transforms and break the next chapter's layer lookup.
	for layer in [temple_picture, ground_picture, foreground_clip, weather_clip]:
		if layer != null:
			layer.visible = false
			if layer is TextureRect:
				layer.texture = null
	temple_picture = null
	ground_picture = null
	foreground_picture = null
	weather_picture = null
	foreground_clip = null
	weather_clip = null
	story_weather_enabled = true
	_load_temple_background()
	_build_temple_picture()
	story.begin()
	cinematic_elapsed = 0.0
	visible_characters = 0.0
	var spawn: Array = chapter_scene.get("player_position",[350,705])
	player_pos = Vector2(float(spawn[0]),float(spawn[1]))
	_sync_story_sprites(Vector2.ZERO,0.0)
	message = ""

func _advance_cinematic() -> void:
	story.next_beat()
	cinematic_elapsed = 0.0

func _start_dialogue(trigger_id: String = "") -> void:
	var nearest: Dictionary = _nearest_npc()
	var selected: String = trigger_id if not trigger_id.is_empty() else str(nearest.get("trigger_id",""))
	if story.interact_at(selected):
		_sync_story_events()
		visible_characters = 0.0

func _dialogue_next() -> void:
	if story.phase != "dialogue": return
	var node: Dictionary=story.current_dialogue()
	if visible_characters < float(str(node.get("text","")).length()):
		visible_characters = float(str(node.text).length())
		return
	if _visible_choices().is_empty() and story.advance_dialogue(_session().flags if _session()!=null else {}):
		_sync_story_events()
		visible_characters = 0.0

func _dialogue_choice(index: int) -> void:
	if story.phase != "dialogue": return
	var node: Dictionary=story.current_dialogue()
	if visible_characters < float(str(node.get("text","")).length()): return
	var session=_session()
	var old_node: String=story.dialogue_id
	if story.choose(index,session.flags if session!=null else {}):
		if session!=null: session.record_choice(old_node,index)
		_sync_story_events()
		visible_characters=0.0

func _sync_story_events() -> void:
	var session=_session()
	if session==null: return
	var events: Array=story.take_events()
	if not events.is_empty() and not session.apply_story_events(events):
		message="剧情事件配置错误，请检查章节数据"
		message_left=4.0
		push_error(message)
	story.complete_if_ready(session.flags)

func _change_scene(path: String) -> void:
	var err: int = get_tree().change_scene_to_file(path)
	if err != OK:
		message = "场景加载失败：" + path
		message_left = 4.0
		push_error(message)

func _action(action: String) -> void:
	match action:
		"start": _enter_new_game()
		"pingjiang_exploration":
			call_deferred("_change_scene", "res://scenes/pingjiang_exploration.tscn")
		"prologue_native_qa":
			# Isolated editable scene blockout; no changes to the formal chapter.
			call_deferred("_change_scene", "res://scenes/prologue/prologue_exploration.tscn")
		"pingjiang_qa":
			# Isolated scene preview: no chapter flags or session mutations.
			call_deferred("_change_scene", "res://scenes/pingjiang_scroll_qa.tscn")
		"pingjiang_vertical_qa":
			call_deferred("_change_scene", "res://scenes/pingjiang_vertical_qa.tscn")
		"pingjiang_25d_qa":
			# Perspective experiment, not a production map or combat entry.
			call_deferred("_change_scene", "res://prototypes/pingjiang_25d/pingjiang_25d_validation.tscn")
		"pingjiang_south_gate_qa":
			call_deferred("_change_scene", "res://scenes/pingjiang_south_gate_qa.tscn")
		"shen_house_qa":
			call_deferred("_change_scene", "res://scenes/pingjiang_shen_house_qa.tscn")
		"hd2d":
			var quick_session = _session()
			if quick_session != null and quick_session.start_quick_battle():
				call_deferred("_change_scene", quick_session.scene_for("battle"))
			else:
				push_error("Native quick encounter unavailable")
		"story_battle":
			var session=_session()
			if session!=null and session.begin_encounter():
				call_deferred("_change_scene", session.scene_for("battle"))
			else:
				message="尚未满足本章战斗触发条件"
				message_left=3.0
		"quit": get_tree().quit()
		"menu":
			story.reset()
			var session=_session()
			if session!=null:
				session.return_to_menu()
				call_deferred("_change_scene",session.scene_for("menu"))
		"skip": story.skip_cinematic()
		"continue": _advance_cinematic()
		"talk": _start_dialogue()
		"next": _dialogue_next()
		_:
			if action.begins_with("choice:"): _dialogue_choice(int(action.substr(7)))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match story.phase:
			"menu":
				if event.keycode in [KEY_ENTER, KEY_SPACE]: _action("start")
				elif event.keycode == KEY_P: _action("pingjiang_qa")
				elif event.keycode == KEY_V: _action("pingjiang_vertical_qa")
				elif event.keycode == KEY_T: _action("pingjiang_25d_qa")
				elif event.keycode == KEY_G: _action("pingjiang_south_gate_qa")
				elif event.keycode == KEY_J: _action("pingjiang_exploration")
				elif event.keycode == KEY_H: _action("shen_house_qa")
				elif event.keycode == KEY_K: _action("prologue_native_qa")
			"cinematic":
				if event.keycode in [KEY_ESCAPE, KEY_S]: _action("skip")
				elif event.keycode in [KEY_ENTER,KEY_SPACE]: _action("continue")
			"explore":
				if event.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]:
					if _npc_distance() < 175.0:
						var chosen: Dictionary = _nearest_npc()
						_start_dialogue(str(chosen.get("trigger_id", "")))
					else:
						message = "请先靠近人物，再按 E 交谈。"
						message_left = 2.3
			"dialogue":
				if event.keycode in [KEY_E,KEY_ENTER,KEY_SPACE]:
					if _visible_choices().is_empty(): _dialogue_next()
					elif visible_characters < float(str(story.current_dialogue().get("text","")).length()):
						visible_characters = float(str(story.current_dialogue().text).length())
				if event.keycode in [KEY_1,KEY_2,KEY_3]:
					_dialogue_choice(int(event.keycode-KEY_1))
			"complete":
				if event.keycode in [KEY_ENTER,KEY_SPACE]: _action("story_battle")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# _input runs before GUI dispatch: do not advance the story when
		# an editor-authored Button is the intended receiver of this click.
		if story.phase in ["menu", "complete"]:
			return
		if story.phase == "cinematic" and $CinematicOverlay/CinematicSkip.get_global_rect().has_point(event.position):
			return
		if story.phase == "explore":
			var talk_button: Button = $ExploreUI/ExploreHUD/TalkButton
			if talk_button.visible and talk_button.get_global_rect().has_point(event.position):
				return
		if story.phase == "dialogue":
			for ui_button in [$DialogueUI/Continue, $DialogueUI/Choice1,
					$DialogueUI/Choice2, $DialogueUI/Choice3]:
				if ui_button.visible and ui_button.get_global_rect().has_point(event.position):
					return
		match story.phase:
			"cinematic": _action("continue")
			"explore":
				for entry in _npcs():
					if _story_screen_to_world(event.position).distance_to(_npc_point(entry)) < 90.0 and player_pos.distance_to(_npc_point(entry)) < 175.0:
						_start_dialogue(str(entry.get("trigger_id","")))
						break
			"dialogue": _dialogue_next()

func _text(pos: Vector2, value: String, size: int = 19, color: Color = INK, calligraphy: bool = false) -> void:
	draw_string(title_font if calligraphy else ui_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _polygon(vertices: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(vertices),color)

func _panel(rect: Rect2, bg: Color, border: Color = Color.TRANSPARENT) -> void:
	draw_rect(Rect2(rect.position+Vector2(4,6),rect.size),Color(0.09,0.12,0.11,0.19))
	draw_rect(rect,bg)
	if border.a > 0: draw_rect(rect,border,false,2)
	draw_line(rect.position+Vector2(14,12),rect.position+Vector2(rect.size.x-14,12),Color(GOLD,0.36),1)

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

func _cover_texture(texture: Texture2D, area: Rect2, tint: Color = Color.WHITE) -> void:
	# Crop, never stretch: wide backdrops and vertical paintings retain proportion.
	var size := Vector2(texture.get_size())
	var source := Rect2(Vector2.ZERO, size)
	var target_ratio := area.size.x / area.size.y
	var image_ratio := size.x / size.y
	if image_ratio > target_ratio:
		var width := size.y * target_ratio
		source.position.x = (size.x - width) * 0.5
		source.size.x = width
	else:
		var height := size.x / target_ratio
		source.position.y = (size.y - height) * 0.5
		source.size.y = height
	draw_texture_rect_region(texture, area, source, tint)

func _painted_portrait(speaker: String, area: Rect2, tint: Color = Color.WHITE) -> bool:
	var painting := ArtCatalog.portrait(speaker)
	if painting == null:
		return false
	_cover_texture(painting, area, tint)
	return true

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
	var landscape := ArtCatalog.scenery("mountain")
	if landscape != null:
		_cover_texture(landscape, Rect2(0,0,1600,1000), Color(0.54,0.67,0.65,0.90))
	draw_rect(Rect2(0,0,1600,1000),Color(0.04,0.12,0.13,0.31))
	draw_rect(Rect2(0,0,665,1000),Color(0.07,0.16,0.16,0.84))
	_panel(Rect2(855,91,510,813),Color(0.07,0.15,0.15,0.62),Color(GOLD,0.7))
	_painted_portrait("沈长风",Rect2(865,101,490,792))
	draw_circle(Vector2(800,370),105,Color(0.93,0.86,0.67,0.10))
	draw_line(Vector2(126,424),Vector2(618,424),GOLD,2)
	# Interactive title/menu typography is in the native CanvasLayer.
	# The scene QA entry is independent of the prologue and battle session.
	# Old duel and party scenes are intentionally absent from player menus.

func _draw_cinematic() -> void:
	# First beat is a memory of the destroyed school; the later rain
	# beats use the EXACT same painted temple shown in playable exploration.
	if story.cinematic_index > 0 and _temple_background():
		pass
	else:
		_sky(clock,true)
		if story.cinematic_index == 0:
			var memory := ArtCatalog.scenery("mountain")
			if memory != null:
				_cover_texture(memory,Rect2(0,0,1600,1000),Color(0.37,0.50,0.51,0.68))
	_rain(clock)
	var drift: float = sin(cinematic_elapsed * 0.55) * 13.0
	if story.cinematic_index==0 or not ResourceLoader.exists(background_path):
		_paint_pavilion(Vector2(1120 + drift,752),0.98)
		_carriage(Vector2(800+sin(clock*.24)*7.0,743))
		_lantern_light(Vector2(1250 + drift,724),clock)
	if story.cinematic_index >= 1:
		_painted_portrait("沈长风",Rect2(80-drift,235,375,635),Color(1,1,1,0.76))
	if story.cinematic_index >= 2:
		_painted_portrait("老镖头",Rect2(1285,395,260,455),Color(1,1,1,0.70))
	draw_rect(Rect2(0,0,1600,1000),Color(0.05,0.11,0.12,0.43))
	_cinema_bars()
	# Caption/body/fade are editable Label and AnimationPlayer tracks in opening.tscn.
	for index in range(story.data.cinematic.size()):
		draw_circle(Vector2(765+(index-1)*35,875),4,GOLD if index==story.cinematic_index else Color(0.79,0.82,0.76,0.36))
	# Skip and hint are native Controls in the CinematicOverlay.

## The generated painting is the entire walkable world, never a wallpaper
## behind a second programmatic road/carriage. Character sprites are separate.
## A file can exist and still contain an all-white placeholder.
## Treat image content, not ResourceLoader.exists(), as the readiness test.
## Evaluate once on scene creation rather than decoding WebP every _draw().
func _painted_content(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var image: Image = texture.get_image()
	if image == null or image.is_empty() or image.get_width() < 256 or image.get_height() < 256:
		return false
	var painted := 0
	for y in range(1, 8):
		for x in range(1, 8):
			var pixel: Color = image.get_pixel(
				mini(image.get_width() - 1, int(float(x) * float(image.get_width()) / 8.0)),
				mini(image.get_height() - 1, int(float(y) * float(image.get_height()) / 8.0)))
			if pixel.a > 0.50 and minf(pixel.r, minf(pixel.g, pixel.b)) < 0.86:
				painted += 1
	# A genuine full-screen backdrop must have substantial coverage, not
	# merely a few dark border pixels around a mostly white placeholder.
	return painted >= 20

func _load_temple_background() -> void:
	temple_uses_fallback = false
	temple_backdrop = null
	story_art_profile = null
	if not scene_art_path.is_empty():
		if not scene_art_path.begins_with("res://data/") or scene_art_path.contains("..") or not ResourceLoader.exists(scene_art_path):
			push_error("Authored chapter scene layers missing: " + scene_art_path)
			return
		var authored: WuxiaSceneArtProfile = ResourceLoader.load(scene_art_path) as WuxiaSceneArtProfile
		if authored == null or not authored.valid_for(story_world_size):
			push_error("Invalid authored chapter scene layers: " + scene_art_path)
			return
		story_art_profile = authored
		temple_backdrop = authored.background
	elif ResourceLoader.exists(background_path):
		var original: Texture2D = ResourceLoader.load(background_path, "Texture2D") as Texture2D
		if _painted_content(original):
			temple_backdrop = original
	if not _painted_content(temple_backdrop):
		push_error("Required chapter background is missing or blank: " + background_path)

## WebP was loaded but the previous draw_texture_rect_region() path rendered
## white in the opening viewport. Use the same native TextureRect presentation
## as the battle scenery, at a negative canvas Z behind UI and role sprites.
func _build_temple_picture() -> void:
	if temple_backdrop == null:
		return
	temple_picture = get_node("FirstActPaintedBackground") as TextureRect
	temple_picture.texture = temple_backdrop
	temple_picture.position = Vector2.ZERO
	temple_picture.size = Vector2(story_world_size)
	temple_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	temple_picture.stretch_mode = TextureRect.STRETCH_SCALE if story_art_profile != null else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	temple_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	temple_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	temple_picture.z_index = -100
	temple_picture.modulate = Color.WHITE
	temple_picture.visible = false
	if story_art_profile != null:
		ground_picture = _add_story_art_layer("GroundArt", story_art_profile.ground, -90)
		foreground_picture = _add_story_art_layer("ForegroundOcclusion", story_art_profile.foreground, 12, true)
		weather_picture = _add_story_art_layer("WeatherOverlay", story_art_profile.weather, 13, true)

func _add_story_art_layer(label: String, texture: Texture2D, depth: int, clip_to_world: bool = false) -> TextureRect:
	if texture == null:
		return null
	var native_path: String = label + "Clip/" + label if clip_to_world else label
	var image: TextureRect = get_node_or_null(native_path) as TextureRect
	if image == null:
		push_error("Missing native story layer: " + native_path)
		return null
	image.texture = texture
	image.position = Vector2.ZERO
	image.size = Vector2(story_world_size)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if clip_to_world:
		# Keep foreground and rain above feet, never over the chapter HUD.
		var clip: Control = get_node(label + "Clip") as Control
		clip.position = Vector2(0,106)
		clip.size = Vector2(1600,730)
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.z_index = depth
		clip.visible = false
		image.position = Vector2(0,-106)
		if label == "WeatherOverlay":
			weather_clip = clip
		else:
			foreground_clip = clip
	else:
		image.z_index = depth
		image.visible = false
	return image


func set_story_weather_enabled(enabled: bool) -> void:
	story_weather_enabled = enabled
	if weather_clip != null:
		weather_clip.visible = enabled and story.phase == "explore"


func _temple_background() -> bool:
	# The painted TextureRect is a real scene child; calling drawing commands
	# from outside Node2D._draw() is no longer necessary.
	return temple_picture != null and temple_picture.texture != null

func _paint_exploration() -> void:
	if not _temple_background():
		_sky(clock,true)
		_wet_road(clock)
		_paint_pavilion(Vector2(1280,570),0.9)
		_carriage(Vector2(837,625))
	if story_weather_enabled and (story_art_profile == null or story_art_profile.weather == null):
		_rain(clock,110)
	# Shen Changfeng and the escort elder are now Sprite2D scene children.
	# Never paint character frames through this CanvasItem.

func _draw_explore() -> void:
	_paint_exploration()
	var nearest: Dictionary = _nearest_npc()
	if _npc_distance() < 175.0 and not nearest.is_empty():
		draw_arc(_npc_point(nearest) + story_stage_offset + Vector2(0, -14),
			75, 0, TAU, 48, Color(GOLD, 0.65 + sin(clock * 3.0) * 0.20), 2, true)
	else:
		for entry in _npcs():
			_text(_npc_point(entry) + story_stage_offset + Vector2(-85, -110),
				str(entry.get("talk_label", "交谈")), 16, Color("e1d2ac"))
	# All viewport HUD text and TalkButton are native in ExploreUI.

func _draw_dialogue() -> void:
	_draw_explore_backdrop()
	# Speaker, portrait, typewriter text and choice Buttons live in DialogueUI.

func _draw_explore_backdrop() -> void:
	_paint_exploration()

func _draw_complete() -> void:
	if not _temple_background():
		_sky(clock, true)
		_carriage(Vector2(1090, 650))
	_rain(clock, 90)
	draw_rect(Rect2(0, 0, 1600, 1000), Color(0.05, 0.12, 0.12, 0.40))
	# Completion actions and typography live in CompleteUI.

func _draw() -> void:
	if ui_font==null or story.load_error!="": return
	match story.phase:
		"menu": _draw_menu()
		"cinematic": _draw_cinematic()
		"explore": _draw_explore()
		"dialogue": _draw_dialogue()
		"complete": _draw_complete()
		_: _draw_menu()
