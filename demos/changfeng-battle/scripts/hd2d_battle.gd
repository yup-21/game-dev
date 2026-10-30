extends Node3D
## HD-2D vertical slice. All tactical state and legality remain in BattleModel.
## Run res://battle_hd2d.tscn explicitly; the original 2D scene is untouched.
const Model = preload("res://scripts/battle_model.gd")
const ContinuousSpace = preload("res://scripts/battle_spatial_service.gd")
const ContinuousPreview = preload("res://scripts/continuous_move_preview.gd")
const EnemyAI = preload("res://scripts/enemy_ai.gd")
const Scenery = preload("res://scripts/hd2d_scenery.gd")
const IllustratedMap = preload("res://scripts/illustrated_battle_map.gd")
const UITheme = preload("res://scripts/hd2d_ui_theme.gd")
const CardUI = preload("res://scripts/hd2d_card_ui.gd")
const ArtCatalog = preload("res://scripts/hd2d_art_catalog.gd")
const Animator = preload("res://scripts/hd2d_animation.gd")
const Facing = preload("res://scripts/actor_facing.gd")
const VFX = preload("res://scripts/hd2d_vfx.gd")
const ResponsePolicy = preload("res://scripts/hd2d_response_policy.gd")
const CharacterRegistry = preload("res://scripts/character_registry.gd")
const CharacterCardUI = preload("res://scripts/character_card_ui.gd")
const ChargeRail = preload("res://scripts/hd2d_ctb_rail.gd")
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
var continuous_space
var continuous_preview
var continuous_preview_enabled := false
var illustrated_map: CanvasLayer
var camera: Camera3D
var actor_nodes: Dictionary = {}
var visual_cells: Dictionary = {}
var movement_paths: Dictionary = {}
var continuous_paths: Dictionary = {}
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
var auto_battle := false
var auto_button: Button
var hovered := Vector2i(-1, -1)
var cursor_mesh: MeshInstance3D
var glow_material: StandardMaterial3D
var card_actions: HBoxContainer
var fan_layout_pending := false
var command_actions: VBoxContainer
var command_scroll: ScrollContainer
var context_veil: TextureRect
var charge_rail: Control
var character_card: Control
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
        model.reset(2026, -1, "tingfeng", _quick_character_options())
    observer_id = _first_player_id()
    snap = model.snapshot(observer_id)
    legals = model.legal_actions(_decision_owner())
    _build_world()
    if illustrated_map != null:
        continuous_space = ContinuousSpace.new()
        continuous_preview = ContinuousPreview.new()
        illustrated_map.scene_root.add_child(continuous_preview)
    # 3D terrain, procedural scenery, and far-away backdrop are removed.
    # Only 2D painted ground and 2D sprite action frames are visible.
    effects_driver = VFX.new(self, camera)
    _build_ui()
    _refresh()
    _update_status()

func _quick_character_options() -> Dictionary:
    var configured: Dictionary=CharacterRegistry.new().battle_options([], {0:"shen_changfeng",1:"pursuer_captain"})
    configured["map_definition_path"]="res://data/maps/rainy_bridge.json"
    return configured

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

    # A 2D illustrated image owns the entire battlefield. The camera stays
    # only for compatibility with old 3D animation/effect fixtures.
    illustrated_map = IllustratedMap.new(story_encounter,str(model.state.map_definition_path))
    add_child(illustrated_map)
    for actor in snap.get("actors", []):
        var id := int(actor.id)
        var sprite: Sprite2D = illustrated_map.add_actor(actor, ArtCatalog.sheet_for_actor(id, int(actor.get("team_id", 0)) != 0))
        actor_nodes[id] = illustrated_map.actors[id]
        visual_cells[id] = Vector2i(actor.cell)
        animation_driver.register_actor(id, sprite, Vector2i(actor.get("facing", Vector2i.RIGHT)))
    return

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
    if target_markers.is_empty() and illustrated_map==null:
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
    if illustrated_map!=null:
        illustrated_map.set_highlights(target_cells,animation_ticket<0 and _player_decision() and not auto_battle)
        return
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
    # Current atlases are action-only (6x4), not true four-angle art.
    # Mirror west/east and provide an unambiguous ground-plane pointer
    # for north/south until original directional poses are available.
    var facing_arrow := MeshInstance3D.new()
    facing_arrow.name = "FacingArrow"
    var arrow_mesh := ImmediateMesh.new()
    arrow_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for point in [Vector3(-0.20,0.065,0.13),Vector3(0.20,0.065,0.13),Vector3(0,0.065,0.59)]:
        arrow_mesh.surface_set_normal(Vector3.UP)
        arrow_mesh.surface_add_vertex(point)
    arrow_mesh.surface_end()
    facing_arrow.mesh = arrow_mesh
    var arrow_material := StandardMaterial3D.new()
    arrow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    arrow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    arrow_material.albedo_color = Color("87d4bb") if not enemy else Color("e4ab79")
    facing_arrow.material_override = arrow_material
    facing_arrow.rotation.y = Facing.yaw(Vector2i(actor.get("facing",Vector2i.RIGHT)))
    root.add_child(facing_arrow)
    visual_cells[actor_id] = Vector2i(actor.cell)
    # Legacy 3D geometry is unreachable in illustrated-map mode.
    # Native Sprite2D registration happens in the painted-map branch.
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

    # A small title and muted state caption leave the camera fully visible.
    var ribbon := Control.new()
    ribbon.name = "ChapterRibbon"
    ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(ribbon)
    ribbon.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    ribbon.offset_bottom = 61.0
    _veil(ribbon, preload("res://assets/ui/veil_top.svg"))
    # Standalone filigree keeps the central chapter label readable.
    var title_filagree := _veil(ribbon,
        preload("res://assets/ui/ornaments/chapter_filagree.svg"))
    title_filagree.anchor_left = 0.5
    title_filagree.anchor_right = 0.5
    title_filagree.anchor_top = 0.0
    title_filagree.anchor_bottom = 0.0
    title_filagree.offset_left = -300.0
    title_filagree.offset_right = 300.0
    title_filagree.offset_top = 0.0
    title_filagree.offset_bottom = 54.0
    var heading := Label.new()
    heading.text = "雨夜追兵" if story_encounter else "断桥听风"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 23)
    heading.add_theme_color_override("font_color", UITheme.PAPER)
    heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ribbon.add_child(heading)
    heading.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    heading.offset_top = 8.0
    heading.offset_bottom = 43.0
    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 11)
    status_label.add_theme_color_override("font_color", UITheme.MUTED)
    status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ribbon.add_child(status_label)
    status_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    status_label.offset_left = 15.0
    status_label.offset_right = 510.0
    status_label.offset_top = 13.0
    status_label.offset_bottom = 47.0
    phase_label = Label.new()
    phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    phase_label.add_theme_font_size_override("font_size", 12)
    phase_label.add_theme_color_override("font_color", UITheme.GOLD)
    phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ribbon.add_child(phase_label)
    phase_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    phase_label.offset_left = -380.0
    phase_label.offset_right = -138.0
    phase_label.offset_top = 15.0
    phase_label.offset_bottom = 42.0
    auto_button = Button.new()
    auto_button.name = "AutoBattleToggle"
    auto_button.text = "自动战斗 · 关"
    auto_button.tooltip_text = "托管我方行动；按 A 随时恢复手动"
    ribbon.add_child(auto_button)
    auto_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    auto_button.offset_left = -138.0
    auto_button.offset_right = -12.0
    auto_button.offset_top = 11.0
    auto_button.offset_bottom = 45.0
    UITheme.apply_button(auto_button)
    auto_button.pressed.connect(_toggle_auto_battle)
    help_label = Label.new()
    help_label.text = "左键选目标 · P 自由移步 · C 角色卡 · Q 攻击 · G 格挡 · Space 收势 · Esc 返回"
    help_label.visible = false
    ribbon.add_child(help_label)

    # Team status floats directly over the scene: no per-actor rectangular
    # panels, only portraits and fine health/qi strokes.
    var party := Control.new()
    party.name = "FloatingRoster"
    party.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(party)
    party.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    party.offset_left = 0.0
    party.offset_right = 214.0
    party.offset_top = 75.0
    party.offset_bottom = 459.0
    _veil(party, preload("res://assets/ui/veil_left.svg"))
    var roster_heading := Label.new()
    roster_heading.text = "江湖同行"
    roster_heading.position = Vector2(13, 10)
    roster_heading.size = Vector2(180, 23)
    roster_heading.add_theme_font_size_override("font_size", 13)
    roster_heading.add_theme_color_override("font_color", UITheme.GOLD)
    roster_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
    party.add_child(roster_heading)
    var roster_scroll := ScrollContainer.new()
    roster_scroll.name = "RosterScroll"
    roster_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    party.add_child(roster_scroll)
    roster_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    roster_scroll.offset_left = 12.0
    roster_scroll.offset_right = -9.0
    roster_scroll.offset_top = 37.0
    roster_scroll.offset_bottom = -10.0
    roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    var roster_list := VBoxContainer.new()
    roster_list.name = "ActorList"
    roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    roster_list.add_theme_constant_override("separation", 5)
    roster_scroll.add_child(roster_list)
    for actor in snap.get("actors", []):
        var actor_id := int(actor.id)
        var enemy := int(actor.get("team_id", 0)) != 0
        var actor_row := HBoxContainer.new()
        actor_row.name = "Status_%d" % actor_id
        actor_row.custom_minimum_size = Vector2(0, 65)
        actor_row.add_theme_constant_override("separation", 7)
        # Enemy progress is on the right CTB rail and over each battle sprite.
        # Keep their read-only controls for existing status consumers.
        actor_row.visible = not enemy
        roster_list.add_child(actor_row)
        var avatar_slot := Control.new()
        avatar_slot.custom_minimum_size = Vector2(58, 65)
        actor_row.add_child(avatar_slot)
        var avatar := TextureRect.new()
        avatar.texture = ArtCatalog.avatar(actor_id, enemy)
        avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        avatar.mouse_filter = Control.MOUSE_FILTER_STOP
        avatar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        avatar.tooltip_text = "查看 %s 的角色卡" % str(actor.name)
        avatar.gui_input.connect(_on_roster_avatar_input.bind(actor_id))
        avatar_slot.add_child(avatar)
        avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        avatar.offset_left = 5.0
        avatar.offset_top = 5.0
        avatar.offset_right = -5.0
        avatar.offset_bottom = -5.0
        var portrait_border := _veil(avatar_slot,
            preload("res://assets/ui/ornaments/portrait_frame.svg"))
        portrait_border.name = "PortraitFrame"
        var detail := VBoxContainer.new()
        detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        detail.add_theme_constant_override("separation", 3)
        actor_row.add_child(detail)
        var entry := Label.new()
        entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        entry.add_theme_font_size_override("font_size", 12)
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

    # Contextual commands float beside, never instead of, the CTB rail.
    var context := Control.new()
    context.name = "ContextActions"
    context.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(context)
    context.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    context.offset_left = -336.0
    context.offset_right = -126.0
    context.offset_top = -538.0
    context.offset_bottom = -265.0
    context_veil = _veil(context, preload("res://assets/ui/veil_right.svg"))
    clash_label = Label.new()
    clash_label.name = "ClashDetails"
    clash_label.position = Vector2(11, 10)
    clash_label.size = Vector2(190, 62)
    clash_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    clash_label.add_theme_font_size_override("font_size", 12)
    clash_label.add_theme_color_override("font_color", UITheme.PAPER)
    context.add_child(clash_label)
    command_scroll = ScrollContainer.new()
    command_scroll.name = "ContextScroll"
    context.add_child(command_scroll)
    command_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    command_scroll.offset_left = 11.0
    command_scroll.offset_right = -9.0
    command_scroll.offset_top = 76.0
    command_scroll.offset_bottom = -8.0
    command_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    command_actions = VBoxContainer.new()
    command_actions.name = "CommandActions"
    command_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    command_actions.add_theme_constant_override("separation", 5)
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
    hand_stage.offset_top = -255.0
    hand_stage.offset_bottom = 0.0
    _veil(hand_stage, preload("res://assets/ui/ornaments/hand_fan_tray.svg"))
    var hand_title := Label.new()
    hand_title.text = "武 学"
    hand_title.add_theme_font_size_override("font_size", 15)
    hand_title.add_theme_color_override("font_color", UITheme.GOLD)
    hand_stage.add_child(hand_title)
    hand_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    hand_title.offset_left = 28.0
    hand_title.offset_right = 110.0
    hand_title.offset_top = 11.0
    hand_title.offset_bottom = 36.0
    selection_label = Label.new()
    selection_label.name = "HandInstruction"
    selection_label.text = "选一式，点目标；右键取消。"
    selection_label.add_theme_font_size_override("font_size", 11)
    selection_label.add_theme_color_override("font_color", UITheme.MUTED)
    hand_stage.add_child(selection_label)
    selection_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    selection_label.offset_left = 112.0
    selection_label.offset_right = -140.0
    selection_label.offset_top = 13.0
    selection_label.offset_bottom = 40.0
    var hand_scroll := ScrollContainer.new()
    hand_scroll.name = "HandScroll"
    hand_stage.add_child(hand_scroll)
    hand_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hand_scroll.offset_left = 75.0
    hand_scroll.offset_right = -128.0
    hand_scroll.offset_top = 38.0
    hand_scroll.offset_bottom = -10.0
    hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    card_actions = HBoxContainer.new()
    card_actions.name = "CardActions"
    # Center short hands; once cards overflow, normal scroll starts at the left.
    card_actions.alignment = BoxContainer.ALIGNMENT_CENTER
    card_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card_actions.add_theme_constant_override("separation", -12)
    hand_scroll.add_child(card_actions)
    card_actions.sort_children.connect(_request_fan_layout)

    # The original CTB is a real vertical charge gauge, not a stack of
    # decorative portraits or a second turn-order model.
    charge_rail = ChargeRail.new()
    charge_rail.name = "ChargeRail"
    hud.add_child(charge_rail)
    charge_rail.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
    charge_rail.offset_left = -116.0
    charge_rail.offset_right = -8.0
    charge_rail.offset_top = 63.0
    charge_rail.offset_bottom = -131.0

    character_card = CharacterCardUI.new()
    hud.add_child(character_card)
    character_card.switch_requested.connect(_on_character_school_switch)

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

func _request_fan_layout() -> void:
    # Container positioning is authoritative. Rotation and slight vertical
    # offsets only change presentation, not card order or scroll coordinates.
    if fan_layout_pending:
        return
    fan_layout_pending = true
    call_deferred("_layout_fan_cards")

func _layout_fan_cards() -> void:
    fan_layout_pending = false
    if card_actions == null or not is_instance_valid(card_actions):
        return
    var cards: Array[Button] = []
    for child in card_actions.get_children():
        if child is Button and not child.is_queued_for_deletion():
            cards.append(child)
    var midpoint := (float(cards.size()) - 1.0) * 0.5
    for i in range(cards.size()):
        var card := cards[i]
        var spread := float(i) - midpoint
        card.pivot_offset = Vector2(card.size.x * 0.5, card.size.y)
        card.rotation_degrees = clampf(spread * 5.2, -11.5, 11.5)
        card.position.y = absf(spread) * 5.0 - (15.0 if _is_selected_card(card) else 0.0)
        card.set_meta("fan_angle", card.rotation_degrees)

func _on_roster_avatar_input(event: InputEvent, id: int) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _open_character_card(id)

func _toggle_auto_battle() -> void:
    _set_auto_battle(not auto_battle)

func _set_auto_battle(enabled: bool) -> void:
    if auto_battle == enabled:
        return
    auto_battle = enabled
    ai_wait = 0.0
    _clear_selection()
    if enabled and character_card != null and character_card.visible:
        character_card.call("close_card")
    _rebuild_actions()
    _refresh_target_markers()
    _update_status()

func _open_character_card(id: int) -> void:
    if character_card != null:
        character_card.call("open_actor",model,id)

func _on_character_school_switch(id: int, school_id: String) -> void:
    if character_card == null or not character_card.visible:
        return
    if id != _decision_owner() or not _player_decision():
        return
    character_card.call("close_card")
    _submit("SWITCH_SCHOOL",{"school_id":school_id})

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

func _unavailable_card_hint(card: Dictionary, phase: String) -> String:
    if phase == "CLASH":
        return "交锋中暂无合法应变；仍然保留已抽到的手牌。"
    if phase != "ACTION":
        return "等待当前角色行动；手牌不会被丢弃。"
    for usage in card.get("usages", []):
        if str(usage.get("timing", "")) == "ACTION" and str(usage.get("target", {}).get("kind", "")) == "enemy_actor":
            return "已抽到攻击招式。当前没有合法攻击目标；靠近敌人并检查内息和攻击条件。"
    return "已抽到此招，当前不满足使用时机、费用或目标条件。"

func _add_visible_hand_card(card: Dictionary, usage: Dictionary, playable: bool) -> void:
    var uid := str(card.get("uid", card.get("card_id", "")))
    var usage_id := str(usage.get("id", ""))
    var definition_id := str(card.get("definition_id", ""))
    var cost: Dictionary = usage.get("quoted_cost", {})
    var button := CardUI.make_card(uid, definition_id,
        str(card.get("name", "招式")), str(usage.get("name", usage_id)), cost,
        playable and selected_card_uid == uid and selected_usage_id == usage_id)
    button.set_meta("usage_id", usage_id)
    button.set_meta("display_only", not playable)
    if playable:
        button.pressed.connect(_select_card.bind(uid, usage_id))
        _bind_card_feedback(button)
    else:
        button.disabled = true
        button.modulate = Color(0.75, 0.80, 0.82, 0.87)
        button.tooltip_text += "\n" + _unavailable_card_hint(card, str(snap.get("phase", "")))
    card_actions.add_child(button)

func _rebuild_actions() -> void:
    if card_actions == null or command_actions == null:
        return
    for child in card_actions.get_children():
        child.queue_free()
    for child in command_actions.get_children():
        child.queue_free()
    var available: bool = _player_decision() and not auto_battle and not bool(snap.get("animation_pending", false)) and str(snap.get("outcome", "playing")) == "playing"
    var owner = model.state.get_actor(_decision_owner())
    var actor_name := str(owner.name) if owner != null else "等待"
    var pass_only := str(snap.get("phase", "")) == "CLASH" and ResponsePolicy.should_auto_pass(
        "CLASH", false, legals)
    # Never use legal_actions as the source of visible hand cards. That would
    # hide drawn attacks when the opponent starts outside their attack range.
    var displayed_count := 0
    var playable_count := 0
    for card in snap.get("hand", []):
        var uid := str(card.get("uid", card.get("card_id", "")))
        var displayed := false
        if available and not pass_only:
            for usage in card.get("usages", []):
                if _find_actions(uid, str(usage.get("id", ""))).is_empty():
                    continue
                _add_visible_hand_card(card, usage, true)
                displayed = true
                playable_count += 1
        if not displayed:
            # One disabled tile per physical card, even if it defines several
            # usages. Prefer the ACTION face over reaction-only alternatives.
            var choices: Array = card.get("usages", [])
            if choices.is_empty():
                continue
            var fallback: Dictionary = choices[0]
            for usage in choices:
                if str(usage.get("timing", "")) == "ACTION":
                    fallback = usage
                    break
            _add_visible_hand_card(card, fallback, false)
        displayed_count += 1
    var hint := "%s · 手牌 %d 张" % [actor_name, displayed_count]
    if auto_battle:
        hint += "    自动托管中 · 按 A 恢复手动"
    elif available and not pass_only:
        hint += "    选择亮起的招式，再点击目标" if playable_count > 0 else "    灰色牌已抽到，靠近目标或满足条件后可出"
    else:
        hint += "    当前等待应变／动画，手牌仍保留"
    selection_label.text = hint
    _request_fan_layout()
    if not available or pass_only:
        return

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
        var technique_def: Dictionary = model.techniques.definitions.get(technique_id,{})
        var stage_def: Dictionary = model.techniques.node(owner,technique_id,node_id)
        var button := CardUI.make_card(technique_id + ":" + node_id,
            "tf_change" if technique_id == "tf_change_stage" else technique_id,
            str(technique_def.get("name","武学续式")),
            str(stage_def.get("name",node_id)),
            model.techniques.cost(owner,technique_id,node_id),
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
        "RESET_TECHNIQUE": "收招 · 复位",
        "SWITCH_SCHOOL": "切换武学"
    }
    var command_seen: Dictionary = {}
    var pitch_actions: Array = []
    var school_switch_available := false
    for action in legals:
        var kind := str(action.get("kind", ""))
        if not commands.has(kind):
            continue
        if kind == "PITCH_CARD":
            pitch_actions.append(action)
            continue
        if kind == "SWITCH_SCHOOL":
            school_switch_available = true
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
    if school_switch_available:
        var schools_button := Button.new()
        schools_button.name = "SwitchSchoolMenu"
        schools_button.text = "武学 · 切换  ▸"
        UITheme.apply_button(schools_button)
        schools_button.pressed.connect(_open_character_card.bind(_decision_owner()))
        command_actions.add_child(schools_button)
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
    button.pivot_offset = Vector2(button.custom_minimum_size.x * 0.5, button.custom_minimum_size.y)
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
    _request_fan_layout()

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
    for key in ["card_uid", "card_id", "usage_id", "technique_id", "node_id", "target_cell", "target_id", "link_id", "school_id"]:
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
    var school_name := str(priority.school_name) if priority != null else ""
    var stance_ready: bool = priority != null and priority.technique_states.has("tf_change_stage") and str(priority.technique_states.tf_change_stage.node) == "ready"
    status_label.text = "第 %d 拍  ·  %s%s" % [
        int(snap.get("global_tick", 0)), active_name,
        "  ◈ 变锋待发" if stance_ready else ""]
    if auto_button != null:
        auto_button.text = "自动战斗 · 开" if auto_battle else "自动战斗 · 关"
    status_label.tooltip_text = "%s / %s / %s" % [mode,
        str(snap.get("phase", "")), school_name]
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
        roster_labels[id].text = "%s %s" % [marker, str(actor.get("name", "江湖客"))]
        roster_labels[id].tooltip_text = "%s  ·  集气 %d\n血 %.0f / %.0f  ·  气 %.1f" % [role, gauge, hp, max_hp, qi]
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
    if charge_rail != null:
        charge_rail.call("set_state", snap.get("actors", []), _decision_owner())
    # Reveal situational controls; the idle battlefield has no framed sidebar.
    var in_clash := str(snap.get("phase", "")) == "CLASH"
    var has_commands := command_actions != null and command_actions.get_child_count() > 0
    if context_veil != null:
        context_veil.visible = in_clash or (has_commands and _player_decision())
    if command_scroll != null:
        command_scroll.visible = has_commands and _player_decision()
        command_scroll.offset_top = 78.0 if in_clash else 12.0
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

func _auto_pass_unavailable_reactions() -> bool:
    # Work entirely through the authoritative, versioned submit pipeline.
    # Both human and AI participants are skipped when they have no viable
    # response card or technique; do not consume time for an empty pass.
    if str(snap.get("phase", "")) != "CLASH" or animation_ticket >= 0:
        return false
    var owner := _decision_owner()
    var legal: Array = model.legal_actions(owner)
    if not ResponsePolicy.should_auto_pass("CLASH",
            bool(model.state.animation_pending), legal):
        return false
    var result: Dictionary = model.submit(model.request("PASS_REACTION", owner))
    if not bool(result.get("success", false)):
        push_warning("Unable to auto-pass unavailable reaction: " + str(result.get("message", "")))
        return false
    # Normal-pass events contain only PRIORITY_PASSED. When this is the
    # second pass, combat resolution can emit damage/attack events: preserve
    # those animation tickets so the result is still shown in the arena.
    var presentation_needed := false
    for event in result.get("events", []):
        if str(event.get("type", "")) != "PRIORITY_PASSED":
            presentation_needed = true
            break
    _accept(result)
    if not presentation_needed and bool(model.state.animation_pending):
        var ticket := int(result.get("ticket", -1))
        var acknowledged: Dictionary = model.acknowledge_animation(ticket)
        if bool(acknowledged.get("success", false)):
            animation_ticket = -1
            animation_time = 0.0
            _accept(acknowledged)
    return true

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
    _update_continuous_preview()
    var moving: Dictionary = {}
    for actor in snap.get("actors", []):
        var id := int(actor.id)
        if actor_nodes.has(id):
            var node: Node2D = actor_nodes[id] if illustrated_map != null else null
            if illustrated_map != null:
                if continuous_paths.has(id):
                    var free_steps: Array = continuous_paths[id]
                    var next_position: Vector2 = Vector2(free_steps[0])
                    if node.position.distance_to(next_position) <= 1.0:
                        free_steps.pop_front()
                    else:
                        var heading: Vector2 = next_position - node.position
                        animation_driver.set_facing(id, Facing.from_delta(Vector2i(roundi(heading.x), roundi(heading.y)), animation_driver.facing_for(id)))
                        node.position = node.position.move_toward(next_position, delta * 160.0)
                        if node.position.distance_to(next_position) <= 1.0:
                            node.position = next_position
                            free_steps.pop_front()
                    if free_steps.is_empty():
                        continuous_paths.erase(id)
                        visual_cells[id] = Vector2i(actor.cell)
                    else:
                        continuous_paths[id] = free_steps
                    moving[id] = continuous_paths.has(id)
                    continue
                var path2: Array = movement_paths.get(id, [])
                var dest2: Vector2 = Vector2(actor.get("position", illustrated_map.point_for_cell(Vector2i(actor.cell))))
                if not path2.is_empty():
                    var step2 := Vector2i(path2[0])
                    animation_driver.set_facing(id, Facing.from_delta(step2 - Vector2i(visual_cells.get(id, actor.cell)), animation_driver.facing_for(id)))
                    dest2 = illustrated_map.point_for_cell(step2)
                node.position = node.position.move_toward(dest2, delta * 160.0)
                var walking2 := node.position.distance_to(dest2) > 1.0
                if not walking2 and not path2.is_empty():
                    node.position = dest2
                    visual_cells[id] = Vector2i(path2.pop_front())
                    if path2.is_empty(): movement_paths.erase(id)
                    else: movement_paths[id] = path2
                moving[id] = walking2 or not path2.is_empty()
                continue
            var legacy_node: Node3D = actor_nodes[id]
            var path: Array = movement_paths.get(id,[])
            var destination := _world(Vector2i(actor.cell))
            if not path.is_empty():
                var next_cell: Vector2i=Vector2i(path[0])
                var previous_cell: Vector2i=Vector2i(visual_cells.get(id,Vector2i(actor.cell)))
                animation_driver.set_facing(id,Facing.from_delta(next_cell-previous_cell,animation_driver.facing_for(id)))
                destination=_world(next_cell)
            legacy_node.position = legacy_node.position.move_toward(destination, delta * 5.5)
            var still_moving: bool=legacy_node.position.distance_to(destination)>0.035
            if not still_moving and not path.is_empty():
                legacy_node.position=destination
                visual_cells[id]=Vector2i(path.pop_front())
                if path.is_empty(): movement_paths.erase(id)
                else: movement_paths[id]=path
            moving[id] = still_moving or not path.is_empty()
            var sprite: Sprite3D = legacy_node.get_node_or_null("Sprite3D") as Sprite3D
            if sprite != null:
                sprite.position.y = 1.0 + sin(elapsed * 2.5 + float(id) * 1.4) * 0.035
    animation_driver.update(delta, moving)
    if illustrated_map != null:
        for actor in snap.get("actors", []):
            var id := int(actor.id)
            var role: Node2D = actor_nodes.get(id, null)
            if role != null:
                role.visible = float(actor.hp) > 0
                role.z_index = clampi(roundi(role.position.y / 20.0), 0, 100)
    for id in actor_nodes:
        var arrow: Node3D=actor_nodes[id].get_node_or_null("FacingArrow") if illustrated_map == null else null
        if arrow != null:
            arrow.rotation.y=Facing.yaw(animation_driver.facing_for(int(id)))
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
        if animation_time <= 0.0 and animation_driver.remaining_seconds() <= 0.0 and continuous_paths.is_empty():
            var ticket := animation_ticket
            animation_ticket = -1
            _accept(model.acknowledge_animation(ticket))
        return
    if snap.get("outcome", "playing") != "playing":
        return
    if character_card != null and character_card.visible:
        return
    # Resolve up to both priority passes without any human prompt or AI
    # thinking delay. Stop immediately if damage/response animation begins.
    for _auto_step in range(2):
        if not _auto_pass_unavailable_reactions():
            break
        if animation_ticket >= 0:
            return
    var decision_id := int(snap.get("active_id", -1))
    if snap.get("phase", "") == "CLASH":
        decision_id = int(snap.get("clash", {}).get("priority_actor_id", -1))
    var decision_actor = model.state.get_actor(decision_id)
    if decision_actor != null and (decision_actor.controller != "PLAYER" or auto_battle):
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
    # Presentation follows each real path waypoint, rather than the straight
    # chord between old and final grid cells. Facing tracks each segment.
    for event in result.get("events", []):
        if str(event.get("type", "")) == "MOVE":
            var id: int=int(event.get("actor_id",-1))
            if actor_nodes.has(id):
                continuous_paths.erase(id)
                visual_cells[id]=Vector2i(event.get("from",Vector2i.ZERO))
                movement_paths[id]=event.get("path",[]).duplicate()
        elif str(event.get("type", "")) == "MOVE_FREE":
            var id: int=int(event.get("actor_id",-1))
            if actor_nodes.has(id) and illustrated_map != null:
                movement_paths.erase(id)
                var steps: Array = []
                for point in event.get("path", PackedVector2Array()):
                    steps.append(Vector2(point))
                if not steps.is_empty():
                    steps.pop_front()
                if not steps.is_empty():
                    continuous_paths[id] = steps
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
        if illustrated_map!=null and id>=0:
            illustrated_map.pulse_actor(id)
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
    if auto_battle or animation_ticket >= 0:
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
    # Movement always requires a real target. The shared optional-cell
    # sentinel (-1,-1) must never choose the first legal MOVE when the user
    # clicks blocked water, cliff faces or outside the calibrated grid.
    if kind == "MOVE" and cell.x < 0:
        return {}
    for action in legals:
        if str(action.get("kind", "")) != kind:
            continue
        if cell.x >= 0 and action.get("target_cell", Vector2i(-2, -2)) != cell:
            continue
        return action
    return {}

func _hover_cell() -> Vector2i:
    var mouse := get_viewport().get_mouse_position()
    if illustrated_map!=null:
        return illustrated_map.cell_from_screen(mouse,snap.get("terrain",{}))
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
    if continuous_preview_enabled and selected_kind.is_empty():
        usable = false
    if illustrated_map!=null:
        illustrated_map.set_cursor(hovered,usable and animation_ticket<0)
        return
    cursor_mesh.visible = usable and animation_ticket < 0
    if cursor_mesh.visible:
        cursor_mesh.position = _world(hovered) + Vector3(0, 0.13, 0)

func _update_continuous_preview() -> void:
    if not continuous_preview_enabled or continuous_space == null or continuous_preview == null or not _player_decision() or animation_ticket >= 0:
        if continuous_preview != null:
            continuous_preview.clear_preview()
        return
    if not selected_kind.is_empty():
        continuous_preview.clear_preview()
        return
    var actor = model.state.get_actor(_decision_owner())
    if actor == null:
        continuous_preview.clear_preview()
        return
    var goal: Vector2 = get_viewport().get_mouse_position()
    var path: PackedVector2Array = model.preview_free_path(actor.id, goal)
    if path.size() < 2:
        continuous_preview.clear_preview()
        return
    var cost: float = model.state.spatial.path_length(path)
    var unit: float = maxf(model.state.spatial.bake.step.x, model.state.spatial.bake.step.y)
    var units: int = ceili((cost - 0.0001) / unit)
    var remaining: int = int(actor.stats.get("move_budget", 2)) - actor.normal_moves_used
    var reachable: bool = units > 0 and units <= remaining and actor.qi_u >= units * 10000
    continuous_preview.show_preview(path, cost, reachable)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
        continuous_preview_enabled = not continuous_preview_enabled
        if not continuous_preview_enabled and continuous_preview != null:
            continuous_preview.clear_preview()
        get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_A:
        _toggle_auto_battle()
        get_viewport().set_input_as_handled()
        return
    if character_card != null and character_card.visible:
        if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
            character_card.call("close_card")
            get_viewport().set_input_as_handled()
        return
    if auto_battle and event is InputEventMouseButton:
        return
    if auto_battle and event is InputEventKey and event.keycode in [KEY_C, KEY_Q, KEY_G, KEY_SPACE, KEY_ENTER]:
        return
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
        elif continuous_preview_enabled and illustrated_map != null and _player_decision():
            _submit("MOVE_FREE", {"target_position": get_viewport().get_mouse_position()})
            get_viewport().set_input_as_handled()
        else:
            var move := _legal("MOVE", _hover_cell())
            if not move.is_empty():
                _submit("MOVE", {"target_cell": move.target_cell})
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_F3:
                if illustrated_map != null:
                    illustrated_map.set_debug_grid(not illustrated_map.debug_grid.visible)
            KEY_C:
                _open_character_card(observer_id)
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
                model.reset(2026, -1, "tingfeng", _quick_character_options())
                _set_auto_battle(false)
                animation_driver.reset()
                if effects_driver != null:
                    effects_driver.clear()
                _clear_selection()
                animation_ticket = -1
                _refresh()
                _refresh_target_markers()
                movement_paths.clear()
                continuous_paths.clear()
                for actor in snap.get("actors", []):
                    var id: int=int(actor.id)
                    actor_nodes[id].position = illustrated_map.point_for_cell(Vector2i(actor.cell)) if illustrated_map != null else _world(actor.cell)
                    visual_cells[id]=Vector2i(actor.cell)
                    animation_driver.set_facing(id,Vector2i(actor.facing))
                    var arrow: Node3D=actor_nodes[id].get_node_or_null("FacingArrow") if illustrated_map == null else null
                    if arrow != null: arrow.rotation.y=Facing.yaw(Vector2i(actor.facing))
            KEY_ESCAPE:
                if story_encounter and snap.get("outcome", "playing") != "playing":
                    get_tree().change_scene_to_file("res://demo_result.tscn")
                elif not story_encounter:
                    get_tree().change_scene_to_file("res://opening.tscn")
