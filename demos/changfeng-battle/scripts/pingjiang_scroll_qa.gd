extends Node2D
## Five-screen Pingjiang scrolling QA with two independently authored, stitched street regions.
## Reach it from the Demo menu; Esc returns without modifying story/session state.
const ViewportShift = preload("res://scripts/world_viewport_offset.gd")
const CombatScale = preload("res://scripts/combat_scale.gd")
const MapBake = preload("res://scripts/map_bake.gd")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")
const ACTOR_PROFILE_PATH := "res://data/native/animations/shen_changfeng.tres"
const WORLD_SIZE := Vector2(8000.0, 1000.0)
const SEAM_X := 4800.0
const MOVE_SPEED := 265.0
const REGIONS := [
    {"id": "pingjiang_long_street_qa", "title": "主干道·临河水市",
        "map": "res://data/maps/pingjiang_long_street_qa.tres",
        "art": "res://data/native/scene_art/pingjiang_long_street_qa.tres",
        "size": Vector2(4800.0, 1000.0), "start_x": 0.0},
    {"id": "pingjiang_east_market_qa", "title": "东市·续接街区",
        "map": "res://data/maps/pingjiang_east_market_qa.tres",
        "art": "res://data/native/scene_art/pingjiang_east_market_qa.tres",
        "size": Vector2(3200.0, 1000.0), "start_x": 4800.0}
]

var bake
var region_bakes: Array = []
var region_debug_lines: Array[Line2D] = []
var current_region_index: int = 0
var crossing_count: int = 0
var stage: Node2D
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
    for region_index in range(REGIONS.size()):
        var region: Dictionary = REGIONS[region_index]
        var region_size: Vector2 = region["size"]
        var current_bake = MapBake.new(str(region["map"]))
        if not current_bake.error.is_empty():
            push_error("Pingjiang QA area %s: %s" % [region["id"], current_bake.error])
            return
        var art := load(str(region["art"])) as WuxiaSceneArtProfile
        if art == null or not art.valid_for(Vector2i(region_size)):
            push_error("Pingjiang QA art layers invalid for " + str(region["id"]))
            return
        region_bakes.append(current_bake)
        var region_node := Node2D.new()
        region_node.name = str(region["id"])
        region_node.position = Vector2(float(region["start_x"]), 0.0)
        stage.add_child(region_node)
        _add_layer(region_node, "Background", art.background, region_size, -100)
        _add_layer(region_node, "Ground", art.ground, region_size, -90)
        _add_layer(region_node, "Foreground", art.foreground, region_size, 110)
        var boundary := Line2D.new()
        boundary.name = "WalkableBoundary"
        boundary.points = current_bake.walkable_outline.duplicate()
        boundary.add_point(current_bake.walkable_outline[0])
        boundary.width = 5.0
        boundary.default_color = Color(0.1, 0.87, 0.44, 0.84)
        boundary.visible = false
        boundary.z_index = 150
        region_node.add_child(boundary)
        region_debug_lines.append(boundary)
    bake = region_bakes[0]
    debug_line = region_debug_lines[0]
    player = Node2D.new()
    player.name = "ShenChangfeng"
    player.position = Vector2(200.0, 790.0)
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
    _update_camera_and_status()

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
    if stage == null or player == null or region_bakes.size() != REGIONS.size():
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
    var reached_region := _region_index_at_x(player.position.x)
    if reached_region != -1 and reached_region != current_region_index:
        current_region_index = reached_region
        crossing_count += 1
    player.z_index = clampi(roundi(player.position.y / 20.0), 0, 100)
    _animate_actor(direction, delta)
    _update_camera_and_status()

func _region_index_at_x(world_x: float) -> int:
    if world_x < 0.0 or world_x >= WORLD_SIZE.x:
        return -1
    return 0 if world_x < SEAM_X else 1

func _walkable_world_point(world_point: Vector2, radius: float) -> bool:
    var region_index := _region_index_at_x(world_point.x)
    if region_index == -1 or region_bakes.size() != REGIONS.size():
        return false
    # Around the shared edge, a footprint overlaps both independently baked
    # polygons. Sample safely inside BOTH street ends to avoid a false wall.
    if absf(world_point.x - SEAM_X) <= radius + 3.0:
        return region_bakes[0].is_walkable_point(Vector2(SEAM_X - radius - 5.0,
            world_point.y), radius) and region_bakes[1].is_walkable_point(
            Vector2(radius + 5.0, world_point.y), radius)
    var region: Dictionary = REGIONS[region_index]
    return region_bakes[region_index].is_walkable_point(
        world_point - Vector2(float(region["start_x"]), 0.0), radius)

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
    stage.position = ViewportShift.world_offset(player.position, WORLD_SIZE)
    var title: String = str(REGIONS[current_region_index]["title"])
    status.text = "平江府双区长街 8000×1000  |  %s (%d/2)  |  跨区 %d 次\nWASD/方向键移动 · 左键选目标 · F3 可走区 · Esc 返回菜单\n脚点 (%.0f, %.0f) · 镜头 X %.0f · 角色 200px / 80px=u" % [
        title, current_region_index + 1, crossing_count,
        player.position.x, player.position.y, stage.position.x]

func _return_to_menu() -> void:
    get_tree().call_deferred("change_scene_to_file", "res://opening.tscn")

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        _return_to_menu()
        get_viewport().set_input_as_handled()
        return
    if stage == null or player == null:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        last_screen_click = event.position
        last_world_click = ViewportShift.screen_to_world(last_screen_click, stage.position)
        if _walkable_world_point(last_world_click, CombatScale.footprint_radius_pixels()):
            goal = last_world_click
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
        for boundary in region_debug_lines:
            boundary.visible = not boundary.visible
