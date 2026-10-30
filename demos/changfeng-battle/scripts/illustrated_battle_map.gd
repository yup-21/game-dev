extends CanvasLayer
## Painted 2D battle. A versioned MapBake, not a perspective camera, is
## authoritative for ALL tile footprints, mouse hits and character feet.
const Art = preload("res://scripts/hd2d_art_catalog.gd")
const MapBake = preload("res://scripts/map_bake.gd")
var bake
var picture: TextureRect
var actors: Dictionary = {}
var lights: Dictionary = {}
var marks: Dictionary = {}
var selection: Polygon2D
var scene_root: Node2D
var debug_grid: Node2D

func _init(_story_battle: bool = false, map_path: String = MapBake.DEFAULT_PATH) -> void:
    layer = -10
    name = "IllustratedBattleMap"
    bake = MapBake.new(map_path if not map_path.is_empty() else MapBake.DEFAULT_PATH)
    if not bake.error.is_empty():
        push_error("Map projection failed: " + bake.error)
        return
    scene_root = Node2D.new()
    scene_root.name = "FlatBattle"
    add_child(scene_root)
    picture = TextureRect.new()
    picture.name = "FullPaintedTerrain"
    picture.size = bake.viewport_size * bake.image_scale
    picture.position = (bake.viewport_size - picture.size) * 0.5
    picture.pivot_offset = picture.size * 0.5
    # Rotate only the illustration to level the slant of the wooden bridge.
    # Gameplay cells remain rectangular and parallel to the screen axes.
    picture.rotation_degrees = bake.image_rotation_degrees
    picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    picture.stretch_mode = TextureRect.STRETCH_SCALE
    picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if ResourceLoader.exists(bake.image_path):
        picture.texture = load(bake.image_path)
    else:
        picture.texture = Art.scenery("rainy_bridge")
    scene_root.add_child(picture)

    debug_grid = Node2D.new()
    debug_grid.name = "BakedGridDebug"
    debug_grid.visible = false
    scene_root.add_child(debug_grid)
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
        scene_root.add_child(marker)
        marks[cell] = marker
    selection = _ellipse(Color(0.37,0.97,0.73,0.52),32,14)
    selection.name = "MoveCursor"
    selection.visible = false
    scene_root.add_child(selection)

func _ellipse(color: Color, rx: float, ry: float) -> Polygon2D:
    var node := Polygon2D.new()
    node.color=color
    var points := PackedVector2Array()
    for i in range(24):
        var theta := TAU * float(i)/24.0
        points.append(Vector2(cos(theta)*rx,sin(theta)*ry))
    node.polygon=points
    return node

func set_debug_grid(enabled: bool) -> void:
    if debug_grid != null:
        debug_grid.visible=enabled

func point_for_cell(cell: Vector2i) -> Vector2:
    return bake.cell_center(cell)

func point_for_grid(grid: Vector2) -> Vector2:
    return bake.grid_position(grid)

func cell_from_screen(screen: Vector2, _board: Dictionary = {}) -> Vector2i:
    # Do not find a nearest passable cell: clicking a river/rock must not
    # snap to some adjacent path. A tile's authored screen rectangle owns it.
    return bake.cell_at_screen(screen,true)

func add_actor(actor: Dictionary, atlas: Texture2D) -> void:
    var id: int=int(actor.id)
    var node := Node2D.new()
    node.name="Role_%d" % id
    node.position=point_for_cell(Vector2i(actor.cell))
    scene_root.add_child(node)
    var foot := _ellipse(Color(0.35,0.87,0.68,0.50) if int(actor.team_id)==0 else Color(0.96,0.49,0.37,0.51),23,11)
    foot.name="FootAnchor"
    node.add_child(foot)
    var sprite := Sprite2D.new()
    sprite.name="ActionSprite"
    sprite.texture=atlas
    sprite.hframes=6
    sprite.vframes=4
    sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
    sprite.scale=Vector2(0.53,0.53)
    sprite.offset=Vector2(0,-102)
    node.add_child(sprite)
    var nameplate := Label.new()
    nameplate.name="RoleName"
    nameplate.text=str(actor.name)
    nameplate.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    nameplate.position=Vector2(-88,-151)
    nameplate.size=Vector2(176,26)
    nameplate.add_theme_color_override("font_color",Color("dcefe0") if int(actor.team_id)==0 else Color("f2c7b7"))
    nameplate.add_theme_font_size_override("font_size",17)
    node.add_child(nameplate)
    actors[id]=node
    lights[id]=0.0

func update_actor(id: int, grid: Vector2, frame: int, flip: bool, alive: bool) -> void:
    var node: Node2D=actors.get(id,null)
    if node==null: return
    node.position=point_for_grid(grid)
    node.visible=alive
    node.z_index=clampi(roundi(node.position.y/20.0),0,100)
    var sprite: Sprite2D=node.get_node("ActionSprite") as Sprite2D
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
