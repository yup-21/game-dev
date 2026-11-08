extends Node2D
## Native-scene prologue blockout: hall spawn -> outside investigation -> return ambush.
## All zone silhouettes, foot polygons, obstacles, exits and spawn markers are
## editable inside scenes/prologue/zones/*.tscn in Godot's 2D editor.

const Progress = preload("res://scripts/prologue/prologue_progress.gd")
const Story = preload("res://scripts/opening_story.gd")
const CombatScale = preload("res://scripts/combat_scale.gd")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")
const ACTOR_PROFILE_PATH := "res://data/native/animations/shen_changfeng.tres"
const CHASE_STORY_PATH := "res://data/native/stories/prologue_chase_story.tres"
const MOVE_SPEED := 260.0
const ZONE_SCENES := {
	"temple_hall": preload("res://scenes/prologue/zones/temple_hall.tscn"),
	"temple_courtyard": preload("res://scenes/prologue/zones/temple_courtyard.tscn"),
	"mountain_road": preload("res://scenes/prologue/zones/mountain_road.tscn"),
	"broken_bridge": preload("res://scenes/prologue/zones/broken_bridge.tscn")
}

@onready var zone_host: Node2D = $CurrentZone
@onready var hero: Node2D = $ShenChangfeng
@onready var camera: Camera2D = $ShenChangfeng/Camera2D
@onready var avatar: Sprite2D = $ShenChangfeng/Avatar
@onready var status: Label = $Interface/Status
@onready var escort_follower: Sprite2D = $EscortFollower
@onready var dialogue_panel: PanelContainer = $Interface/DialoguePanel
@onready var dialogue_speaker: Label = $Interface/DialoguePanel/Content/Speaker
@onready var dialogue_body: Label = $Interface/DialoguePanel/Content/Body
@onready var continue_button: Button = $Interface/DialoguePanel/Content/Actions/Continue
@onready var choice_buttons: Array[Button] = [
	$Interface/DialoguePanel/Content/Actions/Choice1,
	$Interface/DialoguePanel/Content/Actions/Choice2]
@onready var failure_panel: PanelContainer = $Interface/FailurePanel

var current_zone: Node2D
var progress = Progress.new()
var profile: WuxiaActorAnimationProfile
var animation_time: float = 0.0
var show_navigation: bool = false
var notice: String = ""
var fire_animation_time: float = 0.0
var formal_mode: bool = false
var session: Node
var story: RefCounted
var dialogue_outcome: String = ""
var escort_follow_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	session = get_node_or_null("/root/GameSession")
	formal_mode = session != null and session.prologue_active and session.phase == "story"
	current_zone = zone_host.get_child(0)
	if current_zone.zone_id != "temple_hall":
		push_error("Prologue QA must spawn in temple_hall")
		return
	hero.position = current_zone.entry_position("WakeByFire")
	_setup_avatar()
	if formal_mode:
		story = Story.new(CHASE_STORY_PATH)
		if not story.load_error.is_empty():
			push_error(story.load_error)
			return
		story.begin()
		story.skip_cinematic()
		continue_button.pressed.connect(_advance_formal_dialogue)
		choice_buttons[0].pressed.connect(_choose_formal_dialogue.bind(0))
		choice_buttons[1].pressed.connect(_choose_formal_dialogue.bind(1))
		$Interface/FailurePanel/FailureContent/Retry.pressed.connect(_retry_roadside)
		_resume_formal_stage()
	_apply_zone_state()
	_update_interface()

func _process(delta: float) -> void:
	# Small, local QA visual cue. Formal combat/story VFX remain unchanged.
	if current_zone == null:
		return
	var flame := current_zone.get_node_or_null("Campfire/Flame") as Polygon2D
	if flame != null:
		fire_animation_time += delta
		flame.scale.y = 0.93 + 0.07 * sin(fire_animation_time * 8.3)
	if formal_mode and escort_follower.visible:
		var desired := hero.position + Vector2(-80, -18)
		escort_follow_position = escort_follow_position.lerp(desired, minf(1.0, delta * 3.5))
		escort_follower.position = escort_follow_position


func _setup_avatar() -> void:
	profile = load(ACTOR_PROFILE_PATH) as WuxiaActorAnimationProfile
	if profile == null or not profile.valid_profile():
		push_error("Prologue QA requires the registered Shen Changfeng actor atlas")
		return
	avatar.texture = profile.atlas
	avatar.hframes = profile.columns
	avatar.vframes = profile.rows
	avatar.offset = profile.feet_offset
	var idle := profile.clip_for("idle")
	var frame_id := int(idle.frames[0]) if idle != null and not idle.frames.is_empty() else 0
	avatar.frame = frame_id
	VisualScale.fit(avatar, profile.actor_scale, CombatScale.actor_height_pixels(),
		profile.feet_adjust, frame_id, profile.auto_fit_height)
	# Match the 170px exploration height used by current four-area map QA.
	avatar.scale *= 170.0 / CombatScale.actor_height_pixels()

func _physics_process(delta: float) -> void:
	if current_zone == null:
		return
	if formal_mode and (dialogue_panel.visible or failure_panel.visible):
		_animate_actor(Vector2.ZERO, delta)
		return
	var movement := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up"))
	movement.x += float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	movement.y += float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	movement = movement.normalized()
	var target: Vector2 = hero.position + movement * MOVE_SPEED * delta
	if current_zone.permits_foot(Vector2(target.x, hero.position.y)):
		hero.position.x = target.x
	if current_zone.permits_foot(Vector2(hero.position.x, target.y)):
		hero.position.y = target.y
	_animate_actor(movement, delta)
	_update_interface()

func _animate_actor(movement: Vector2, delta: float) -> void:
	if profile == null:
		return
	var moving := movement.length_squared() > 0.01
	var clip := profile.clip_for("move" if moving else "idle")
	if clip == null or clip.frames.is_empty():
		return
	animation_time = animation_time + delta if moving else 0.0
	avatar.frame = int(clip.frames[int(floor(animation_time * clip.loop_fps)) % clip.frames.size()])
	if absf(movement.x) > 0.05:
		avatar.flip_h = movement.x < 0.0

func _closest_marker(container_name: String) -> Marker2D:
	var container: Node2D = current_zone.get_node(container_name)
	var closest: Marker2D
	var distance := INF
	for marker in container.get_children():
		if marker is Marker2D:
			var candidate: float = hero.position.distance_to(marker.position)
			if candidate <= marker.interaction_radius and candidate < distance:
				closest = marker
				distance = candidate
	return closest

func interact() -> bool:
	if formal_mode:
		return _interact_formal()
	var landmark: Marker2D = _closest_marker("Landmarks")
	if landmark != null and not progress.discovered_landmarks.has(landmark.landmark_id):
		progress.discover(landmark.landmark_id)
		match landmark.landmark_id:
			"campfire":
				notice = "篝火尚暖，破瓦外的秋雨仍未停。"
			"guardian_statue":
				notice = "断臂金刚像静坐在阴影里，佛前尽是旧尘。"
			_:
				notice = "已经查看：" + landmark.hint + "。回到破庙看看。"
		_update_interface()
		return true
	var gate: Marker2D = _closest_marker("Exits")
	if gate != null:
		return follow_portal(gate.name)
	return false

func follow_portal(portal_name: String) -> bool:
	if formal_mode and (dialogue_panel.visible or failure_panel.visible):
		return false
	var gate: Marker2D = current_zone.get_node_or_null("Exits/" + portal_name) as Marker2D
	if gate == null or hero.position.distance_to(gate.position) > gate.interaction_radius:
		return false
	if not ZONE_SCENES.has(gate.target_zone_id):
		return false
	var next_zone: Node2D = ZONE_SCENES[gate.target_zone_id].instantiate()
	var entry: Vector2 = next_zone.entry_position(gate.target_entry_id)
	if entry == Vector2.INF or not next_zone.permits_foot(entry):
		next_zone.free()
		push_error("Prologue portal has missing or blocked entry: " + portal_name)
		return false
	var previous_id: String = current_zone.zone_id
	if previous_id == "temple_hall" and not formal_mode:
		progress.on_leave_hall()
	var old_zone: Node2D = current_zone
	zone_host.remove_child(old_zone)
	old_zone.queue_free()
	zone_host.add_child(next_zone)
	current_zone = next_zone
	hero.position = entry
	if not formal_mode and next_zone.zone_id == "broken_bridge":
		progress.discover("broken_bridge")
	if formal_mode:
		_on_formal_portal(previous_id, next_zone.zone_id)
	elif next_zone.zone_id == "temple_hall" and progress.on_enter_hall(previous_id):
		notice = "庙里传来脚步声——两名鬼面刀卫已经闯入！"
	else:
		notice = ""
	_apply_zone_state()
	_update_interface()
	return true

func _apply_zone_state() -> void:
	var enemies := current_zone.get_node_or_null("AmbushActors")
	if enemies != null:
		enemies.visible = not formal_mode and progress.ambush_started
	# The same safe first-room becomes an uneasy scene on the explored return.
	for part in ["Flame", "GlowingEmbers", "FireLight"]:
		var fire_part := current_zone.get_node_or_null("Campfire/" + part) as CanvasItem
		if fire_part != null:
			var opacity := 1.0
			if progress.ambush_started and not formal_mode:
				opacity = 0.22 if part == "FireLight" else 0.38
			var tint: Color = fire_part.modulate
			tint.a = opacity
			fire_part.modulate = tint
	current_zone.walkable.visible = show_navigation
	# Centered 1600×1000 blockouts retain the same world scale across zones.
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 1600
	camera.limit_bottom = 1000

func _update_interface() -> void:
	if current_zone == null:
		return
	if formal_mode:
		_update_formal_interface()
		return
	var phase := "初醒·殿内安全"
	if progress.ambush_started:
		phase = "返庙·敌人现身"
	elif progress.explored_deep_outside:
		phase = "已发现线索·可以返庙"
	elif progress.left_temple:
		phase = "外出探索中"
	var action := "走近门口按 E 进入相邻地图"
	var landmark: Marker2D = _closest_marker("Landmarks")
	if landmark != null and not progress.discovered_landmarks.has(landmark.landmark_id):
		action = "E · " + landmark.hint
	else:
		var gate: Marker2D = _closest_marker("Exits")
		if gate != null:
			action = "E · " + gate.hint
	status.text = "序幕原生场景 QA · %s · %s\nWASD/方向键移动 · %s · F3 可走区 · Esc 菜单\n%s" % [
		current_zone.zone_title, phase, action, notice]

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if formal_mode and failure_panel.visible:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_E]:
			_retry_roadside()
		get_viewport().set_input_as_handled()
		return
	if formal_mode and dialogue_panel.visible:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_SPACE]:
			if story.available_choices(session.flags).is_empty():
				_advance_formal_dialogue()
		elif event.keycode in [KEY_1, KEY_2]:
			_choose_formal_dialogue(event.keycode - KEY_1)
		get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_E:
			interact()
		KEY_F3:
			show_navigation = not show_navigation
			_apply_zone_state()
		KEY_ESCAPE:
			if formal_mode:
				session.return_to_menu()
			get_tree().call_deferred("change_scene_to_file", "res://opening.tscn")

## Formal narrative controller. The isolated prologue_progress QA state above
## deliberately remains untouched, so editor map inspections stay repeatable.
func _resume_formal_stage() -> void:
	match session.prologue_stage:
		"wave1_cleared":
			_teleport_formal("temple_courtyard", "FromHall")
			notice = "你挡住了第一波探子。搀着严守诚冲向官道。"
		"wave2_cleared":
			_teleport_formal("mountain_road", "FromCourtyard")
			notice = "第二波追兵已被击退。断桥后或许还有生路。"
		"lookout_cleared":
			_teleport_formal("broken_bridge", "FromRoad")
			notice = "残卷的洞察帮你摆脱哨探。快沿溪谷离开。"
		"healing", "wave1_ready":
			_teleport_formal("temple_hall", "WakeByFire")
		"wave2_ready":
			_teleport_formal("mountain_road", "FromCourtyard")
		"lookout_ready":
			_teleport_formal("broken_bridge", "FromRoad")
		"roadside_retry":
			_teleport_formal("mountain_road", "FromCourtyard")
			_start_formal_dialogue("roadside_open", "roadside_choice")
		_:
			notice = "雨夜暂歇。你还要将一封家书送往平江府。可到官道看看去路。"
	_update_escort_visibility()

func _teleport_formal(zone_id: String, entry_name: String) -> void:
	if not ZONE_SCENES.has(zone_id):
		return
	var next_zone: Node2D = ZONE_SCENES[zone_id].instantiate()
	var entry: Vector2 = next_zone.entry_position(entry_name)
	if entry == Vector2.INF or not next_zone.permits_foot(entry):
		push_error("Invalid formal prologue spawn: " + zone_id + "/" + entry_name)
		next_zone.free()
		return
	zone_host.remove_child(current_zone)
	current_zone.queue_free()
	zone_host.add_child(next_zone)
	current_zone = next_zone
	hero.position = entry
	_apply_zone_state()

func _update_escort_visibility() -> void:
	if not formal_mode:
		return
	escort_follower.visible = session.prologue_stage in [
		"healing", "wave1_ready", "wave1_battle", "wave1_cleared",
		"wave2_ready", "wave2_battle", "wave2_cleared"]
	if escort_follower.visible:
		escort_follow_position = hero.position + Vector2(-80, -18)
		escort_follower.position = escort_follow_position

func _interact_formal() -> bool:
	if dialogue_panel.visible or failure_panel.visible:
		return false
	var landmark: Marker2D = _closest_marker("Landmarks")
	if landmark != null:
		if landmark.landmark_id == "cart_traces" and session.prologue_stage in ["explore", "roadside_retry"]:
			return _start_formal_dialogue("roadside_open", "roadside_choice")
		if landmark.landmark_id == "campfire" and session.prologue_stage == "healing":
			return _start_formal_dialogue("healing_open", "heal")
		if not progress.discovered_landmarks.has(landmark.landmark_id):
			progress.discover(landmark.landmark_id)
			notice = "查看了" + landmark.hint + "。"
			_update_interface()
			return true
	if current_zone.zone_id == "broken_bridge":
		var ferry := current_zone.get_node("StoryAnchors/FutureFerryTrailNotConnected") as Marker2D
		if hero.position.distance_to(ferry.position) <= ferry.interaction_radius:
			if session.prologue_stage == "lookout_ready":
				return _start_formal_dialogue("lookout_open", "lookout")
			if session.prologue_stage == "lookout_cleared":
				return _start_formal_dialogue("escape_open", "escape")
	var gate: Marker2D = _closest_marker("Exits")
	if gate != null:
		return follow_portal(gate.name)
	return false

func _on_formal_portal(previous_id: String, new_id: String) -> void:
	if session.prologue_stage == "wave1_ready" and previous_id == "temple_hall" and new_id == "temple_courtyard":
		_start_formal_dialogue("wave1_open", "wave1")
	elif session.prologue_stage == "wave1_cleared" and previous_id == "temple_courtyard" and new_id == "mountain_road":
		if session.set_prologue_stage("wave2_ready"):
			_start_formal_dialogue("wave2_open", "wave2")
	elif session.prologue_stage == "wave2_cleared" and previous_id == "mountain_road" and new_id == "broken_bridge":
		_start_formal_dialogue("handover_open", "handover")
	_update_escort_visibility()

func _start_formal_dialogue(node_id: String, outcome: String) -> bool:
	if story == null or not story.interact_at(node_id):
		return false
	dialogue_outcome = outcome
	_apply_formal_events()
	_render_formal_dialogue()
	return true

func _apply_formal_events() -> void:
	if not session.apply_story_events(story.take_events()):
		push_error("Could not apply prologue story events")

func _render_formal_dialogue() -> void:
	dialogue_panel.visible = story.phase == "dialogue"
	if not dialogue_panel.visible:
		_finish_formal_dialogue()
		return
	var entry: Dictionary = story.current_dialogue()
	dialogue_speaker.text = str(entry.get("speaker", ""))
	dialogue_body.text = str(entry.get("text", ""))
	var choices: Array = story.available_choices(session.flags)
	continue_button.visible = choices.is_empty()
	for i in choice_buttons.size():
		choice_buttons[i].visible = i < choices.size()
		if i < choices.size():
			choice_buttons[i].text = "%d · %s" % [i + 1, str(choices[i].get("text", ""))]
	_update_interface()

func _advance_formal_dialogue() -> void:
	if not dialogue_panel.visible or not story.advance_dialogue(session.flags):
		return
	_apply_formal_events()
	_render_formal_dialogue()

func _choose_formal_dialogue(index: int) -> void:
	if not dialogue_panel.visible:
		return
	var entry_id: String = story.dialogue_id
	if not story.choose(index, session.flags):
		return
	session.record_choice(entry_id, index)
	_apply_formal_events()
	_render_formal_dialogue()

func _finish_formal_dialogue() -> void:
	var finished: String = dialogue_outcome
	dialogue_outcome = ""
	match finished:
		"roadside_choice":
			if bool(session.flags.get("helped_escort", false)):
				if session.set_prologue_stage("healing"):
					_teleport_formal("temple_hall", "WakeByFire")
					notice = "严守诚靠坐在篝火旁。走近火堆按 E 替他止血。"
			else:
				session.set_prologue_stage("failure")
				failure_panel.visible = true
		"heal":
			if session.set_prologue_stage("wave1_ready"):
				notice = "有敌人寻到庙外！由殿门出去迎战，别让他们伤到严守诚。"
		"wave1", "wave2", "lookout":
			if not session.begin_prologue_wave():
				push_error("Prologue encounter unavailable at stage " + session.prologue_stage)
			else:
				get_tree().call_deferred("change_scene_to_file", session.scene_for("battle"))
		"handover":
			if session.set_prologue_stage("lookout_ready"):
				notice = "严守诚留在明路牵制追兵。你带着残卷去断桥东侧的溪谷入口。"
		"escape":
			if not session.flags.get("prologue_escaped", false):
				push_error("Prologue ending requires escape flag")
			elif session.set_prologue_stage("escaped"):
				story.complete_if_ready(session.flags)
				# Pingjiang is the next existing native free-roam destination.
				get_tree().call_deferred("change_scene_to_file", "res://scenes/pingjiang_exploration.tscn")
	_update_escort_visibility()
	_update_interface()

func _retry_roadside() -> void:
	if not session.set_prologue_stage("roadside_retry"):
		return
	failure_panel.visible = false
	session.flags.erase("helped_escort")
	_teleport_formal("mountain_road", "FromCourtyard")
	_start_formal_dialogue("roadside_open", "roadside_choice")

func _update_formal_interface() -> void:
	var stage_text: Dictionary = {
		"explore": "破庙初醒", "roadside_retry": "官道抉择", "healing": "篝火疗伤",
		"wave1_ready": "庙外追兵", "wave1_cleared": "护送逃亡",
		"wave2_ready": "山道截击", "wave2_cleared": "奔向断桥",
		"lookout_ready": "残卷相托", "lookout_cleared": "溪谷脱险"}
	var action := "靠近出口按 E 换区"
	var landmark: Marker2D = _closest_marker("Landmarks")
	if landmark != null:
		action = "E · " + landmark.hint
	if current_zone.zone_id == "broken_bridge":
		var ferry := current_zone.get_node("StoryAnchors/FutureFerryTrailNotConnected") as Marker2D
		if hero.position.distance_to(ferry.position) <= ferry.interaction_radius:
			action = "E · " + ferry.hint
	var gate: Marker2D = _closest_marker("Exits")
	if gate != null and landmark == null:
		action = "E · " + gate.hint
	status.text = "暮秋荒庙 · %s · %s\nWASD/方向键移动 · %s · F3 可走区 · Esc 返回菜单\n%s" % [
		current_zone.zone_title, str(stage_text.get(session.prologue_stage, "雨夜逃亡")), action, notice]
