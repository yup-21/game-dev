extends Node2D
## Native-scene prologue blockout: hall spawn -> outside investigation -> return ambush.
## All zone silhouettes, foot polygons, obstacles, exits and spawn markers are
## editable inside scenes/prologue/zones/*.tscn in Godot's 2D editor.

const Progress = preload("res://scripts/prologue/prologue_progress.gd")
const CombatScale = preload("res://scripts/combat_scale.gd")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")
const ACTOR_PROFILE_PATH := "res://data/native/animations/shen_changfeng.tres"
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

var current_zone: Node2D
var progress = Progress.new()
var profile: WuxiaActorAnimationProfile
var animation_time: float = 0.0
var show_navigation: bool = false
var notice: String = ""
var fire_animation_time: float = 0.0

func _ready() -> void:
	current_zone = zone_host.get_child(0)
	if current_zone.zone_id != "temple_hall":
		push_error("Prologue QA must spawn in temple_hall")
		return
	hero.position = current_zone.entry_position("WakeByFire")
	_setup_avatar()
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
	if previous_id == "temple_hall":
		progress.on_leave_hall()
	var old_zone: Node2D = current_zone
	zone_host.remove_child(old_zone)
	old_zone.queue_free()
	zone_host.add_child(next_zone)
	current_zone = next_zone
	hero.position = entry
	if next_zone.zone_id == "broken_bridge":
		progress.discover("broken_bridge")
	if next_zone.zone_id == "temple_hall" and progress.on_enter_hall(previous_id):
		notice = "庙里传来脚步声——两名鬼面刀卫已经闯入！"
	else:
		notice = ""
	_apply_zone_state()
	_update_interface()
	return true

func _apply_zone_state() -> void:
	var enemies := current_zone.get_node_or_null("AmbushActors")
	if enemies != null:
		enemies.visible = progress.ambush_started
	# The same safe first-room becomes an uneasy scene on the explored return.
	for part in ["Flame", "GlowingEmbers", "FireLight"]:
		var fire_part := current_zone.get_node_or_null("Campfire/" + part) as CanvasItem
		if fire_part != null:
			var opacity := 1.0
			if progress.ambush_started:
				opacity = 0.22 if part == "FireLight" else 0.38
			fire_part.modulate.a = opacity
	current_zone.walkable.visible = show_navigation
	# Centered 1600×1000 blockouts retain the same world scale across zones.
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 1600
	camera.limit_bottom = 1000

func _update_interface() -> void:
	if current_zone == null:
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
	match event.keycode:
		KEY_E:
			interact()
		KEY_F3:
			show_navigation = not show_navigation
			_apply_zone_state()
		KEY_ESCAPE:
			get_tree().call_deferred("change_scene_to_file", "res://opening.tscn")
