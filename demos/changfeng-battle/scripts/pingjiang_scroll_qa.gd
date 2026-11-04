extends Node2D
## Independent Pingjiang map QA. Only the active map is mounted in the world;
## zone_exit marker metadata changes the map at an explicit connection point.
const ViewportShift = preload("res://scripts/world_viewport_offset.gd")
const CombatScale = preload("res://scripts/combat_scale.gd")
const MapBake = preload("res://scripts/map_bake.gd")
const ZoneConnection = preload("res://scripts/map_zone_connection.gd")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")
const ACTOR_PROFILE_PATH := "res://data/native/animations/shen_changfeng.tres"
const MOVE_SPEED := 265.0
const REGIONS := {
    "pingjiang_long_street_qa": {
        "title": "主干道·临河水市", "map": "res://data/maps/pingjiang_long_street_qa.tres",
        "art": "res://data/native/scene_art/pingjiang_long_street_qa.tres",
        "size": Vector2(4800, 1000), "start": "player_start"},
    "pingjiang_east_market_qa": {
        "title": "东市·续接街区", "map": "res://data/maps/pingjiang_east_market_qa.tres",
        "art": "res://data/native/scene_art/pingjiang_east_market_qa.tres",
        "size": Vector2(3200, 1000), "start": "from_west"},
    "pingjiang_north_lane_qa": {
        "title": "北街·南北长巷", "map": "res://data/maps/pingjiang_north_lane_qa.tres",
        "art": "res://data/native/scene_art/pingjiang_north_lane_qa.tres",
        "size": Vector2(1600, 4000), "start": "south_start"}
}

@export var initial_region_id: String = "pingjiang_long_street_qa"

## Other map QA scenes may add dedicated regions without changing the original
## three-zone scrolling test or baking a second stitched world texture.
var regions: Dictionary = {}
var bake
var region_node: Node2D
var current_region_id: String = ""
var crossing_count: int = 0
var stage: Node2D
var player: Node2D
var actor_sprite: Sprite2D
var actor_profile: WuxiaActorAnimationProfile
var status: Label
var debug_line: Line2D
var debug_visible: bool = false
var goal: Vector2 = Vector2.INF
var animation_time: float = 0.0
var last_screen_click: Vector2 = Vector2.ZERO
var last_world_click: Vector2 = Vector2.ZERO

func _ready() -> void:
    regions = REGIONS.duplicate(true)
    regions.merge(_additional_regions(), true)
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
    status.add_theme_font_size_override("font_size", 25)
    status.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
    status.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.03, 0.95))
    status.add_theme_constant_override("shadow_offset_x", 2)
    status.add_theme_constant_override("shadow_offset_y", 2)
    hud.add_child(status)
    if not regions.has(initial_region_id) or not _load_region(initial_region_id,
            str(regions[initial_region_id]["start"])):
        push_error("Pingjiang QA cannot load initial map: " + initial_region_id)

func _additional_regions() -> Dictionary:
    return {}

## Load and display ONE native map; release the previous region after the
## destination Resource, layered art, polygon and entry point all validate.
func _load_region(region_id: String, entry_id: String, prepared_bake = null) -> bool:
    if not regions.has(region_id):
        return false
    var region: Dictionary = regions[region_id]
    var next_bake = prepared_bake
    if next_bake == null:
        next_bake = MapBake.new(str(region["map"]))
    if not next_bake.error.is_empty() or next_bake.id != region_id:
        push_error("Pingjiang QA map %s: %s" % [region_id, next_bake.error])
        return false
    var art := load(str(region["art"])) as WuxiaSceneArtProfile
    var region_size: Vector2 = region["size"]
    if art == null or not art.valid_for(Vector2i(region_size)):
        push_error("Pingjiang QA art layers invalid for " + region_id)
        return false
    var entry: Dictionary = next_bake.markers.get(entry_id, {})
    var entry_point: Vector2 = next_bake.marker_position(entry_id)
    if str(entry.get("kind", "")) != "spawn" or entry_point == Vector2.INF or \
            not next_bake.is_walkable_point(entry_point, CombatScale.footprint_radius_pixels()):
        push_error("Pingjiang QA requires a walkable spawn marker: " + entry_id)
        return false

    var next_node := Node2D.new()
    next_node.name = region_id
    stage.add_child(next_node)
    _add_layer(next_node, "Background", art.background, region_size, -100)
    _add_layer(next_node, "Ground", art.ground, region_size, -90)
    _add_layer(next_node, "Foreground", art.foreground, region_size, 110)
    var boundary := Line2D.new()
    boundary.name = "WalkableBoundary"
    boundary.points = next_bake.walkable_outline.duplicate()
    if not next_bake.walkable_outline.is_empty():
        boundary.add_point(next_bake.walkable_outline[0])
    boundary.width = 5.0
    boundary.default_color = Color(0.1, 0.87, 0.44, 0.84)
    boundary.visible = debug_visible
    boundary.z_index = 150
    next_node.add_child(boundary)
    for marker in next_bake.markers.values():
        if str(marker.get("kind", "")) == "zone_exit":
            _add_exit_sign(next_node, marker)
    if region_node != null:
        region_node.free()
    region_node = next_node
    bake = next_bake
    debug_line = boundary
    current_region_id = region_id
    player.position = entry_point
    player.z_index = clampi(roundi(player.position.y / 20.0), 0, 100)
    goal = Vector2.INF
    last_world_click = Vector2.ZERO
    animation_time = 0.0
    _update_camera_and_status()
    return true

func _add_layer(parent: Node2D, name: String, texture: Texture2D,
        region_size: Vector2, order: int) -> void:
    if texture == null:
        return
    var rect := TextureRect.new()
    rect.name = name
    rect.texture = texture
    rect.size = region_size
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_SCALE
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    rect.z_index = order
    parent.add_child(rect)

func _add_exit_sign(parent: Node2D, marker: Dictionary) -> void:
    var coords: Array = marker["position"]
    var center := Vector2(float(coords[0]), float(coords[1]))
    var gate := Node2D.new()
    gate.name = "Exit_" + str(marker["id"])
    gate.position = center
    parent.add_child(gate)
    var ring := Line2D.new()
    ring.name = "ConnectorRing"
    for n in range(17):
        var angle := TAU * float(n) / 16.0
        ring.add_point(Vector2(cos(angle) * 58.0, sin(angle) * 24.0))
    ring.width = 4.0
    ring.default_color = Color(0.93, 0.74, 0.28, 0.86)
    ring.z_index = 140
    gate.add_child(ring)
    var caption := Label.new()
    caption.name = "ConnectorHint"
    var target: Dictionary = regions.get(str(marker["target_zone_id"]), {})
    caption.text = "E · " + str(target.get("title", "连接点"))
    caption.position = Vector2(-135, -105)
    caption.size = Vector2(270, 38)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_font_size_override("font_size", 23)
    caption.add_theme_color_override("font_color", Color(0.22, 0.30, 0.29))
    caption.add_theme_color_override("font_shadow_color", Color(0.98, 0.96, 0.86))
    caption.add_theme_constant_override("shadow_offset_x", 1)
    caption.add_theme_constant_override("shadow_offset_y", 1)
    caption.z_index = 141
    gate.add_child(caption)

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
        CombatScale.actor_height_pixels(), actor_profile.feet_adjust, reference,
        actor_profile.auto_fit_height)

func _process(delta: float) -> void:
    if stage == null or player == null or bake == null:
        return
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
    var distance_step: float = MOVE_SPEED * delta
    if goal != Vector2.INF:
        distance_step = minf(distance_step, player.position.distance_to(goal))
    var candidate: Vector2 = player.position + direction * distance_step
    var radius := CombatScale.footprint_radius_pixels()
    if _walkable_world_point(Vector2(candidate.x, player.position.y), radius):
        player.position.x = candidate.x
    if _walkable_world_point(Vector2(player.position.x, candidate.y), radius):
        player.position.y = candidate.y
    player.z_index = clampi(roundi(player.position.y / 20.0), 0, 100)
    _animate_actor(direction, delta)
    _update_camera_and_status()

func _walkable_world_point(world_point: Vector2, radius: float) -> bool:
    return bake != null and bake.is_walkable_point(world_point, radius)

func _nearby_exit() -> Dictionary:
    if bake == null or player == null:
        return {}
    for marker in bake.markers.values():
        if str(marker.get("kind", "")) != "zone_exit":
            continue
        var coords: Array = marker.get("position", [])
        if coords.size() != 2:
            continue
        var point := Vector2(float(coords[0]), float(coords[1]))
        if player.position.distance_to(point) <= float(marker.get("radius", 80.0)):
            return marker
    return {}

func _activate_exit(marker_id: String) -> bool:
    var marker: Dictionary = _nearby_exit()
    if marker.is_empty() or str(marker.get("id", "")) != marker_id:
        return false
    var target_id: String = str(marker.get("target_zone_id", ""))
    if target_id == current_region_id or not regions.has(target_id):
        return false
    var target_bake = MapBake.new(str(regions[target_id]["map"]))
    var route: Dictionary = ZoneConnection.resolve_exit(bake, marker_id, target_bake,
        CombatScale.footprint_radius_pixels())
    if route.is_empty() or not _load_region(target_id, str(route["target_entry_id"]), target_bake):
        return false
    crossing_count += 1
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
    if current_region_id.is_empty() or stage == null or player == null:
        return
    var region: Dictionary = regions[current_region_id]
    var size: Vector2 = region["size"]
    stage.position = ViewportShift.world_offset(player.position, size)
    var nearby: Dictionary = _nearby_exit()
    var interaction: String = "靠近金色连接点按 E 换图" if nearby.is_empty() else "按 E 前往目标区域"
    status.text = "平江地图测试  |  %s  |  %d×%d  |  跨区 %d 次\nWASD/方向键移动 · 左键选目标 · %s · F3 可走区 · Esc 返回菜单\n脚点 (%.0f, %.0f) · 镜头 (%.0f, %.0f) · 角色 200px / 80px=u" % [
        str(region["title"]), int(size.x), int(size.y), crossing_count, interaction,
        player.position.x, player.position.y, stage.position.x, stage.position.y]

func _return_to_menu() -> void:
    get_tree().call_deferred("change_scene_to_file", "res://opening.tscn")

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        _return_to_menu()
        get_viewport().set_input_as_handled()
        return
    if stage == null or player == null or bake == null:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_E:
            var marker: Dictionary = _nearby_exit()
            if not marker.is_empty():
                _activate_exit(str(marker["id"]))
                get_viewport().set_input_as_handled()
        elif event.keycode == KEY_F3:
            debug_visible = not debug_visible
            if debug_line != null:
                debug_line.visible = debug_visible
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        last_screen_click = event.position
        last_world_click = ViewportShift.screen_to_world(last_screen_click, stage.position)
        if _walkable_world_point(last_world_click, CombatScale.footprint_radius_pixels()):
            goal = last_world_click
