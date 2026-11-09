extends Node2D
## Native prologue: the same editable four-zone geography serves isolated QA
## and the formal rescue/chase story. Visual-only chase actors are scene nodes;
## encounters and outcomes remain the authority of the native story resources.

const Progress = preload("res://scripts/prologue/prologue_progress.gd")
const Story = preload("res://scripts/opening_story.gd")
const CombatScale = preload("res://scripts/combat_scale.gd")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")
const ACTOR_PROFILE_PATH := "res://data/native/animations/shen_changfeng.tres"
const CHASE_STORY_PATH := "res://data/native/stories/prologue_chase_story.tres"
const ELDER_RESTING_POSE := preload("res://assets/imported/characters/escort_elder/story-poses/injured.png")
const ELDER_STANDING_POSE := preload("res://assets/imported/characters/escort_elder/portraits/portrait.png")
const MOVE_SPEED := 260.0
const ESCORT_PLAYER_SPEED := 180.0
const ESCORT_WAIT_SPEED := 88.0
const ESCORT_FOLLOW_SPEED := 135.0
const ESCORT_MAX_SEPARATION := 150.0
const YAN_DECOY_DURATION := 3.0
const CAMERA_DEFAULT_ZOOM := Vector2(1.15, 1.15)
const INSIGHT_GLOW_DURATION := 1.2
const ZONE_SCENES := {
	"temple_hall": preload("res://scenes/prologue/zones/temple_hall.tscn"),
	"temple_courtyard": preload("res://scenes/prologue/zones/temple_courtyard.tscn"),
	"mountain_road": preload("res://scenes/prologue/zones/mountain_road.tscn"),
	"broken_bridge": preload("res://scenes/prologue/zones/broken_bridge.tscn")
}

@export_group("Cinematic Tuning")
@export var enable_cinematic_fx: bool = true
@export_range(1.0, 1.4, 0.01) var handover_zoom: float = 1.23
@export_range(1.0, 1.4, 0.01) var farewell_zoom: float = 1.29
@export_range(0.0, 30.0, 1.0) var scout_advance_pixels: float = 18.0
@export_range(0.0, 60.0, 1.0) var search_torch_advance_pixels: float = 35.0
@export_range(0.0, 0.25, 0.01) var insight_glow_alpha: float = 0.16

@onready var zone_host: Node2D = $CurrentZone
@onready var hero: Node2D = $ShenChangfeng
@onready var camera: Camera2D = $ShenChangfeng/Camera2D
@onready var screen_tint: ColorRect = $CinematicOverlay/ScreenTint
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
var escort_travel_direction: Vector2 = Vector2.RIGHT
var escort_stride_time: float = 0.0
var yan_decoy_time: float = -1.0
var pursuit_motion_time: float = 0.0
var torch_approach_time: float = 0.0
var camera_impact_time: float = 0.0
var camera_impact_strength: float = 0.0
var insight_glow_time: float = 0.0
var cinematic_time: float = 0.0

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
	# Visual-only scene feedback. Combat and story resources still own results.
	if current_zone == null:
		return
	cinematic_time += delta
	var flame := current_zone.get_node_or_null("Campfire/Flame") as Polygon2D
	if flame != null:
		fire_animation_time += delta
		flame.scale.y = 0.93 + 0.07 * sin(fire_animation_time * 8.3)
	if _escort_is_travelling():
		var desired: Vector2 = hero.position - escort_travel_direction * 76.0 + Vector2(0, -8)
		var previous: Vector2 = escort_follow_position
		escort_follow_position = escort_follow_position.move_toward(desired, ESCORT_FOLLOW_SPEED * delta)
		var walking := previous.distance_to(escort_follow_position) > 0.1
		if walking:
			escort_stride_time += delta * 5.5
		escort_follower.position = escort_follow_position + Vector2(0, -1.6 * absf(sin(escort_stride_time)) if walking else 0.0)
		escort_follower.rotation = deg_to_rad(-2.0 + (0.9 * sin(escort_stride_time) if walking else 0.0))
		if absf(escort_travel_direction.x) > 0.25:
			escort_follower.flip_h = escort_travel_direction.x < 0.0
	_update_yan_decoy(delta)
	_update_pursuer_visuals(delta)
	_update_cinematic_camera(delta)
	var torches := current_zone.get_node_or_null("SearchPartyTorches") as Node2D
	if enable_cinematic_fx and torches != null and torches.visible:
		fire_animation_time += delta
		for torch in torches.get_children():
			if torch is Polygon2D:
				torch.modulate.a = 0.79 + 0.14 * sin(fire_animation_time * 6.0 + float(torch.get_index()))

func _update_pursuer_visuals(delta: float) -> void:
	if not formal_mode or not enable_cinematic_fx:
		return
	var pursuers := current_zone.get_node_or_null("ChaseActors") as Node2D
	if pursuers != null and pursuers.visible:
		pursuit_motion_time += delta
		for actor in pursuers.get_children():
			if not actor is Node2D:
				continue
			if not actor.has_meta("authored_origin"):
				actor.set_meta("authored_origin", actor.position)
			var origin: Vector2 = actor.get_meta("authored_origin")
			var advance := (hero.position - origin).normalized() * minf(scout_advance_pixels, pursuit_motion_time * 7.0)
			actor.position = origin + advance + Vector2(0, sin(pursuit_motion_time * 5.4 + float(actor.get_index())) * 2.0)
	var torches := current_zone.get_node_or_null("SearchPartyTorches") as Node2D
	if torches != null and torches.visible:
		torch_approach_time += delta
		torches.position = Vector2(minf(search_torch_advance_pixels, torch_approach_time * 8.0),
			sin(torch_approach_time * 1.9) * 1.5)

func _update_cinematic_camera(delta: float) -> void:
	if not enable_cinematic_fx:
		camera.offset = Vector2.ZERO
		camera.zoom = CAMERA_DEFAULT_ZOOM
		screen_tint.color = Color(0.06, 0.11, 0.18, 0.0)
		camera_impact_time = 0.0
		insight_glow_time = 0.0
		return
	var focus := Vector2.ZERO
	var target_zoom := CAMERA_DEFAULT_ZOOM
	var veil_alpha := 0.0
	if formal_mode and current_zone.zone_id == "broken_bridge":
		if dialogue_panel.visible and dialogue_outcome == "handover":
			focus = Vector2(-60, -18)
			target_zoom = Vector2.ONE * handover_zoom
			veil_alpha = 0.075
		elif yan_decoy_time >= 0.0:
			var focus_ratio := sin(PI * minf(1.0, yan_decoy_time / YAN_DECOY_DURATION))
			focus = Vector2(-112, -20) * focus_ratio
			target_zoom = CAMERA_DEFAULT_ZOOM.lerp(Vector2.ONE * farewell_zoom, focus_ratio)
			veil_alpha = 0.07 + 0.09 * focus_ratio
	var tint := Color(0.06, 0.11, 0.18, veil_alpha)
	if insight_glow_time > 0.0:
		insight_glow_time = maxf(0.0, insight_glow_time - delta)
		var phase := 1.0 - insight_glow_time / INSIGHT_GLOW_DURATION
		tint = Color(0.86, 0.63, 0.25, insight_glow_alpha * sin(PI * phase))
	if camera_impact_time > 0.0:
		camera_impact_time = maxf(0.0, camera_impact_time - delta)
		var strength := camera_impact_strength * camera_impact_time / 0.55
		focus += Vector2(sin(cinematic_time * 41.0), cos(cinematic_time * 37.0)) * strength
	# Camera2D.offset is not clamped by the normal camera limits. Avoid revealing
	# empty space beyond the 1600×1000 painted scene during a close-up or shake.
	var half_view: Vector2 = get_viewport_rect().size / (target_zoom * 2.0)
	var center := Vector2(
		clampf(hero.position.x, half_view.x, 1600.0 - half_view.x),
		clampf(hero.position.y, half_view.y, 1000.0 - half_view.y))
	focus.x = clampf(focus.x, half_view.x - center.x, 1600.0 - half_view.x - center.x)
	focus.y = clampf(focus.y, half_view.y - center.y, 1000.0 - half_view.y - center.y)
	camera.offset = camera.offset.lerp(focus, minf(1.0, delta * 4.2))
	camera.zoom = camera.zoom.lerp(target_zoom, minf(1.0, delta * 3.4))
	screen_tint.color = Color(tint.r, tint.g, tint.b,
		lerpf(screen_tint.color.a, tint.a, minf(1.0, delta * 7.5)))

func _reset_cinematic_state() -> void:
	camera.offset = Vector2.ZERO
	camera.zoom = CAMERA_DEFAULT_ZOOM
	screen_tint.color = Color(0.06, 0.11, 0.18, 0.0)
	camera_impact_time = 0.0
	insight_glow_time = 0.0
	pursuit_motion_time = 0.0
	torch_approach_time = 0.0
	yan_decoy_time = -1.0


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
	var speed := MOVE_SPEED
	if _escort_is_travelling():
		if movement.length_squared() > 0.01:
			escort_travel_direction = movement
		speed = ESCORT_WAIT_SPEED if hero.position.distance_to(escort_follow_position) > ESCORT_MAX_SEPARATION else ESCORT_PLAYER_SPEED
	var target: Vector2 = hero.position + movement * speed * delta
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
		_reset_cinematic_state()
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
	# Named native anchors preview the increasing pursuer count. They never
	# replace or influence the BattleModel's encounter combatants.
	var chase_actors := current_zone.get_node_or_null("ChaseActors") as Node2D
	if chase_actors != null:
		chase_actors.visible = formal_mode and (
			(current_zone.zone_id == "temple_courtyard" and session.prologue_stage == "wave1_ready")
			or (current_zone.zone_id == "mountain_road" and session.prologue_stage == "wave2_ready"))
	var search_torches := current_zone.get_node_or_null("SearchPartyTorches") as Node2D
	if search_torches != null:
		search_torches.visible = formal_mode and session.prologue_stage in [
			"wave2_cleared", "lookout_ready", "lookout_battle", "lookout_cleared"]
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
	# All 1600×1000 native zones retain the same world scale.
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
	_reset_cinematic_state()
	_update_escort_visibility()
	_apply_zone_state()

func _escort_is_travelling() -> bool:
	return formal_mode and escort_follower.visible and session.prologue_stage in [
		"wave1_ready", "wave1_cleared", "wave2_ready", "wave2_cleared"]

func _update_escort_visibility() -> void:
	if not formal_mode:
		return
	escort_follower.visible = session.prologue_stage in [
		"healing", "wave1_ready", "wave1_battle", "wave1_cleared",
		"wave2_ready", "wave2_battle", "wave2_cleared"]
	if escort_follower.visible:
		var resting: bool = session.prologue_stage == "healing"
		escort_follower.texture = ELDER_RESTING_POSE if resting else ELDER_STANDING_POSE
		# The sprite's world origin is at the feet, not the center of the portrait canvas.
		escort_follower.offset = Vector2(0, -escort_follower.texture.get_height() * 0.5)
		escort_follower.rotation = 0.0
		escort_follower.flip_h = false
		if resting:
			var rest := current_zone.get_node_or_null("StoryAnchors/YanRestByFire") as Marker2D
			escort_follow_position = rest.position if rest != null else hero.position + Vector2(-100, 12)
		elif current_zone.zone_id == "broken_bridge":
			# During the handover Yan stands at the authored diversion route's start.
			var route := current_zone.get_node_or_null("YanDecoyRoute") as Path2D
			escort_follow_position = route.curve.get_point_position(0) if route != null else hero.position + Vector2(-76, 0)
		else:
			escort_follow_position = hero.position - escort_travel_direction * 76.0 + Vector2(0, -8)
		escort_follower.position = escort_follow_position

func _start_yan_decoy() -> void:
	if current_zone.zone_id != "broken_bridge":
		return
	var route := current_zone.get_node_or_null("YanDecoyRoute") as Path2D
	if route == null or route.curve == null or route.curve.point_count < 2:
		push_warning("Broken bridge has no editable Yan diversion route")
		return
	var traveler := route.get_node("Traveler") as PathFollow2D
	traveler.progress_ratio = 0.0
	traveler.modulate.a = 1.0
	route.visible = true
	yan_decoy_time = 0.0

func _update_yan_decoy(delta: float) -> void:
	if yan_decoy_time < 0.0 or current_zone.zone_id != "broken_bridge":
		return
	var route := current_zone.get_node_or_null("YanDecoyRoute") as Path2D
	if route == null or not route.visible:
		yan_decoy_time = -1.0
		return
	yan_decoy_time += delta
	var ratio := minf(1.0, yan_decoy_time / YAN_DECOY_DURATION)
	var traveler := route.get_node("Traveler") as PathFollow2D
	traveler.progress_ratio = ratio
	traveler.modulate.a = clampf((1.0 - ratio) * 4.0, 0.0, 1.0)
	if ratio >= 1.0:
		route.visible = false
		yan_decoy_time = -1.0

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
	match node_id:
		"wave1_open", "wave2_open":
			camera_impact_time = 0.55
			camera_impact_strength = 7.0 if node_id == "wave1_open" else 12.0
		"lookout_open":
			insight_glow_time = INSIGHT_GLOW_DURATION
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
				notice = "严守诚拿着断旗折回明路，走向搜山火光。你带着残卷往断桥东侧的溪谷走。"
		"escape":
			if not session.flags.get("prologue_escaped", false):
				push_error("Prologue ending requires escape flag")
			elif session.set_prologue_stage("escaped"):
				story.complete_if_ready(session.flags)
				# Pingjiang is the next existing native free-roam destination.
				get_tree().call_deferred("change_scene_to_file", "res://scenes/pingjiang_exploration.tscn")
	_update_escort_visibility()
	if finished == "handover" and session.prologue_stage == "lookout_ready":
		_start_yan_decoy()
	_apply_zone_state()
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
