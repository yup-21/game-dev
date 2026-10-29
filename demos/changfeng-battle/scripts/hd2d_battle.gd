extends Node3D
## HD-2D vertical slice. All tactical state and legality remain in BattleModel.
## Run res://battle_hd2d.tscn explicitly; the original 2D scene is untouched.
const Model = preload("res://scripts/battle_model.gd")
const EnemyAI = preload("res://scripts/enemy_ai.gd")
const COLS := 15
const ROWS := 10
const CELL := 1.5

var model = Model.new()
var ai = EnemyAI.new()
var camera: Camera3D
var actor_nodes: Dictionary = {}
var snap: Dictionary = {}
var legals: Array = []
var status_label: Label
var help_label: Label
var animation_time := 0.0
var animation_ticket := -1
var ai_wait := 0.0
var hovered := Vector2i(-1, -1)
var cursor_mesh: MeshInstance3D
var glow_material: StandardMaterial3D

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
    camera.position = Vector3(17, 22, 25)
    rig.add_child(camera)
    camera.look_at(Vector3.ZERO, Vector3.UP)
    camera.current = true

    _box("River", Vector3(0, -0.35, 0), Vector3(3.3, 0.18, 20), Color("397e82"), 0.22)
    for x in range(COLS):
        for y in range(ROWS):
            var cell := Vector2i(x, y)
            var terrain := str(snap.get("terrain", {}).get(cell, ""))
            # Model terrain is authoritative; these meshes are visual only.
            # snap is initialized below before the geometry is built.
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
    var sprite_id := 86 if int(actor.get("team_id", 0)) == 0 else 96
    sprite.texture = load("res://assets/kenney/characters/tile_%04d.png" % sprite_id)
    sprite.pixel_size = 0.092
    sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sprite.transparent = true
    sprite.position.y = 0.80
    root.add_child(sprite)
    actor_nodes[int(actor.id)] = root

func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)
    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    canvas.add_child(panel)
    var column := VBoxContainer.new()
    panel.add_child(column)
    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 18)
    column.add_child(status_label)
    help_label = Label.new()
    help_label.text = "左键合法格移动  ·  Q 基础攻击  ·  G 格挡  ·  Space 结束/Pass  ·  R 重开  ·  Esc 返回主菜单"
    column.add_child(help_label)

func _refresh() -> void:
    snap = model.snapshot(0)
    legals = model.legal_actions(0)
    for actor in snap.get("actors", []):
        var id := int(actor.id)
        if not actor_nodes.has(id):
            _create_actor(actor)

func _update_status() -> void:
    if status_label == null or snap.is_empty():
        return
    var info := "断桥听风 · HD-2D 试验场    %s   tick %d" % [snap.get("phase", ""), int(snap.get("global_tick", 0))]
    for actor in snap.get("actors", []):
        info += "    %s  血 %.1f/%.1f  气 %.1f" % [actor.name, float(actor.hp), float(actor.max_hp), float(actor.qi)]
    if snap.get("outcome", "playing") != "playing":
        info += "    结束: %s" % str(snap.outcome)
    status_label.text = info

func _process(delta: float) -> void:
    if snap.is_empty():
        return
    _update_cursor()
    for actor in snap.get("actors", []):
        var id := int(actor.id)
        if actor_nodes.has(id):
            var node: Node3D = actor_nodes[id]
            var destination := _world(actor.cell)
            node.position = node.position.move_toward(destination, delta * 5.5)
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
    _refresh()
    if snap.get("animation_pending", false):
        animation_ticket = int(result.get("ticket", snap.get("ticket", -1)))
        animation_time = 0.35
    _update_status()

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
    var usable := not _legal("MOVE", hovered).is_empty()
    cursor_mesh.visible = usable and animation_ticket < 0
    if cursor_mesh.visible:
        cursor_mesh.position = _world(hovered) + Vector3(0, 0.085, 0)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
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
                animation_ticket = -1
                _refresh()
                for actor in snap.get("actors", []):
                    actor_nodes[int(actor.id)].position = _world(actor.cell)
            KEY_ESCAPE:
                get_tree().change_scene_to_file("res://opening.tscn")
