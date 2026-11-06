extends CanvasLayer
## Painted 2D battle. A versioned MapBake, not a perspective camera, is
## authoritative for ALL tile footprints, mouse hits and character feet.
const MapBake = preload("res://scripts/map_bake.gd")
const CombatScale = preload("res://scripts/combat_scale.gd")
const BattleActorScene = preload("res://scenes/actors/battle_actor.tscn")
## Art calibration is still owned by the map Resource. These optional nudges
## are saved on the PackedScene and are editable without touching battle rules.
@export var illustration_nudge: Vector2 = Vector2.ZERO
@export_range(0.25, 4.0, 0.01) var illustration_scale: float = 1.0
@export_range(-180.0, 180.0, 0.1) var illustration_rotation_degrees: float = 0.0
var bake
var picture: TextureRect
var actors: Dictionary = {}
var lights: Dictionary = {}
var marks: Dictionary = {}
var selection: Polygon2D
var scene_root: Node2D
var debug_grid: Node2D

func configure(map_path: String = MapBake.DEFAULT_PATH) -> void:
    bake = MapBake.new(map_path if not map_path.is_empty() else MapBake.DEFAULT_PATH)
    if not bake.error.is_empty():
        push_error("Map projection failed: " + bake.error)
        return
    scene_root = get_node("FlatBattle") as Node2D
    var art_group: Node2D = scene_root.get_node("ArtCalibration") as Node2D
    picture = art_group.get_node("FullPaintedTerrain") as TextureRect
    # All four painted layers exist in the .tscn for Godot visual editing.
    # An encounter selects textures, never creates or replaces authored nodes.
    if bake.scene_art != null:
        picture.texture = bake.scene_art.background
    else:
        picture.texture = ResourceLoader.load(bake.image_path, "Texture2D") as Texture2D
    if picture.texture == null:
        push_error("Required battle map artwork missing: " + bake.image_path)
        return
    for name in ["FullPaintedTerrain", "GroundArt", "ForegroundOcclusion", "WeatherOverlay"]:
        var layer_node: TextureRect = art_group.get_node(name) as TextureRect
        var texture: Texture2D = picture.texture
        if name != "FullPaintedTerrain":
            texture = null
            if bake.scene_art != null:
                match name:
                    "GroundArt": texture = bake.scene_art.ground
                    "ForegroundOcclusion": texture = bake.scene_art.foreground
                    "WeatherOverlay": texture = bake.scene_art.weather
        layer_node.texture = texture
        layer_node.visible = texture != null
    # The projection Resource determines the overall calibration, while each
    # child TextureRect keeps its Godot-authored position, size and pivot.
    var reference_size := Vector2(1600, 1000)
    var painted_size: Vector2 = bake.viewport_size * bake.image_scale * illustration_scale
    art_group.scale = painted_size / reference_size
    art_group.rotation_degrees = bake.image_rotation_degrees + illustration_rotation_degrees
    var centre: Vector2 = bake.viewport_size * 0.5 + illustration_nudge
    art_group.position = centre - (painted_size * 0.5).rotated(deg_to_rad(art_group.rotation_degrees))
    debug_grid = scene_root.get_node("BakedGridDebug") as Node2D
    var marker_layer: Node2D = scene_root.get_node("LegalMarkers") as Node2D
    for generated in debug_grid.get_children():
        generated.free()
    for generated in marker_layer.get_children():
        generated.free()
    marks.clear()
    if bake.polygon_mode and not bake.walkable_outline.is_empty():
        var contour := Line2D.new()
        contour.name = "PaintedWalkableBoundary"
        contour.points = bake.walkable_outline.duplicate()
        contour.add_point(bake.walkable_outline[0])
        contour.width = 3.0
        contour.default_color = Color(0.98, 0.90, 0.30, 0.94)
        contour.antialiased = true
        debug_grid.add_child(contour)
    for key in bake.tiles:
        var cell: Vector2i = key
        var tile: Dictionary = bake.tiles[cell]
        var area: Rect2 = tile.bounds
        var wire := Line2D.new()
        var outline: PackedVector2Array = bake.cell_polygon(cell)
        outline.append(outline[0])
        wire.points = outline
        wire.width = 1.25
        wire.default_color = Color(0.28,0.96,0.65,0.87) if tile.walkable else Color(0.98,0.39,0.27,0.85)
        debug_grid.add_child(wire)
        var fill := Polygon2D.new()
        fill.polygon = bake.cell_polygon(cell)
        fill.color = Color(0.21,0.82,0.62,0.08) if tile.walkable else Color(0.92,0.24,0.20,0.16)
        debug_grid.add_child(fill)
        var text := Label.new()
        text.text = "%d,%d" % [cell.x,cell.y]
        text.position = area.position + Vector2(3,2)
        text.add_theme_font_size_override("font_size",11)
        text.add_theme_color_override("font_color",Color.WHITE)
        debug_grid.add_child(text)
        var marker := Polygon2D.new()
        marker.name = "Legal_%d_%d" % [cell.x,cell.y]
        marker.position = tile.foot_anchor
        marker.polygon = PackedVector2Array([
            -bake.step*0.43, Vector2(bake.step.x*0.43,-bake.step.y*0.43),
            bake.step*0.43,Vector2(-bake.step.x*0.43,bake.step.y*0.43)])
        marker.color = Color(0.39,0.97,0.69,0.25)
        marker.visible = false
        marker_layer.add_child(marker)
        marks[cell] = marker
    selection = scene_root.get_node("MoveCursor") as Polygon2D
    selection.visible = false

func set_weather_enabled(enabled: bool) -> void:
    var overlay := scene_root.get_node_or_null("ArtCalibration/WeatherOverlay") if scene_root != null else null
    if overlay != null:
        overlay.visible = enabled

func set_debug_grid(enabled: bool) -> void:
    if debug_grid != null:
        debug_grid.visible=enabled

func point_for_cell(cell: Vector2i) -> Vector2:
    return bake.cell_center(cell)

func point_for_grid(grid: Vector2) -> Vector2:
    return bake.grid_position(grid)

func to_battle_point(screen: Vector2) -> Vector2:
    # Camera shake offsets the CanvasLayer world. Translate pointer intent
    # to the same unshaken feet coordinate space as MapBake/BattleModel.
    return screen - scene_root.position

func cell_from_screen(screen: Vector2, _board: Dictionary = {}) -> Vector2i:
    # Do not snap blocked terrain to any nearby traversable cell.
    return bake.cell_at_screen(to_battle_point(screen), true)

func add_actor(actor: Dictionary, atlas: Texture2D) -> Sprite2D:
    var id: int=int(actor.id)
    var node: Node2D = BattleActorScene.instantiate()
    node.name="Role_%d" % id
    node.position=point_for_cell(Vector2i(actor.cell))
    scene_root.add_child(node)
    var foot: Polygon2D = node.get_node("FootAnchor")
    foot.color = Color(0.35,0.87,0.68,0.50) if int(actor.team_id)==0 else Color(0.96,0.49,0.37,0.51)
    var sprite: Sprite2D = node.get_node("ActionSprite")
    sprite.texture=atlas
    sprite.hframes=6
    sprite.vframes=4
    var nameplate: Label = node.get_node("RoleName")
    nameplate.text=str(actor.name)
    nameplate.add_theme_color_override("font_color",Color("dcefe0") if int(actor.team_id)==0 else Color("f2c7b7"))
    actors[id]=node
    lights[id]=0.0
    return sprite

func update_actor(id: int, grid: Vector2, frame: int, flip: bool, alive: bool) -> void:
    var node: Node2D=actors.get(id,null)
    if node==null: return
    node.position=point_for_grid(grid)
    node.visible=alive
    node.z_index=clampi(roundi(node.position.y/20.0),0,100)
    var sprite: Sprite2D=node.get_node("ActionSprite") as Sprite2D
    var native: AnimatedSprite2D = sprite.get_node_or_null("NativeFrames")
    if native != null and native.sprite_frames != null:
        var count: int = native.sprite_frames.get_frame_count(native.animation)
        if count > 0:
            native.frame = clampi(frame, 0, count - 1)
        native.flip_h = flip
    else:
        sprite.frame=frame
    sprite.flip_h=flip
    sprite.modulate=Color(1.0,0.88,0.65) if float(lights.get(id,0.0))>0 else Color.WHITE

func set_highlights(cells: Dictionary, show: bool) -> void:
    for cell in marks:
        var mark: Polygon2D=marks[cell]
        mark.visible=show and cells.has(cell) and bake.is_walkable(cell)

func set_cursor(cell: Vector2i, valid: bool) -> void:
    selection.visible=valid and bake.is_walkable(cell)
    if selection.visible: selection.position=point_for_cell(cell)

func pulse_actor(id: int) -> void:
    if actors.has(id): lights[id]=0.18

func _process(delta: float) -> void:
    for id in lights:
        lights[id]=maxf(0.0,float(lights[id])-delta)
