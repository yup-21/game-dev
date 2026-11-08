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
const DEFAULT_EXPLORATION_HEIGHT := 170.0
const DEFAULT_EXPLORATION_ZOOM := 1.375
const REGIONS := {
    "pingjiang_crossroads": {
        "title": "PJ-02·四街十字路", "map": "res://data/maps/pingjiang_crossroads.tres",
        "art": "res://data/native/scene_art/pingjiang_crossroads.tres",
        "size": Vector2(1600, 1000), "start": "player_start",
        "scene": "res://scenes/pingjiang_regions/pj02_crossroads.tscn"},
    "pingjiang_south_gate_qa": {
        "title": "PJ-01·平江瓮城正南门", "map": "res://data/maps/pingjiang_south_gate_qa.tres",
        "art": "res://data/native/scene_art/pingjiang_south_gate_qa.tres",
        "size": Vector2(1600, 2000), "start": "from_south",
        "scene": "res://scenes/pingjiang_regions/pj01_south_gate.tscn"},
    "pingjiang_shen_house": {
        "title": "PJ-04·沈家旧宅", "map": "res://data/maps/pingjiang_shen_house.tres",
        "art": "res://data/native/scene_art/pingjiang_shen_house.tres",
        "size": Vector2(1600, 1000), "start": "player_start",
        "scene": "res://scenes/pingjiang_regions/pj04_shen_house.tscn"},
    "pingjiang_riverside_market": {
        "title": "PJ-03·临河水市主大街", "map": "res://data/maps/pingjiang_riverside_market.tres",
        "art": "res://data/native/scene_art/pingjiang_riverside_market.tres",
        "size": Vector2(4800, 1000), "start": "player_start",
        "scene": "res://scenes/pingjiang_regions/pj03_riverside_market.tscn"},
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
## Presentation-only overrides for the four-area exploration entrance. Other
## independent map QA scenes keep the existing 200px actor and 1:1 viewport.
@export var actor_display_scale: float = 1.0
@export var camera_zoom: float = 1.0
@export var enable_view_controls: bool = false

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
var actor_base_scale: Vector2 = Vector2.ONE
var actor_silhouette: Polygon2D
var actor_profile: WuxiaActorAnimationProfile
var nameplate: Label
var status: Label
var view_settings_panel: PanelContainer
var actor_height_slider: HSlider
var camera_zoom_slider: HSlider
var actor_height_readout: Label
var camera_zoom_readout: Label
var view_summary: Label
var debug_line: Line2D
var debug_visible: bool = false
var goal: Vector2 = Vector2.INF
var animation_time: float = 0.0
var last_screen_click: Vector2 = Vector2.ZERO
var last_world_click: Vector2 = Vector2.ZERO

func _ready() -> void:
    if actor_display_scale <= 0.0 or camera_zoom <= 0.0:
        push_error("Pingjiang QA requires positive actor scale and camera zoom")
        return
    regions = REGIONS.duplicate(true)
    regions.merge(_additional_regions(), true)
    stage = Node2D.new()
    stage.name = "ScrollingWorld"
    stage.scale = Vector2.ONE * camera_zoom
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
    nameplate = Label.new()
    nameplate.text = "沈长风"
    nameplate.position = Vector2(-70.0 / camera_zoom,
        -CombatScale.actor_height_pixels() * actor_display_scale - 48.0 / camera_zoom)
    nameplate.scale = Vector2.ONE / camera_zoom
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
    if enable_view_controls:
        _build_view_controls(hud)

func _build_view_controls(hud: CanvasLayer) -> void:
    view_settings_panel = PanelContainer.new()
    view_settings_panel.name = "ViewSettings"
    view_settings_panel.position = Vector2(1190, 20)
    view_settings_panel.custom_minimum_size = Vector2(380, 0)
    view_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    hud.add_child(view_settings_panel)
    var layout := VBoxContainer.new()
    layout.name = "Options"
    view_settings_panel.add_child(layout)
    var heading := Label.new()
    heading.text = "四区视图调节 · F4 收起/展开"
    layout.add_child(heading)

    var actor_row := HBoxContainer.new()
    layout.add_child(actor_row)
    var actor_caption := Label.new()
    actor_caption.text = "人物高度"
    actor_row.add_child(actor_caption)
    actor_height_slider = HSlider.new()
    actor_height_slider.name = "ActorHeight"
    actor_height_slider.min_value = 100.0
    actor_height_slider.max_value = 220.0
    actor_height_slider.step = 5.0
    actor_height_slider.custom_minimum_size = Vector2(170, 24)
    actor_height_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actor_height_slider.value = CombatScale.actor_height_pixels() * actor_display_scale
    actor_row.add_child(actor_height_slider)
    actor_height_readout = Label.new()
    actor_height_readout.custom_minimum_size = Vector2(66, 0)
    actor_row.add_child(actor_height_readout)
    actor_height_slider.value_changed.connect(_on_actor_height_changed)

    var camera_row := HBoxContainer.new()
    layout.add_child(camera_row)
    var camera_caption := Label.new()
    camera_caption.text = "地图镜头"
    camera_row.add_child(camera_caption)
    camera_zoom_slider = HSlider.new()
    camera_zoom_slider.name = "CameraZoom"
    camera_zoom_slider.min_value = 1.0
    camera_zoom_slider.max_value = 2.0
    camera_zoom_slider.step = 0.001
    camera_zoom_slider.custom_minimum_size = Vector2(170, 24)
    camera_zoom_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    camera_zoom_slider.value = camera_zoom
    camera_row.add_child(camera_zoom_slider)
    camera_zoom_readout = Label.new()
    camera_zoom_readout.custom_minimum_size = Vector2(66, 0)
    camera_row.add_child(camera_zoom_readout)
    camera_zoom_slider.value_changed.connect(_on_camera_zoom_changed)

    view_summary = Label.new()
    layout.add_child(view_summary)

    var reset := Button.new()
    reset.name = "ResetView"
    reset.text = "恢复 170px / 1.375×"
    reset.pressed.connect(_reset_view_settings)
    layout.add_child(reset)
    _refresh_view_readouts()

func _on_actor_height_changed(value: float) -> void:
    actor_display_scale = value / CombatScale.actor_height_pixels()
    _apply_view_settings()

func _on_camera_zoom_changed(value: float) -> void:
    camera_zoom = value
    _apply_view_settings()

func _reset_view_settings() -> void:
    actor_display_scale = DEFAULT_EXPLORATION_HEIGHT / CombatScale.actor_height_pixels()
    camera_zoom = DEFAULT_EXPLORATION_ZOOM
    actor_height_slider.set_value_no_signal(DEFAULT_EXPLORATION_HEIGHT)
    camera_zoom_slider.set_value_no_signal(DEFAULT_EXPLORATION_ZOOM)
    _apply_view_settings()

func _apply_view_settings() -> void:
    if stage == null:
        return
    stage.scale = Vector2.ONE * camera_zoom
    if actor_sprite != null:
        actor_sprite.scale = actor_base_scale * actor_display_scale
    if actor_silhouette != null:
        actor_silhouette.scale = Vector2.ONE * actor_display_scale
    if nameplate != null:
        nameplate.position = Vector2(-70.0 / camera_zoom,
            -CombatScale.actor_height_pixels() * actor_display_scale - 48.0 / camera_zoom)
        nameplate.scale = Vector2.ONE / camera_zoom
    _refresh_view_readouts()
    _update_camera_and_status()

func _refresh_view_readouts() -> void:
    if actor_height_readout != null:
        actor_height_readout.text = "%.0fpx" % (CombatScale.actor_height_pixels() * actor_display_scale)
    if camera_zoom_readout != null:
        camera_zoom_readout.text = "×%.3f" % camera_zoom
    if view_summary != null:
        view_summary.text = "屏幕人物约 %.0fpx · 可见地图 %.0f×%.0f" % [
            CombatScale.actor_height_pixels() * actor_display_scale * camera_zoom,
            ViewportShift.VIEWPORT_SIZE.x / camera_zoom,
            ViewportShift.VIEWPORT_SIZE.y / camera_zoom]

func _additional_regions() -> Dictionary:
    return {}

func _create_region_node(region_id: String) -> Node2D:
    var spec: Dictionary = regions[region_id]
    if not spec.has("scene"):
        return Node2D.new() # explicit legacy QA fixtures only
    var packed := load(str(spec["scene"])) as PackedScene
    if packed == null:
        push_error("Missing native region scene for " + region_id)
        return null
    var result := packed.instantiate() as WuxiaNativeMapRegion
    if result == null or result.source_map == null or result.source_map.content_id != region_id:
        push_error("Invalid native region scene for " + region_id)
        if result != null:
            result.free()
        return null
    return result

func _new_bake(region_id: String):
    var spec: Dictionary = regions[region_id]
    if not spec.has("scene"):
        return MapBake.new(str(spec["map"]))
    var node := _create_region_node(region_id)
    if node == null:
        return null
    var definition := (node as WuxiaNativeMapRegion).build_definition()
    node.free()
    return MapBake.new(str(spec["map"]), definition) if definition != null else null

## Load and display ONE native map; release the previous region after the
## destination Resource, layered art, polygon and entry point all validate.
func _load_region(region_id: String, entry_id: String, prepared_bake = null) -> bool:
    if not regions.has(region_id):
        return false
    var region: Dictionary = regions[region_id]
    var next_node := _create_region_node(region_id)
    if next_node == null:
        return false
    var next_bake = prepared_bake
    if next_bake == null:
        if next_node is WuxiaNativeMapRegion:
            var snapshot := (next_node as WuxiaNativeMapRegion).build_definition()
            if snapshot != null:
                next_bake = MapBake.new(str(region["map"]), snapshot)
        else:
            next_bake = MapBake.new(str(region["map"]))
    if next_bake == null or not next_bake.error.is_empty() or next_bake.id != region_id:
        push_error("Pingjiang QA map invalid: " + region_id)
        next_node.free()
        return false
    var art := load(str(region["art"])) as WuxiaSceneArtProfile
    var region_size: Vector2 = region["size"]
    if art == null or not art.valid_for(Vector2i(region_size)):
        push_error("Pingjiang QA art layers invalid for " + region_id)
        next_node.free()
        return false
    var entry: Dictionary = next_bake.markers.get(entry_id, {})
    var entry_point: Vector2 = next_bake.marker_position(entry_id)
    if str(entry.get("kind", "")) != "spawn" or entry_point == Vector2.INF or \
            not next_bake.is_walkable_point(entry_point, CombatScale.footprint_radius_pixels()):
        push_error("Pingjiang QA requires a walkable spawn marker: " + entry_id)
        next_node.free()
        return false

    next_node.name = region_id
    stage.add_child(next_node)
    if not region.has("scene"):
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
    caption.text = ("E · " + str(target["title"])) if not target.is_empty() else "规划连接 · 尚未接入"
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
        push_warning("Existing actor atlas unavailable; using explicitly scaled QA silhouette")
        actor_silhouette = Polygon2D.new()
        actor_silhouette.color = Color(0.17, 0.34, 0.43)
        actor_silhouette.polygon = PackedVector2Array([
            Vector2(-20, 0), Vector2(-28, -88), Vector2(-43, -137),
            Vector2(-28, -170), Vector2(-15, -176), Vector2(-18, -200),
            Vector2(18, -200), Vector2(15, -176), Vector2(28, -170),
            Vector2(43, -137), Vector2(28, -88), Vector2(20, 0)])
        actor_silhouette.scale = Vector2.ONE * actor_display_scale
        player.add_child(actor_silhouette)
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
    actor_base_scale = actor_sprite.scale
    actor_sprite.scale = actor_base_scale * actor_display_scale

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
    var target_bake = _new_bake(target_id)
    if target_bake == null:
        return false
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
    var visible_world_size := ViewportShift.VIEWPORT_SIZE / camera_zoom
    stage.position = ViewportShift.world_offset(player.position, size, visible_world_size) * camera_zoom
    var nearby: Dictionary = _nearby_exit()
    var interaction: String = "靠近金色连接点按 E 换图" if nearby.is_empty() else "按 E 前往目标区域"
    if not nearby.is_empty() and not regions.has(str(nearby.get("target_zone_id", ""))):
        interaction = "规划连接 · 尚未开放"
    var game_session = get_node_or_null("/root/GameSession")
    var arrived_from_prologue: bool = game_session != null and game_session.prologue_active \
        and bool(game_session.flags.get("prologue_escaped", false))
    var heading: String = "平江府 · 抵达南门（序幕已完成，后续剧情待续）" if arrived_from_prologue else "平江地图测试"
    status.text = "%s  |  %s  |  %d×%d  |  跨区 %d 次\nWASD/方向键移动 · 左键选目标 · %s · F3 可走区 · Esc 返回菜单\n脚点 (%.0f, %.0f) · 镜头 (%.0f, %.0f) · 演示角色 %.0fpx / 80px=u · 镜头×%.3f" % [
        heading, str(region["title"]), int(size.x), int(size.y), crossing_count, interaction,
        player.position.x, player.position.y, stage.position.x, stage.position.y,
        CombatScale.actor_height_pixels() * actor_display_scale, camera_zoom]

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
        elif event.keycode == KEY_F4 and view_settings_panel != null:
            view_settings_panel.visible = not view_settings_panel.visible
            get_viewport().set_input_as_handled()
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        last_screen_click = event.position
        last_world_click = ViewportShift.screen_to_world(last_screen_click, stage.position, camera_zoom)
        if _walkable_world_point(last_world_click, CombatScale.footprint_radius_pixels()):
            goal = last_world_click
