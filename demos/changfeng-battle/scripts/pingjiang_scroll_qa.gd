extends Node2D
## Pingjiang zone-transition QA: ONE loaded native map at a time.
## A/B are horizontal maps, C is an independent 1600x4000 vertical map.
## Crossing a native zone_exit marker replaces the active map and relocates
## the actor to the destination map's named spawn marker.
const ViewportShift = preload("res://scripts/world_viewport_offset.gd")
const CombatScale = preload("res://scripts/combat_scale.gd")
const MapBake = preload("res://scripts/map_bake.gd")
const ZoneConnection = preload("res://scripts/map_zone_connection.gd")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")
const ACTOR_PROFILE_PATH := "res://data/native/animations/shen_changfeng.tres"
const MOVE_SPEED := 265.0
const ZONES := {
    "pingjiang_long_street_qa": {
        "name": "主干道·临河水市",
        "map": "res://data/maps/pingjiang_long_street_qa.tres"},
    "pingjiang_east_market_qa": {
        "name": "东市·续接街区",
        "map": "res://data/maps/pingjiang_east_market_qa.tres"},
    "pingjiang_north_lane_qa": {
        "name": "北街·南北长巷",
        "map": "res://data/maps/pingjiang_north_lane_qa.tres"}
}
const SIDE_NAMES := {"east": "东", "west": "西", "north": "北", "south": "南"}

@export var initial_zone_id: String = "pingjiang_long_street_qa"
var active_zone_id: String = ""
var transition_count: int = 0
var transition_cooldown: float = 0.0
var last_transition: String = "尚未跨区"
var bake
var stage: Node2D
var zone_visual: Node2D
var player: Node2D
var actor_sprite: Sprite2D
var actor_profile: WuxiaActorAnimationProfile
var status: Label
var debug_line: Line2D
var goal: Vector2 = Vector2.INF
var animation_time: float = 0.0
var last_screen_click: Vector2 = Vector2.ZERO
var last_world_click: Vector2 = Vector2.ZERO

func _ready() -> void:
    stage = Node2D.new()
    stage.name = "ScrollingWorld"
    add_child(stage)
    player = Node2D.new()
    player.name = "ShenChangfeng"
    stage.add_child(player)
    var foot := Polygon2D.new()
    foot.name = "Footprint24px"
    foot.color = Color(0.85, 0.73, 0.31, 0.48)
    foot.polygon = PackedVector2Array([
        Vector2(-24, 0), Vector2(-16, -10), Vector2(16, -10),
        Vector2(24, 0), Vector2(16, 10), Vector2(-16, 10)])
    player.add_child(foot)
    _load_actor_sprite()
    var nameplate := Label.new()
    nameplate.text = "沈长风"
    nameplate.position = Vector2(-70, -248)
    nameplate.size = Vector2(140, 28)
    nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    nameplate.add_theme_color_override("font_color", Color(0.17, 0.26, 0.28))
    nameplate.add_theme_font_size_override("font_size", 19)
    player.add_child(nameplate)
    var hud := CanvasLayer.new()
    hud.layer = 10
    add_child(hud)
    status = Label.new()
    status.position = Vector2(30, 20)
    status.add_theme_font_size_override("font_size", 24)
    status.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
    status.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.03, 0.95))
    status.add_theme_constant_override("shadow_offset_x", 2)
    status.add_theme_constant_override("shadow_offset_y", 2)
    hud.add_child(status)
    if not _enter_zone(initial_zone_id, "player_start"):
        push_error("Pingjiang QA cannot load initial zone: " + initial_zone_id)

func _enter_zone(zone_id: String, entry_id: String, prepared_bake = null) -> bool:
    if not ZONES.has(zone_id):
        return false
    var new_bake = prepared_bake
    if new_bake == null:
        new_bake = MapBake.new(str(ZONES[zone_id]["map"]))
    if not new_bake.error.is_empty() or new_bake.id != zone_id:
        push_error("Native zone map missing/invalid: " + zone_id)
        return false
    var entry: Dictionary = new_bake.markers.get(entry_id, {})
    var spawn: Vector2 = new_bake.marker_position(entry_id)
    if str(entry.get("kind", "")) != "spawn" or spawn == Vector2.INF or not new_bake.is_walkable_point(
            spawn, CombatScale.footprint_radius_pixels()):
        push_error("Invalid target zone entry: " + zone_id + "/" + entry_id)
        return false
    var art: WuxiaSceneArtProfile = new_bake.scene_art
    if art == null or not art.valid_for(Vector2i(new_bake.viewport_size)):
        push_error("Zone art layers mismatch: " + zone_id)
        return false
    var next_visual := Node2D.new()
    next_visual.name = "Region_" + zone_id
    _add_layer(next_visual, "Background", art.background, new_bake.viewport_size, -100)
    _add_layer(next_visual, "Ground", art.ground, new_bake.viewport_size, -90)
    _add_layer(next_visual, "Foreground", art.foreground, new_bake.viewport_size, 110)
    var boundary := Line2D.new()
    boundary.name = "WalkableBoundary"
    boundary.points = new_bake.walkable_outline.duplicate()
    boundary.add_point(new_bake.walkable_outline[0])
    boundary.width = 5.0
    boundary.default_color = Color(0.10, 0.87, 0.44, 0.84)
    boundary.visible = debug_line.visible if debug_line != null else false
    boundary.z_index = 150
    next_visual.add_child(boundary)
    for exit_id in new_bake.markers_of_kind("zone_exit"):
        _add_connection_marker(next_visual, new_bake, exit_id)
    # Remove the old region root from the visible world BEFORE mounting the
    # new region. No stitched textures, shared global road or double rendering.
    if zone_visual != null:
        stage.remove_child(zone_visual)
        zone_visual.queue_free()
    stage.add_child(next_visual)
    zone_visual = next_visual
    debug_line = boundary
    bake = new_bake
    active_zone_id = zone_id
    player.position = spawn
    player.z_index = clampi(roundi(spawn.y / 20.0), 0, 100)
    goal = Vector2.INF
    _update_camera_and_status()
    return true

func _add_layer(parent: Node2D, name: String, texture: Texture2D,
        world_size: Vector2, order: int) -> void:
    var rect := TextureRect.new()
    rect.name = name
    rect.texture = texture
    rect.size = world_size
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_SCALE
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    rect.z_index = order
    parent.add_child(rect)

func _add_connection_marker(parent: Node2D, source_bake, exit_id: String) -> void:
    var marker: Dictionary = source_bake.markers[exit_id]
    var sign := Node2D.new()
    sign.name = "Exit_" + exit_id
    sign.position = source_bake.marker_position(exit_id)
    sign.z_index = 125
    parent.add_child(sign)
    var ring := Line2D.new()
    ring.width = 6.0
    ring.default_color = Color(0.15, 0.84, 0.65, 0.92)
    var radius: float = minf(float(marker.get("radius", 60.0)), 64.0)
    for i in range(33):
        ring.add_point(Vector2(radius, 0).rotated(TAU * float(i) / 32.0))
    sign.add_child(ring)
    var caption := Label.new()
    caption.position = Vector2(-160, -117)
    caption.size = Vector2(320, 46)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_color_override("font_color", Color(0.11, 0.32, 0.31))
    caption.add_theme_color_override("font_shadow_color", Color(0.96, 0.93, 0.77))
    caption.add_theme_constant_override("shadow_offset_x", 1)
    caption.add_theme_constant_override("shadow_offset_y", 1)
    caption.add_theme_font_size_override("font_size", 23)
    caption.text = "往%s · %s" % [
        str(SIDE_NAMES.get(marker.get("exit_side", ""), "下一站")),
        str(ZONES.get(str(marker.get("target_zone_id", "")), {}).get("name", "下一街区"))]
    sign.add_child(caption)

func _load_actor_sprite() -> void:
    actor_profile = load(ACTOR_PROFILE_PATH) as WuxiaActorAnimationProfile
    if actor_profile == null or not actor_profile.valid_profile():
        push_warning("Existing actor atlas unavailable; using 200px test silhouette")
        var silhouette := Polygon2D.new()
        silhouette.color = Color(0.17, 0.34, 0.43)
        silhouette.polygon = PackedVector2Array([
            Vector2(-20, 0), Vector2(-28, -88), Vector2(-43, -137),
            Vector2(-28, -170), Vector2(-15, -176), Vector2(-18, -200),
            Vector2(18, -200), Vector2(15, -176), Vector2(28, -170),
            Vector2(43, -137), Vector2(28, -88), Vector2(20, 0)])
        player.add_child(silhouette)
        return
    actor_sprite = Sprite2D.new()
    actor_sprite.name = "ActionSprite"
    actor_sprite.texture = actor_profile.atlas
    actor_sprite.hframes = actor_profile.columns
    actor_sprite.vframes = actor_profile.rows
    actor_sprite.offset = actor_profile.feet_offset
    var idle := actor_profile.clip_for("idle")
    var reference := int(idle.frames[0]) if idle != null and not idle.frames.is_empty() else 0
    actor_sprite.frame = reference
    player.add_child(actor_sprite)
    VisualScale.fit(actor_sprite, actor_profile.actor_scale,
        CombatScale.actor_height_pixels(), actor_profile.feet_adjust, reference)

func _process(delta: float) -> void:
    if bake == null or player == null:
        return
    transition_cooldown = maxf(0.0, transition_cooldown - delta)
    var direction := Vector2(
        Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
        Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up"))
    direction.x += float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
    direction.y += float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
    if direction.length_squared() > 0.01:
        goal = Vector2.INF
        direction = direction.normalized()
    elif goal != Vector2.INF:
        var remaining: Vector2 = goal - player.position
        if remaining.length() <= 3.0:
            goal = Vector2.INF
        else:
            direction = remaining.normalized()
    var step: float = MOVE_SPEED * delta
    if goal != Vector2.INF:
        step = minf(step, player.position.distance_to(goal))
    var candidate: Vector2 = player.position + direction * step
    var radius := CombatScale.footprint_radius_pixels()
    if bake.is_walkable_point(Vector2(candidate.x, player.position.y), radius):
        player.position.x = candidate.x
    if bake.is_walkable_point(Vector2(player.position.x, candidate.y), radius):
        player.position.y = candidate.y
    player.z_index = clampi(roundi(player.position.y / 20.0), 0, 100)
    if _try_zone_exit():
        _animate_actor(Vector2.ZERO, delta)
        return
    _animate_actor(direction, delta)
    _update_camera_and_status()

func _try_zone_exit() -> bool:
    if transition_cooldown > 0.0 or bake == null:
        return false
    for exit_id in bake.markers_of_kind("zone_exit"):
        var marker: Dictionary = bake.markers[exit_id]
        if player.position.distance_to(bake.marker_position(exit_id)) <= float(marker.get("radius", 0.0)):
            return _follow_zone_exit(exit_id)
    return false

func _follow_zone_exit(exit_id: String) -> bool:
    if bake == null or not bake.markers.has(exit_id):
        return false
    var exit_marker: Dictionary = bake.markers[exit_id]
    var target_id := str(exit_marker.get("target_zone_id", ""))
    if not ZONES.has(target_id):
        return false
    var target_bake = MapBake.new(str(ZONES[target_id]["map"]))
    var route: Dictionary = ZoneConnection.resolve_exit(bake, exit_id, target_bake,
        CombatScale.footprint_radius_pixels())
    if route.is_empty():
        return false
    var previous_zone: String = active_zone_id
    if not _enter_zone(target_id, str(route["target_entry_id"]), target_bake):
        return false
    transition_count += 1
    transition_cooldown = 0.75
    last_transition = "%s → %s" % [
        str(ZONES[previous_zone]["name"]), str(ZONES[target_id]["name"])]
    _update_camera_and_status()
    return true

func _animate_actor(direction: Vector2, delta: float) -> void:
    if actor_sprite == null or actor_profile == null:
        return
    var moving := direction.length_squared() > 0.01
    var clip := actor_profile.clip_for("move" if moving else "idle")
    if clip == null or clip.frames.is_empty():
        return
    animation_time = animation_time + delta if moving else 0.0
    actor_sprite.frame = int(clip.frames[int(floor(animation_time * clip.loop_fps)) % clip.frames.size()])
    if absf(direction.x) > 0.05:
        actor_sprite.flip_h = direction.x < 0.0

func _update_camera_and_status() -> void:
    if stage == null or player == null or bake == null:
        return
    stage.position = ViewportShift.world_offset(player.position, bake.viewport_size)
    status.text = "平江府跨地图跳转 QA  |  当前：%s  |  原生地图 %.0f×%.0f\n转场 %d 次 · %s\nWASD/方向键移动 · 左键选目标 · 绿色连接点自动跳转 · F3 边界 · Esc 返回菜单\n脚点 (%.0f, %.0f) · 镜头 (%.0f, %.0f) · 角色 200px / 80px=u" % [
        str(ZONES[active_zone_id]["name"]), bake.viewport_size.x, bake.viewport_size.y,
        transition_count, last_transition,
        player.position.x, player.position.y, stage.position.x, stage.position.y]

func _return_to_menu() -> void:
    get_tree().call_deferred("change_scene_to_file", "res://opening.tscn")

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        _return_to_menu()
        get_viewport().set_input_as_handled()
        return
    if bake == null or player == null:
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
        debug_line.visible = not debug_line.visible
        get_viewport().set_input_as_handled()
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        last_screen_click = event.position
        last_world_click = ViewportShift.screen_to_world(last_screen_click, stage.position)
        if bake.is_walkable_point(last_world_click, CombatScale.footprint_radius_pixels()):
            goal = last_world_click
