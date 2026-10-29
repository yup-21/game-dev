extends Node3D
## HD-2D vertical slice. All tactical state and legality remain in BattleModel.
## Run res://battle_hd2d.tscn explicitly; the original 2D scene is untouched.
const Model = preload("res://scripts/battle_model.gd")
const EnemyAI = preload("res://scripts/enemy_ai.gd")
const Scenery = preload("res://scripts/hd2d_scenery.gd")
const UITheme = preload("res://scripts/hd2d_ui_theme.gd")
const SpriteFactory = preload("res://scripts/hd2d_sprite_factory.gd")
const Animator = preload("res://scripts/hd2d_animation.gd")
const COLS := 15
const ROWS := 10
const CELL := 1.5

var model = Model.new()
var ai = EnemyAI.new()
var animation_driver = Animator.new()
var camera: Camera3D
var actor_nodes: Dictionary = {}
var snap: Dictionary = {}
var legals: Array = []
var status_label: Label
var help_label: Label
var clash_label: Label
var phase_label: Label
var animation_time := 0.0
var animation_ticket := -1
var ai_wait := 0.0
var hovered := Vector2i(-1, -1)
var cursor_mesh: MeshInstance3D
var glow_material: StandardMaterial3D
var card_actions: HFlowContainer
var selection_label: Label
var selected_card_uid := ""
var selected_usage_id := ""
var selected_technique := ""
var selected_node := ""
var selected_kind := ""
var last_cue := ""
var cue_lights: Dictionary = {}
var cue_remaining: Dictionary = {}
var target_markers: Array = []
var camera_base := Vector3(17, 22, 25)
var camera_shake := 0.0
var elapsed := 0.0

func _ready() -> void:
    model.reset(2026)
    snap = model.snapshot(0)
    legals = model.legal_actions(0)
    _build_world()
    _build_ui()
    _refresh()
    _update_status()

func _material(color: Color, roughness: float = 1.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material

func _box(name: String, pos: Vector3, size: Vector3, color: Color, roughness: float = 1.0) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var instance := MeshInstance3D.new()
    instance.name = name
    instance.mesh = mesh
    instance.material_override = _material(color, roughness)
    instance.position = pos
    add_child(instance)
    return instance

func _world(cell: Vector2i) -> Vector3:
    return Vector3((float(cell.x) - 7.0) * CELL, 0.0, (float(cell.y) - 4.5) * CELL)

func _build_world() -> void:
    var environment := WorldEnvironment.new()
    var settings := Environment.new()
    settings.background_mode = Environment.BG_COLOR
    settings.background_color = Color("a7c1b3")
    settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    settings.ambient_light_color = Color("b8d0c7")
    settings.ambient_light_energy = 0.65
    settings.fog_enabled = true
    settings.fog_light_color = Color("a8b9a8")
    settings.fog_density = 0.012
    environment.environment = settings
    add_child(environment)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -36, 0)
    sun.light_color = Color("ffdfaa")
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    add_child(sun)

    var rig := Node3D.new()
    rig.name = "CameraRig"
    add_child(rig)
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 29.0
    camera.position = camera_base
    rig.add_child(camera)
    camera.look_at(Vector3.ZERO, Vector3.UP)
    camera.current = true

    var river := _box("River", Vector3(0, -0.35, 0), Vector3(3.3, 0.18, 20), Color("397e82"), 0.22)
    var water := ShaderMaterial.new()
    water.shader = preload("res://shaders/hd2d_river.gdshader")
    river.material_override = water
    for x in range(COLS):
        for y in range(ROWS):
            var cell := Vector2i(x, y)
            var terrain := str(snap.get("terrain", {}).get(cell, ""))
            # Model terrain is authoritative; these meshes are visual only.
            # snap was initialized from the model before geometry creation.
            if terrain == "water":
                continue
            var center := _world(cell)
            var ground_color := Color("647e54") if (x + y) % 3 else Color("70875c")
            if terrain == "bridge":
                ground_color = Color("8b6746")
            elif terrain == "ford":
                ground_color = Color("8e9d8a")
            elif terrain == "rock":
                ground_color = Color("82887a")
            _box("Ground_%d_%d" % [x, y], center + Vector3(0, -0.10, 0),
                Vector3(CELL * 0.985, 0.20, CELL * 0.985), ground_color)
            if terrain == "bridge":
                for plank in range(3):
                    _box("Plank", center + Vector3(0, 0.025, (plank - 1) * 0.42),
                        Vector3(1.45, 0.08, 0.36), Color("9b7955"))
            elif terrain == "bamboo" or terrain == "rock":
                _box("Scenery", center + Vector3(0.40, 0.22, -0.38),
                    Vector3(0.30, 0.44, 0.34), Color("405c43") if terrain == "bamboo" else Color("898d80"))

    # A floating ground highlight; visible only for selectable cells.
    glow_material = _material(Color(0.48, 0.93, 0.77, 0.52))
    glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var highlight := BoxMesh.new()
    highlight.size = Vector3(CELL * 0.94, 0.035, CELL * 0.94)
    cursor_mesh = MeshInstance3D.new()
    cursor_mesh.mesh = highlight
    cursor_mesh.material_override = glow_material
    cursor_mesh.visible = false
    add_child(cursor_mesh)

    for actor in snap.get("actors", []):
        _create_actor(actor)
    Scenery.build(self)
    _build_target_markers()

func _build_target_markers() -> void:
    var marker_mesh := BoxMesh.new()
    marker_mesh.size = Vector3(CELL * 0.76, 0.02, CELL * 0.76)
    var marker_material := StandardMaterial3D.new()
    marker_material.albedo_color = Color(0.27, 0.71, 0.61, 0.16)
    marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    marker_material.no_depth_test = false
    for x in range(COLS):
        for y in range(ROWS):
            var marker := MeshInstance3D.new()
            marker.mesh = marker_mesh
            marker.material_override = marker_material
            marker.position = _world(Vector2i(x, y)) + Vector3(0, 0.09, 0)
            marker.visible = false
            add_child(marker)
            target_markers.append(marker)

func _refresh_target_markers() -> void:
    if target_markers.is_empty():
        return
    var target_cells: Dictionary = {}
    var actions: Array = _selected_actions() if not selected_kind.is_empty() else legals
    for action in actions:
        if selected_kind.is_empty() and str(action.get("kind", "")) != "MOVE":
            continue
        if action.has("target_cell"):
            target_cells[action.target_cell] = true
        if action.has("target_id"):
            for actor in snap.get("actors", []):
                if int(actor.id) == int(action.target_id):
                    target_cells[actor.cell] = true
    for x in range(COLS):
        for y in range(ROWS):
            var cell := Vector2i(x, y)
            var marker: MeshInstance3D = target_markers[x * ROWS + y]
            marker.visible = target_cells.has(cell) and animation_ticket < 0 and _decision_owner() == 0

func _create_actor(actor: Dictionary) -> void:
    var root := Node3D.new()
    root.name = "Actor_%d" % int(actor.id)
    root.position = _world(actor.cell)
    add_child(root)
    var shadow := MeshInstance3D.new()
    var disc := CylinderMesh.new()
    disc.top_radius = 0.42
    disc.bottom_radius = 0.42
    disc.height = 0.03
    shadow.mesh = disc
    shadow.material_override = _material(Color("263c34"))
    root.add_child(shadow)
    var sprite := Sprite3D.new()
    sprite.texture = SpriteFactory.make_sheet(int(actor.get("team_id", 0)) != 0)
    sprite.pixel_size = 0.024
    sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sprite.transparent = true
    sprite.position.y = 0.80
    root.add_child(sprite)
    animation_driver.register_actor(int(actor.id), sprite)
    var nameplate := Label3D.new()
    nameplate.name = "Nameplate"
    nameplate.text = str(actor.get("name", "江湖客"))
    nameplate.font_size = 28
    nameplate.pixel_size = 0.006
    nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    nameplate.modulate = Color("ccead8") if int(actor.get("team_id", 0)) == 0 else Color("f2b4a2")
    nameplate.position.y = 1.85
    root.add_child(nameplate)
    var cue := OmniLight3D.new()
    cue.light_color = Color("eac77e")
    cue.light_energy = 0.0
    cue.omni_range = 3.0
    cue.position.y = 1.15
    root.add_child(cue)
    cue_lights[int(actor.id)] = cue
    cue_remaining[int(actor.id)] = 0.0
    actor_nodes[int(actor.id)] = root

func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)

    # Upper status banner: parchment typography over translucent dark jade.
    var panel := PanelContainer.new()
    canvas.add_child(panel)
    panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    panel.offset_left = 10.0
    panel.offset_right = -10.0
    panel.offset_top = 8.0
    panel.offset_bottom = 108.0
    UITheme.apply_panel(panel)
    var column := VBoxContainer.new()
    panel.add_child(column)
    var heading := Label.new()
    heading.text = "长风浮生录  ·  断桥论剑"
    heading.add_theme_font_size_override("font_size", 23)
    heading.add_theme_color_override("font_color", UITheme.GOLD)
    column.add_child(heading)
    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 16)
    status_label.add_theme_color_override("font_color", UITheme.PAPER)
    column.add_child(status_label)
    help_label = Label.new()
    help_label.text = "左键走位/选目标  ·  Q 普攻  ·  G 格挡  ·  Space Pass/结束  ·  R 重开  ·  右键取消  ·  Esc 返回"
    help_label.add_theme_font_size_override("font_size", 12)
    help_label.add_theme_color_override("font_color", UITheme.MUTED)
    column.add_child(help_label)

    # Combat priority and response window information remain visible.
    var sidebar := PanelContainer.new()
    canvas.add_child(sidebar)
    sidebar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    sidebar.offset_left = -350.0
    sidebar.offset_right = -12.0
    sidebar.offset_top = 119.0
    sidebar.offset_bottom = 236.0
    UITheme.apply_panel(sidebar)
    var sidebar_column := VBoxContainer.new()
    sidebar.add_child(sidebar_column)
    phase_label = Label.new()
    phase_label.add_theme_font_size_override("font_size", 19)
    phase_label.add_theme_color_override("font_color", UITheme.GOLD)
    sidebar_column.add_child(phase_label)
    clash_label = Label.new()
    clash_label.add_theme_font_size_override("font_size", 14)
    clash_label.add_theme_color_override("font_color", UITheme.PAPER)
    sidebar_column.add_child(clash_label)

    # The lower martial-arts command tray keeps the 3D battlefield visible.
    var tray := PanelContainer.new()
    canvas.add_child(tray)
    tray.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    tray.offset_left = 12.0
    tray.offset_right = -12.0
    tray.offset_top = -230.0
    tray.offset_bottom = -10.0
    UITheme.apply_panel(tray)
    var tray_column := VBoxContainer.new()
    tray.add_child(tray_column)
    var tray_heading := Label.new()
    tray_heading.text = "武 学 招 式  /  自由行动与连锁交锋"
    tray_heading.add_theme_font_size_override("font_size", 19)
    tray_heading.add_theme_color_override("font_color", UITheme.GOLD)
    tray_column.add_child(tray_heading)
    selection_label = Label.new()
    selection_label.text = "选择武学招式后点击合法目标；敌人响应期间可进行迎锋、闪避与截势。"
    selection_label.add_theme_font_size_override("font_size", 14)
    selection_label.add_theme_color_override("font_color", UITheme.MUTED)
    tray_column.add_child(selection_label)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tray_column.add_child(scroll)
    card_actions = HFlowContainer.new()
    card_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(card_actions)

func _refresh() -> void:
    snap = model.snapshot(0)
    legals = model.legal_actions(0)
    for actor in snap.get("actors", []):
        var id := int(actor.id)
        if not actor_nodes.has(id):
            _create_actor(actor)
    _rebuild_actions()
    _refresh_target_markers()

func _decision_owner() -> int:
    if snap.get("phase", "") == "CLASH":
        return int(snap.get("clash", {}).get("priority_actor_id", -1))
    return int(snap.get("active_id", -1))

func _find_actions(uid: String, usage: String) -> Array:
    var choices: Array = []
    for action in legals:
        if str(action.get("kind", "")) == "PLAY_CARD" and str(action.get("card_uid", action.get("card_id", ""))) == uid and str(action.get("usage_id", "")) == usage:
            choices.append(action)
    return choices

func _clear_selection() -> void:
    selected_card_uid = ""
    selected_usage_id = ""
    selected_technique = ""
    selected_node = ""
    selected_kind = ""

func _rebuild_actions() -> void:
    if card_actions == null:
        return
    for child in card_actions.get_children():
        if child != selection_label:
            child.queue_free()
    var available: bool = _decision_owner() == 0 and not bool(snap.get("animation_pending", false)) and str(snap.get("outcome", "playing")) == "playing"
    selection_label.text = ("选择目标：" + selected_usage_id if not selected_usage_id.is_empty() else "左键走位，选择招式后再点目标格；右键取消") if available else "等待对手行动 / 动画结算"
    if not available:
        return
    for card in snap.get("hand", []):
        var uid := str(card.get("uid", card.get("card_id", "")))
        for usage in card.get("usages", []):
            var usage_id := str(usage.get("id", ""))
            if _find_actions(uid, usage_id).is_empty():
                continue
            var button := Button.new()
            var cost: Dictionary = usage.get("quoted_cost", {})
            button.text = "%s · %s (%.1f 气)" % [str(card.get("name", "招式")), str(usage.get("name", usage_id)), float(cost.get("qi", 0))]
            UITheme.apply_button(button)
            button.pressed.connect(_select_card.bind(uid, usage_id))
            card_actions.add_child(button)
    var seen_abilities: Dictionary = {}
    for action in legals:
        if str(action.get("kind", "")) != "USE_ABILITY":
            continue
        var technique_id := str(action.get("technique_id", ""))
        var node_id := str(action.get("node_id", ""))
        var key := technique_id + ":" + node_id
        if seen_abilities.has(key):
            continue
        seen_abilities[key] = true
        var button := Button.new()
        button.text = "武学续式 %s / %s" % [technique_id, node_id]
        UITheme.apply_button(button)
        button.pressed.connect(_select_technique.bind(technique_id, node_id))
        card_actions.add_child(button)
    if snap.get("phase", "") == "CLASH":
        var pass_button := Button.new()
        pass_button.text = "Pass · 交还响应权"
        UITheme.apply_button(pass_button)
        pass_button.pressed.connect(_submit.bind("PASS_REACTION", {}))
        card_actions.add_child(pass_button)

func _select_card(uid: String, usage: String) -> void:
    _clear_selection()
    selected_card_uid = uid
    selected_usage_id = usage
    selected_kind = "PLAY_CARD"
    _activate_selection()

func _select_technique(technique: String, node: String) -> void:
    _clear_selection()
    selected_technique = technique
    selected_node = node
    selected_kind = "USE_ABILITY"
    _activate_selection()

func _selected_actions() -> Array:
    if selected_kind == "PLAY_CARD":
        return _find_actions(selected_card_uid, selected_usage_id)
    var choices: Array = []
    if selected_kind == "USE_ABILITY":
        for action in legals:
            if str(action.get("kind", "")) == selected_kind and str(action.get("technique_id", "")) == selected_technique and str(action.get("node_id", "")) == selected_node:
                choices.append(action)
    return choices

func _submit_legal(action: Dictionary) -> void:
    var params: Dictionary = {}
    for key in ["card_uid", "card_id", "usage_id", "technique_id", "node_id", "target_cell", "target_id", "link_id"]:
        if action.has(key):
            params[key] = action[key]
    _clear_selection()
    _submit(str(action.get("kind", "")), params)

func _activate_selection() -> void:
    var actions := _selected_actions()
    if actions.is_empty():
        _clear_selection()
        return
    # Untargeted effects execute immediately. Link-targeted responses get buttons.
    if not actions[0].has("target_cell") and not actions[0].has("target_id") and not actions[0].has("link_id"):
        _submit_legal(actions[0])
        return
    for action in actions:
        if not action.has("link_id"):
            continue
        var button := Button.new()
        button.text = "截势：选择响应层 %s" % str(action.link_id)
        UITheme.apply_button(button)
        button.pressed.connect(_submit_legal.bind(action))
        card_actions.add_child(button)
    selection_label.text = "已选择招式：点击绿色目标格或角色；右键取消。"
    _refresh_target_markers()

func _action_at(cell: Vector2i) -> Dictionary:
    for action in _selected_actions():
        if action.has("target_cell") and action.target_cell == cell:
            return action
        if action.has("target_id"):
            var target_id := int(action.target_id)
            for actor in snap.get("actors", []):
                if int(actor.id) == target_id and actor.cell == cell:
                    return action
    return {}

func _update_status() -> void:
    if status_label == null or snap.is_empty():
        return
    var info := "断桥听风 · HD-2D 试验场    %s   tick %d" % [snap.get("phase", ""), int(snap.get("global_tick", 0))]
    for actor in snap.get("actors", []):
        info += "    %s  血 %.1f/%.1f  气 %.1f" % [actor.name, float(actor.hp), float(actor.max_hp), float(actor.qi)]
    if snap.get("outcome", "playing") != "playing":
        info += "    结束: %s" % str(snap.outcome)
    status_label.text = info
    var acting: int = _decision_owner()
    if phase_label != null:
        phase_label.text = "交锋应变" if snap.get("phase", "") == "CLASH" else ("自由行动" if acting == 0 else "敌方行动")
    if clash_label != null:
        var clash: Dictionary = snap.get("clash", {})
        if snap.get("phase", "") == "CLASH":
            clash_label.text = "响应层 %d / 4   Pass %d / 2\n%s获得响应权" % [clash.get("stack", []).size(), int(clash.get("consecutive_passes", 0)), "我方" if acting == 0 else "敌方"]
        else:
            clash_label.text = "移动 · 出招 · 护体 · 连携\n按合法行动结算，不改变原规则"

func _process(delta: float) -> void:
    if snap.is_empty():
        return
    elapsed += delta
    camera_shake = maxf(0.0, camera_shake - delta)
    if camera_shake > 0.0:
        camera.position = camera_base + Vector3(sin(elapsed * 71.0) * 0.12, sin(elapsed * 89.0) * 0.07, 0) * camera_shake
    else:
        camera.position = camera_base
    _update_cursor()
    var moving: Dictionary = {}
    for actor in snap.get("actors", []):
        var id := int(actor.id)
        if actor_nodes.has(id):
            var node: Node3D = actor_nodes[id]
            var destination := _world(actor.cell)
            node.position = node.position.move_toward(destination, delta * 5.5)
            moving[id] = node.position.distance_to(destination) > 0.035
            var sprite: Sprite3D = node.get_node_or_null("Sprite3D") as Sprite3D
            if sprite != null:
                sprite.position.y = 0.80 + sin(elapsed * 2.5 + float(id) * 1.4) * 0.035
    animation_driver.update(delta, moving)
    for id in cue_remaining.keys():
        cue_remaining[id] = maxf(0.0, float(cue_remaining[id]) - delta)
        if cue_lights.has(id):
            var light: OmniLight3D = cue_lights[id]
            light.light_energy = float(cue_remaining[id]) * 4.0
    if animation_ticket >= 0:
        animation_time -= delta
        if animation_time <= 0.0:
            var ticket := animation_ticket
            animation_ticket = -1
            _accept(model.acknowledge_animation(ticket))
        return
    if snap.get("outcome", "playing") != "playing":
        return
    var decision_id := int(snap.get("active_id", -1))
    if snap.get("phase", "") == "CLASH":
        decision_id = int(snap.get("clash", {}).get("priority_actor_id", -1))
    if decision_id != 0:
        ai_wait -= delta
        if ai_wait <= 0:
            var request: Dictionary = ai.choose_action(model.decision_context(decision_id))
            ai_wait = 0.4
            if not request.is_empty():
                _accept(model.submit(request))

func _accept(result: Dictionary) -> void:
    if not result.get("success", false):
        push_warning(str(result.get("message", "Action rejected")))
        return
    _cue_events(result.get("events", []))
    animation_driver.events(result.get("events", []))
    _clear_selection()
    _refresh()
    if snap.get("animation_pending", false):
        animation_ticket = int(result.get("ticket", snap.get("ticket", -1)))
        animation_time = _event_duration(result.get("events", []))
    _refresh_target_markers()
    _update_status()

func _event_duration(events: Array) -> float:
    var duration: float = 0.35
    for event in events:
        match str(event.get("type", "")):
            "ATTACK_DECLARED", "ATTACK_HIT", "COMBO_TRIGGERED":
                duration = maxf(duration, 0.62)
            "MOVE":
                duration = maxf(duration, 0.50)
            "INTERCEPT_JUDGED", "ATTACK_INTERRUPTED":
                duration = maxf(duration, 0.40)
    return duration

func _cue_events(events: Array) -> void:
    for event in events:
        var kind := str(event.get("type", ""))
        var id := int(event.get("defender_id", event.get("target_id", event.get("actor_id", -1))))
        if kind in ["ATTACK_DECLARED", "COMBO_TRIGGERED", "SHIELD", "MOVE"]:
            id = int(event.get("actor_id", id))
        if not cue_lights.has(id):
            continue
        var light: OmniLight3D = cue_lights[id]
        match kind:
            "ATTACK_DECLARED":
                light.light_color = Color("f0bd66")
            "COMBO_TRIGGERED":
                light.light_color = Color("f9df8a")
            "DAMAGE", "HP_DAMAGED", "SCORCH_TICK":
                light.light_color = Color("f05a50")
            "SHIELD", "INTERCEPT_JUDGED":
                light.light_color = Color("79d9c3")
            "MOVE":
                light.light_color = Color("80bfc3")
            _:
                continue
        cue_remaining[id] = 0.55
        last_cue = kind
        if kind in ["DAMAGE", "HP_DAMAGED", "ATTACK_HIT", "COMBO_TRIGGERED"]:
            camera_shake = 0.20

func _submit(kind: String, params: Dictionary = {}) -> void:
    if animation_ticket >= 0:
        return
    var owner := int(snap.get("active_id", -1))
    if snap.get("phase", "") == "CLASH":
        owner = int(snap.get("clash", {}).get("priority_actor_id", -1))
    if owner != 0:
        return
    _accept(model.submit(model.request(kind, 0, params)))

func _legal(kind: String, cell: Vector2i = Vector2i(-1, -1)) -> Dictionary:
    for action in legals:
        if str(action.get("kind", "")) != kind:
            continue
        if cell.x >= 0 and action.get("target_cell", Vector2i(-2, -2)) != cell:
            continue
        return action
    return {}

func _hover_cell() -> Vector2i:
    var mouse := get_viewport().get_mouse_position()
    var origin := camera.project_ray_origin(mouse)
    var direction := camera.project_ray_normal(mouse)
    if absf(direction.y) < 0.0001:
        return Vector2i(-1, -1)
    var t := -origin.y / direction.y
    if t < 0:
        return Vector2i(-1, -1)
    var point := origin + direction * t
    var x := roundi(point.x / CELL + 7.0)
    var y := roundi(point.z / CELL + 4.5)
    if x < 0 or x >= COLS or y < 0 or y >= ROWS:
        return Vector2i(-1, -1)
    return Vector2i(x, y)

func _update_cursor() -> void:
    hovered = _hover_cell()
    var usable := not _action_at(hovered).is_empty() if not selected_kind.is_empty() else not _legal("MOVE", hovered).is_empty()
    cursor_mesh.visible = usable and animation_ticket < 0
    if cursor_mesh.visible:
        cursor_mesh.position = _world(hovered) + Vector3(0, 0.13, 0)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        _clear_selection()
        _rebuild_actions()
        _refresh_target_markers()
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if not selected_kind.is_empty():
            var selected := _action_at(_hover_cell())
            if not selected.is_empty():
                _submit_legal(selected)
        else:
            var move := _legal("MOVE", _hover_cell())
            if not move.is_empty():
                _submit("MOVE", {"target_cell": move.target_cell})
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_Q:
                var attack := _legal("BASIC_ATTACK")
                if not attack.is_empty():
                    _submit("BASIC_ATTACK", {"target_id": attack.target_id})
            KEY_G:
                if not _legal("BASIC_GUARD").is_empty():
                    _submit("BASIC_GUARD")
            KEY_SPACE, KEY_ENTER:
                var kind := "PASS_REACTION" if snap.get("phase", "") == "CLASH" else "END_ACTION"
                if not _legal(kind).is_empty():
                    _submit(kind)
            KEY_R:
                model.reset(2026)
                animation_driver.reset()
                _clear_selection()
                animation_ticket = -1
                _refresh()
                _refresh_target_markers()
                for actor in snap.get("actors", []):
                    actor_nodes[int(actor.id)].position = _world(actor.cell)
            KEY_ESCAPE:
                get_tree().change_scene_to_file("res://opening.tscn")
