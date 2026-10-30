extends Node3D
## HD-2D vertical slice. All tactical state and legality remain in BattleModel.
## Run res://battle_hd2d.tscn explicitly; the original 2D scene is untouched.
const Model = preload("res://scripts/battle_model.gd")
const EnemyAI = preload("res://scripts/enemy_ai.gd")
const Scenery = preload("res://scripts/hd2d_scenery.gd")
const UITheme = preload("res://scripts/hd2d_ui_theme.gd")
const CardUI = preload("res://scripts/hd2d_card_ui.gd")
const ArtCatalog = preload("res://scripts/hd2d_art_catalog.gd")
const Animator = preload("res://scripts/hd2d_animation.gd")
const VFX = preload("res://scripts/hd2d_vfx.gd")
const COLS := 15
const ROWS := 10
const CELL := 1.5

var model = Model.new()
var story_encounter := false
var observer_id := 0
var result_reported := false
var ai = EnemyAI.new()
var animation_driver = Animator.new()
var effects_driver
var camera: Camera3D
var actor_nodes: Dictionary = {}
var snap: Dictionary = {}
var legals: Array = []
var status_label: Label
var help_label: Label
var clash_label: Label
var phase_label: Label
var roster_labels: Dictionary = {}
var roster_bars: Dictionary = {}
var animation_time := 0.0
var animation_ticket := -1
var ai_wait := 0.0
var hovered := Vector2i(-1, -1)
var cursor_mesh: MeshInstance3D
var glow_material: StandardMaterial3D
var card_actions: HBoxContainer
var command_actions: VBoxContainer
var command_scroll: ScrollContainer
var context_veil: TextureRect
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
var intro_remaining := 3.25
var intro_title: Label
var intro_subtitle: Label

func _ready() -> void:
    var session = _session()
    story_encounter = session != null and session.phase == "battle"
    if story_encounter:
        model.reset(session.encounter_seed(), -1, "tingfeng", session.encounter_options())
    else:
        model.reset(2026)
    observer_id = _first_player_id()
    snap = model.snapshot(observer_id)
    legals = model.legal_actions(_decision_owner())
    _build_world()
    effects_driver = VFX.new(self, camera)
    _build_ui()
    _refresh()
    _update_status()

func _session():
    return get_node_or_null("/root/GameSession")

func _first_player_id() -> int:
    for actor in model.state.actors:
        if actor.team_id == 0 and actor.controller == "PLAYER":
            return actor.id
    return 0

func _player_decision() -> bool:
    var actor = model.state.get_actor(_decision_owner())
    return actor != null and actor.controller == "PLAYER"

func _report_story_result() -> void:
    if not story_encounter or result_reported or str(snap.get("outcome", "playing")) == "playing":
        return
    var session = _session()
    if session != null and session.phase == "battle":
        session.report_battle(str(snap.get("outcome", "draw")), int(snap.get("winning_team", -1)))
    result_reported = true

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
    settings.background_color = Color("27383d") if story_encounter else Color("a7c1b3")
    settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    settings.ambient_light_color = Color("91a9b7") if story_encounter else Color("b8d0c7")
    settings.ambient_light_energy = 0.48 if story_encounter else 0.65
    settings.fog_enabled = true
    settings.fog_light_color = Color("4e6469") if story_encounter else Color("a8b9a8")
    settings.fog_density = 0.012
    environment.environment = settings
    add_child(environment)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -36, 0)
    sun.light_color = Color("b3c6d5") if story_encounter else Color("ffdfaa")
    sun.light_energy = 0.65 if story_encounter else 1.25
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
            var ground_color := Color("6b806a") if (x + y) % 3 else Color("70866c")
            if terrain == "bridge":
                ground_color = Color("8b6746")
            elif terrain == "ford":
                ground_color = Color("8e9d8a")
            elif terrain == "rock":
                ground_color = Color("82887a")
            # Flush terrain plates avoid a visible block-grid; rules still use 15x10 cells.
            _box("Ground_%d_%d" % [x, y], center + Vector3(0, -0.052, 0),
                Vector3(CELL * 1.003, 0.105, CELL * 1.003), ground_color)
            if terrain != "bridge" and terrain != "rock" and (x * 7 + y * 11) % 8 == 0:
                var moss := MeshInstance3D.new()
                var patch := CylinderMesh.new()
                patch.top_radius = 0.34
                patch.bottom_radius = 0.36
                patch.height = 0.018
                moss.mesh = patch
                moss.material_override = _material(Color("7a9175"))
                moss.position = center + Vector3(-0.31, 0.014, 0.28)
                add_child(moss)
            if terrain == "bridge":
                for plank in range(3):
                    _box("Plank", center + Vector3(0, 0.025, (plank - 1) * 0.42),
                        Vector3(1.45, 0.08, 0.36), Color("9b7955"))
            elif terrain == "bamboo" or terrain == "rock":
                var ornament := MeshInstance3D.new()
                var shape := SphereMesh.new()
                shape.radius = 0.34 if terrain == "bamboo" else 0.40
                shape.height = 0.66 if terrain == "bamboo" else 0.55
                ornament.mesh = shape
                ornament.material_override = _material(
                    Color("476b54") if terrain == "bamboo" else Color("8c9185"))
                ornament.position = center + Vector3(0.37, 0.28, -0.32)
                ornament.scale = Vector3(0.90, 1.18, 0.78)
                add_child(ornament)

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
    Scenery.build(self, story_encounter, camera)
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
            marker.visible = target_cells.has(cell) and animation_ticket < 0 and _player_decision()

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
    sprite.name = "Sprite3D"
    var actor_id := int(actor.id)
    var enemy := int(actor.get("team_id", 0)) != 0
    sprite.texture = ArtCatalog.sheet_for_actor(actor_id, enemy)
    # Normalize differing atlas cell sizes to one world-space character height.
    sprite.pixel_size = 2.16 / (float(sprite.texture.get_height()) / 4.0)
    sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sprite.transparent = true
    sprite.position.y = 1.12
    root.add_child(sprite)
    animation_driver.register_actor(int(actor.id), sprite)
    var nameplate := Label3D.new()
    nameplate.name = "Nameplate"
    nameplate.text = str(actor.get("name", "江湖客"))
    nameplate.font_size = 28
    nameplate.pixel_size = 0.006
    nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    nameplate.modulate = Color("ccead8") if int(actor.get("team_id", 0)) == 0 else Color("f2b4a2")
    nameplate.position.y = 2.52
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

func _veil(parent: Control, texture: Texture2D) -> TextureRect:
    # Decorative texture is deliberately non-interactive: the battlefield
    # must still receive all clicks outside the actual card/command controls.
    var image := TextureRect.new()
    image.texture = texture
    image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    image.stretch_mode = TextureRect.STRETCH_SCALE
    image.mouse_filter = Control.MOUSE_FILTER_IGNORE
    image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    parent.add_child(image)
    return image

func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "WuxiaCombatHUD"
    add_child(canvas)
    var hud := Control.new()
    hud.name = "UnifiedHUD"
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(hud)

    # A narrow ink gradient replaces the old full-width framed banner.
    var ribbon := Control.new()
    ribbon.name = "ChapterRibbon"
    ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(ribbon)
    ribbon.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    ribbon.offset_top = 0.0
    ribbon.offset_bottom = 95.0
    _veil(ribbon, preload("res://assets/ui/veil_top.svg"))
    var header := HBoxContainer.new()
    header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    header.offset_left = 28.0
    header.offset_right = -29.0
    header.offset_top = 12.0
    header.offset_bottom = 70.0
    header.add_theme_constant_override("separation", 13)
    ribbon.add_child(header)
    var seal := TextureRect.new()
    seal.name = "JadeMark"
    seal.texture = preload("res://assets/ui/jade_seal.svg")
    seal.custom_minimum_size = Vector2(43, 43)
    seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header.add_child(seal)
    var heading_stack := VBoxContainer.new()
    heading_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading_stack.add_theme_constant_override("separation", 2)
    header.add_child(heading_stack)
    var heading := Label.new()
    heading.text = "长风浮生录  /  雨夜残镖" if story_encounter else "长风浮生录  /  断桥听风"
    heading.add_theme_font_size_override("font_size", 24)
    heading.add_theme_color_override("font_color", UITheme.PAPER)
    heading_stack.add_child(heading)
    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 13)
    status_label.add_theme_color_override("font_color", UITheme.MUTED)
    heading_stack.add_child(status_label)
    var right_heading := VBoxContainer.new()
    right_heading.add_theme_constant_override("separation", 2)
    header.add_child(right_heading)
    phase_label = Label.new()
    phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    phase_label.add_theme_font_size_override("font_size", 19)
    phase_label.add_theme_color_override("font_color", UITheme.GOLD)
    right_heading.add_child(phase_label)
    help_label = Label.new()
    help_label.text = "左键选目标 · Q 攻击 · G 格挡 · Space 收势/Pass · 右键取消 · Esc 返回"
    help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    help_label.add_theme_font_size_override("font_size", 11)
    help_label.add_theme_color_override("font_color", UITheme.MUTED)
    right_heading.add_child(help_label)

    # Team status floats directly over the scene: no per-actor rectangular
    # panels, only portraits, fine health/qi strokes and CTB typography.
    var party := Control.new()
    party.name = "FloatingRoster"
    party.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(party)
    party.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    party.offset_left = 0.0
    party.offset_right = 285.0
    party.offset_top = 105.0
    party.offset_bottom = 619.0
    _veil(party, preload("res://assets/ui/veil_left.svg"))
    var roster_heading := Label.new()
    roster_heading.text = "江 湖 同 行    ·    CTB"
    roster_heading.position = Vector2(20, 16)
    roster_heading.size = Vector2(241, 29)
    roster_heading.add_theme_font_size_override("font_size", 16)
    roster_heading.add_theme_color_override("font_color", UITheme.GOLD)
    roster_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
    party.add_child(roster_heading)
    var roster_scroll := ScrollContainer.new()
    roster_scroll.name = "RosterScroll"
    roster_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    party.add_child(roster_scroll)
    roster_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    roster_scroll.offset_left = 17.0
    roster_scroll.offset_right = -19.0
    roster_scroll.offset_top = 49.0
    roster_scroll.offset_bottom = -10.0
    roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    var roster_list := VBoxContainer.new()
    roster_list.name = "ActorList"
    roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    roster_list.add_theme_constant_override("separation", 8)
    roster_scroll.add_child(roster_list)
    for actor in snap.get("actors", []):
        var actor_id := int(actor.id)
        var enemy := int(actor.get("team_id", 0)) != 0
        var actor_row := HBoxContainer.new()
        actor_row.name = "Status_%d" % actor_id
        actor_row.custom_minimum_size = Vector2(0, 57)
        actor_row.add_theme_constant_override("separation", 9)
        roster_list.add_child(actor_row)
        var avatar := TextureRect.new()
        avatar.custom_minimum_size = Vector2(46, 51)
        avatar.texture = ArtCatalog.avatar(actor_id, enemy)
        avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
        actor_row.add_child(avatar)
        var detail := VBoxContainer.new()
        detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        detail.add_theme_constant_override("separation", 5)
        actor_row.add_child(detail)
        var entry := Label.new()
        entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        entry.add_theme_font_size_override("font_size", 13)
        entry.add_theme_color_override("font_color", UITheme.RED if enemy else UITheme.JADE)
        detail.add_child(entry)
        roster_labels[actor_id] = entry
        var hp := ProgressBar.new()
        UITheme.apply_meter(hp, UITheme.RED if enemy else Color("a5cda9"))
        detail.add_child(hp)
        var qi := ProgressBar.new()
        UITheme.apply_meter(qi, UITheme.JADE)
        detail.add_child(qi)
        roster_bars[actor_id] = {"hp": hp, "qi": qi}

    # The right rail has no box. It reveals a soft ink veil only while actual
    # commands are available; clash details appear only during CLASH.
    var context := Control.new()
    context.name = "ContextActions"
    context.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(context)
    context.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    context.offset_left = -319.0
    context.offset_right = 0.0
    context.offset_top = 112.0
    context.offset_bottom = 535.0
    context_veil = _veil(context, preload("res://assets/ui/veil_right.svg"))
    clash_label = Label.new()
    clash_label.name = "ClashDetails"
    clash_label.position = Vector2(23, 15)
    clash_label.size = Vector2(274, 69)
    clash_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    clash_label.add_theme_font_size_override("font_size", 15)
    clash_label.add_theme_color_override("font_color", UITheme.PAPER)
    context.add_child(clash_label)
    command_scroll = ScrollContainer.new()
    command_scroll.name = "ContextScroll"
    context.add_child(command_scroll)
    command_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    command_scroll.offset_left = 23.0
    command_scroll.offset_right = -20.0
    command_scroll.offset_top = 85.0
    command_scroll.offset_bottom = -9.0
    command_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    command_actions = VBoxContainer.new()
    command_actions.name = "CommandActions"
    command_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    command_actions.add_theme_constant_override("separation", 8)
    command_scroll.add_child(command_actions)

    # Ink fades out into the battlefield. Cards themselves are the UI and do
    # not sit inside a second solid, framed tray.
    var hand_stage := Control.new()
    hand_stage.name = "HandStage"
    hand_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(hand_stage)
    hand_stage.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    hand_stage.offset_left = 0.0
    hand_stage.offset_right = 0.0
    hand_stage.offset_top = -321.0
    hand_stage.offset_bottom = 0.0
    _veil(hand_stage, preload("res://assets/ui/veil_hand.svg"))
    var hand_title := Label.new()
    hand_title.text = "听 风 出 招    /    武 学"
    hand_title.add_theme_font_size_override("font_size", 19)
    hand_title.add_theme_color_override("font_color", UITheme.GOLD)
    hand_stage.add_child(hand_title)
    hand_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    hand_title.offset_left = 65.0
    hand_title.offset_right = 440.0
    hand_title.offset_top = 18.0
    hand_title.offset_bottom = 46.0
    selection_label = Label.new()
    selection_label.name = "HandInstruction"
    selection_label.text = "选一式，点目标；右键取消。"
    selection_label.add_theme_font_size_override("font_size", 13)
    selection_label.add_theme_color_override("font_color", UITheme.MUTED)
    hand_stage.add_child(selection_label)
    selection_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    selection_label.offset_left = 65.0
    selection_label.offset_right = -50.0
    selection_label.offset_top = 49.0
    selection_label.offset_bottom = 72.0
    var hand_scroll := ScrollContainer.new()
    hand_scroll.name = "HandScroll"
    hand_stage.add_child(hand_scroll)
    hand_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hand_scroll.offset_left = 64.0
    hand_scroll.offset_right = -62.0
    hand_scroll.offset_top = 79.0
    hand_scroll.offset_bottom = -9.0
    hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    card_actions = HBoxContainer.new()
    card_actions.name = "CardActions"
    # Center short hands; once cards overflow, normal scroll starts at the left.
    card_actions.alignment = BoxContainer.ALIGNMENT_CENTER
    card_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card_actions.add_theme_constant_override("separation", 12)
    hand_scroll.add_child(card_actions)

    # Chapter reveal is visual only, and cannot swallow user mouse input.
    intro_title = Label.new()
    intro_title.text = "雨 夜 追 兵" if story_encounter else "断 桥 听 风"
    intro_title.add_theme_font_size_override("font_size", 54)
    intro_title.add_theme_color_override("font_color", UITheme.PAPER)
    intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hud.add_child(intro_title)
    intro_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    intro_title.offset_left = -320.0
    intro_title.offset_right = 320.0
    intro_title.offset_top = -160.0
    intro_title.offset_bottom = -84.0
    intro_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    intro_subtitle = Label.new()
    intro_subtitle.text = "一剑试江湖   ·   水墨武学 / 立体战场"
    intro_subtitle.add_theme_font_size_override("font_size", 20)
    intro_subtitle.add_theme_color_override("font_color", UITheme.GOLD)
    intro_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hud.add_child(intro_subtitle)
    intro_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    intro_subtitle.offset_left = -320.0
    intro_subtitle.offset_right = 320.0
    intro_subtitle.offset_top = -90.0
    intro_subtitle.offset_bottom = -45.0
    intro_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _refresh() -> void:
    # Read priority from the NEW state before choosing hand visibility.
    snap = model.snapshot(observer_id)
    var owner := _decision_owner()
    var owner_actor = model.state.get_actor(owner)
    if owner_actor != null and owner_actor.controller == "PLAYER":
        observer_id = owner
    snap = model.snapshot(observer_id)
    legals = model.legal_actions(owner) if _player_decision() else []
    _report_story_result()
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
    if card_actions == null or command_actions == null:
        return
    for child in card_actions.get_children():
        child.queue_free()
    for child in command_actions.get_children():
        child.queue_free()
    var available: bool = _player_decision() and not bool(snap.get("animation_pending", false)) and str(snap.get("outcome", "playing")) == "playing"
    var owner = model.state.get_actor(_decision_owner())
    var actor_name := str(owner.name) if owner != null else "等待"
    selection_label.text = ("执剑者 · " + actor_name + "    选择招式后点击亮起的目标；右键取消") if available else "静候敌方应变 / 动画结算"
    if not available:
        return

    for card in snap.get("hand", []):
        var uid := str(card.get("uid", card.get("card_id", "")))
        for usage in card.get("usages", []):
            var usage_id := str(usage.get("id", ""))
            if _find_actions(uid, usage_id).is_empty():
                continue
            var cost: Dictionary = usage.get("quoted_cost", {})
            var definition_id := str(card.get("definition_id", card.get("card_id", "")))
            var button := CardUI.make_card(uid, definition_id,
                str(card.get("name", "招式")), str(usage.get("name", usage_id)), cost,
                selected_card_uid == uid and selected_usage_id == usage_id)
            button.set_meta("usage_id", usage_id)
            button.pressed.connect(_select_card.bind(uid, usage_id))
            card_actions.add_child(button)
            _bind_card_feedback(button)

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
        var button := CardUI.make_card(technique_id + ":" + node_id,
            technique_id, "连携续式", node_id, {},
            selected_technique == technique_id and selected_node == node_id)
        button.set_meta("technique_id", technique_id)
        button.set_meta("node_id", node_id)
        button.pressed.connect(_select_technique.bind(technique_id, node_id))
        card_actions.add_child(button)
        _bind_card_feedback(button)

    var commands := {
        "BASIC_GUARD": "守势 · 格挡",
        "END_ACTION": "收势 · 结束行动",
        "PASS_REACTION": "按兵 · 交还响应",
        "PITCH_CARD": "弃牌 · 调息",
        "RESET_TECHNIQUE": "收招 · 复位"
    }
    var command_seen: Dictionary = {}
    var pitch_actions: Array = []
    for action in legals:
        var kind := str(action.get("kind", ""))
        if not commands.has(kind):
            continue
        if kind == "PITCH_CARD":
            pitch_actions.append(action)
            continue
        var key := kind + ":" + str(action.get("card_uid", action.get("technique_id", "")))
        if command_seen.has(key):
            continue
        command_seen[key] = true
        var command_button := Button.new()
        command_button.text = str(commands[kind])
        if kind == "RESET_TECHNIQUE":
            command_button.text = "复位 · " + str(action.get("technique_id", ""))
        UITheme.apply_button(command_button)
        command_button.pressed.connect(_submit_legal.bind(action))
        command_actions.add_child(command_button)
    if not pitch_actions.is_empty():
        # Present one contextual command instead of N technical card-UID rows.
        var pitch_toggle := Button.new()
        pitch_toggle.name = "PitchToggle"
        pitch_toggle.text = "调息 · 弃牌  ▸"
        UITheme.apply_button(pitch_toggle)
        pitch_toggle.pressed.connect(_toggle_pitch_choices.bind(pitch_actions, pitch_toggle))
        command_actions.add_child(pitch_toggle)
    if snap.get("phase", "") == "CLASH" and not command_seen.has("PASS_REACTION:"):
        var pass_button := Button.new()
        pass_button.text = "按兵 · 交还响应"
        UITheme.apply_button(pass_button)
        pass_button.pressed.connect(_submit.bind("PASS_REACTION", {}))
        command_actions.add_child(pass_button)

func _toggle_pitch_choices(actions: Array, toggle: Button) -> void:
    var existing := command_actions.get_node_or_null("PitchChoices")
    if existing != null:
        existing.queue_free()
        toggle.text = "调息 · 弃牌  ▸"
        return
    toggle.text = "调息 · 收起  ▾"
    var choices := VBoxContainer.new()
    choices.name = "PitchChoices"
    choices.add_theme_constant_override("separation", 3)
    command_actions.add_child(choices)
    for action in actions:
        var card_uid := str(action.get("card_uid", ""))
        var card_name := "手牌"
        for card in snap.get("hand", []):
            if str(card.get("uid", card.get("card_id", ""))) == card_uid:
                card_name = str(card.get("name", "手牌"))
                break
        var choice := Button.new()
        choice.text = "弃 · " + card_name
        UITheme.apply_button(choice)
        choice.pressed.connect(_submit_legal.bind(action))
        choices.add_child(choice)

func _bind_card_feedback(button: Button) -> void:
    # Scale changes do not affect the HBox layout or the legal action data.
    button.pivot_offset = Vector2(88, 218)
    button.mouse_entered.connect(_on_card_hover.bind(button, true))
    button.mouse_exited.connect(_on_card_hover.bind(button, false))

func _on_card_hover(button: Button, entering: bool) -> void:
    if not is_instance_valid(button):
        return
    var chosen := _is_selected_card(button)
    button.z_index = 5 if entering or chosen else 0
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_CUBIC)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(button, "scale",
        Vector2.ONE * (1.055 if entering else (1.025 if chosen else 1.0)), 0.14)

func _is_selected_card(button: Button) -> bool:
    if button.has_meta("technique_id"):
        return str(button.get_meta("technique_id")) == selected_technique and str(button.get_meta("node_id")) == selected_node
    return button.has_meta("card_uid") and str(button.get_meta("card_uid")) == selected_card_uid and str(button.get_meta("usage_id")) == selected_usage_id

func _paint_selection() -> void:
    for child in card_actions.get_children():
        if not child is Button:
            continue
        var chosen := _is_selected_card(child)
        UITheme.apply_card(child, chosen)
        if chosen:
            child.z_index = 4
            child.scale = Vector2.ONE * 1.025
        elif not child.is_hovered():
            child.z_index = 0
            child.scale = Vector2.ONE

func _update_card_selection() -> void:
    _paint_selection()

func _select_card(uid: String, usage: String) -> void:
    _clear_selection()
    selected_card_uid = uid
    selected_usage_id = usage
    selected_kind = "PLAY_CARD"
    _update_card_selection()
    _activate_selection()

func _select_technique(technique: String, node: String) -> void:
    _clear_selection()
    selected_technique = technique
    selected_node = node
    selected_kind = "USE_ABILITY"
    _update_card_selection()
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
        command_actions.add_child(button)
    selection_label.text = "已选择招式：点击绿色目标格或角色；右键取消。"
    _paint_selection()
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
    var mode := "雨夜追兵 · 多人交锋" if story_encounter else "断桥论剑 · HD-2D"
    var priority = model.state.get_actor(_decision_owner())
    var active_name := str(priority.name) if priority != null else "等待结算"
    status_label.text = "%s    /    %s    /    第 %d 拍    /    执剑者：%s" % [
        mode, str(snap.get("phase", "")), int(snap.get("global_tick", 0)), active_name]
    if str(snap.get("outcome", "playing")) != "playing":
        status_label.text += "    ·    战斗结束：" + str(snap.get("outcome", ""))
    for actor in snap.get("actors", []):
        var id := int(actor.id)
        if not roster_labels.has(id):
            continue
        var marker := "◆" if id == _decision_owner() else "◇"
        var role := "手动" if str(actor.get("controller", "")) == "PLAYER" else "自动"
        var hp := float(actor.get("hp", 0.0))
        var max_hp := maxf(1.0, float(actor.get("max_hp", 1.0)))
        var qi := float(actor.get("qi", 0.0))
        var gauge := int(actor.get("gauge", 0))
        roster_labels[id].text = "%s %s  ·  %s  /  CTB %d" % [
            marker, str(actor.get("name", "江湖客")), role, gauge]
        roster_labels[id].tooltip_text = "血 %.0f / %.0f  ·  气 %.1f" % [hp, max_hp, qi]
        if roster_bars.has(id):
            var bars: Dictionary = roster_bars[id]
            var hp_bar: ProgressBar = bars["hp"]
            hp_bar.max_value = max_hp
            hp_bar.value = clampf(hp, 0.0, max_hp)
            hp_bar.tooltip_text = "气血 %.0f / %.0f" % [hp, max_hp]
            var qi_bar: ProgressBar = bars["qi"]
            var max_qi := maxf(1.0, maxf(qi, float(actor.get("max_qi", 10.0))))
            qi_bar.max_value = max_qi
            qi_bar.value = clampf(qi, 0.0, max_qi)
            qi_bar.tooltip_text = "真气 %.1f / %.1f" % [qi, max_qi]
    # Reveal situational controls; the idle battlefield has no framed sidebar.
    var in_clash := str(snap.get("phase", "")) == "CLASH"
    var has_commands := command_actions != null and command_actions.get_child_count() > 0
    if context_veil != null:
        context_veil.visible = in_clash or (has_commands and _player_decision())
    if command_scroll != null:
        command_scroll.visible = has_commands and _player_decision()
        command_scroll.offset_top = 87.0 if in_clash else 17.0
    if clash_label != null:
        clash_label.visible = in_clash
    if phase_label != null:
        phase_label.text = "◆  交 锋 应 变" if snap.get("phase", "") == "CLASH" else ("◆  我 方 行 动" if _player_decision() else "◆  敌 方 行 动")
    if clash_label != null:
        var clash: Dictionary = snap.get("clash", {})
        if snap.get("phase", "") == "CLASH":
            clash_label.text = "响应层 %d / 4    ·    Pass %d / 2\n%s持有响应权；可选择合法应对" % [
                clash.get("stack", []).size(), int(clash.get("consecutive_passes", 0)),
                "我方" if _player_decision() else "敌方"]
        else:
            clash_label.text = "走位  /  出招  /  护体  /  连携\n所有指令由原有规则与合法动作校验"

func _process(delta: float) -> void:
    if snap.is_empty():
        return
    elapsed += delta
    if intro_remaining > 0.0:
        intro_remaining = maxf(0.0, intro_remaining - delta)
        var reveal: float = minf(1.0, intro_remaining / 0.65)
        intro_title.modulate.a = reveal
        intro_subtitle.modulate.a = reveal
        intro_title.visible = intro_remaining > 0.0
        intro_subtitle.visible = intro_remaining > 0.0
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
                sprite.position.y = 1.0 + sin(elapsed * 2.5 + float(id) * 1.4) * 0.035
    animation_driver.update(delta, moving)
    if effects_driver != null:
        effects_driver.update(delta)
    for id in cue_remaining.keys():
        cue_remaining[id] = maxf(0.0, float(cue_remaining[id]) - delta)
        if cue_lights.has(id):
            var light: OmniLight3D = cue_lights[id]
            light.light_energy = float(cue_remaining[id]) * 4.0
    if animation_ticket >= 0:
        animation_time -= delta
        # The semantic queue can span several frame boundaries. Its remaining
        # stages must finish even when the initial wall-clock estimate expires.
        if animation_time <= 0.0 and animation_driver.remaining_seconds() <= 0.0:
            var ticket := animation_ticket
            animation_ticket = -1
            _accept(model.acknowledge_animation(ticket))
        return
    if snap.get("outcome", "playing") != "playing":
        return
    var decision_id := int(snap.get("active_id", -1))
    if snap.get("phase", "") == "CLASH":
        decision_id = int(snap.get("clash", {}).get("priority_actor_id", -1))
    var decision_actor = model.state.get_actor(decision_id)
    if decision_actor != null and decision_actor.controller != "PLAYER":
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
    if effects_driver != null:
        effects_driver.handle_events(result.get("events", []), actor_nodes)
    _clear_selection()
    _refresh()
    if snap.get("animation_pending", false):
        animation_ticket = int(result.get("ticket", snap.get("ticket", -1)))
        animation_time = _event_duration(result.get("events", []))
    _refresh_target_markers()
    _update_status()

func _event_duration(_events: Array) -> float:
    # Await the entire semantic event animation queue before acknowledging
    # the model's presentation ticket and letting the next actor act.
    return maxf(0.35, animation_driver.remaining_seconds())

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
    if not _player_decision():
        return
    # Reject stale UI commands; only the authoritative legal set may execute.
    for candidate in model.legal_actions(owner):
        if str(candidate.get("kind", "")) != kind:
            continue
        var matches := true
        for key in params:
            if not candidate.has(key) or candidate[key] != params[key]:
                matches = false
                break
        if matches:
            _accept(model.submit(model.request(kind, owner, params)))
            return

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
                if story_encounter:
                    return
                model.reset(2026)
                animation_driver.reset()
                if effects_driver != null:
                    effects_driver.clear()
                _clear_selection()
                animation_ticket = -1
                _refresh()
                _refresh_target_markers()
                for actor in snap.get("actors", []):
                    actor_nodes[int(actor.id)].position = _world(actor.cell)
            KEY_ESCAPE:
                if story_encounter and snap.get("outcome", "playing") != "playing":
                    get_tree().change_scene_to_file("res://demo_result.tscn")
                elif not story_encounter:
                    get_tree().change_scene_to_file("res://opening.tscn")
