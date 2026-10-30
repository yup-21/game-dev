extends CanvasLayer
## Flat 2D illustrated battle presentation. No terrain meshes or 3D
## backdrop are used for the player-visible battlefield.
## The 15x10 logical BattleModel grid is mapped to painterly foot anchors.
const Art = preload("res://scripts/hd2d_art_catalog.gd")
const BridgeLayout = preload("res://scripts/rainy_bridge_layout.gd")
const STORY_MAP = BridgeLayout.ART_PATH
const PREVIEW_MAP = BridgeLayout.ART_PATH
const VIEW = BridgeLayout.CANVAS_SIZE
var picture: TextureRect
var actors: Dictionary = {}
var lights: Dictionary = {}
var marks: Dictionary = {}
var selection: Polygon2D
var scene_root: Node2D

func _init(story_battle: bool = false) -> void:
    layer = -10
    name = "IllustratedBattleMap"
    var base := Node2D.new()
    base.name = "FlatBattle"
    add_child(base)
    scene_root = base
    picture = TextureRect.new()
    picture.name = "FullPaintedTerrain"
    picture.position = Vector2.ZERO
    picture.size = VIEW
    picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    picture.stretch_mode = TextureRect.STRETCH_SCALE
    picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var asset := STORY_MAP if story_battle else PREVIEW_MAP
    if ResourceLoader.exists(asset):
        picture.texture = load(asset)
    else:
        # Backward-compatible visual fallback for builds without the
        # separately-supplied high-resolution painting.
        picture.texture = Art.scenery("rainy_bridge")
    scene_root.add_child(picture)
    selection = _ellipse(Color(0.36,0.97,0.76,0.40),42,19)
    selection.name = "MoveCursor"
    selection.visible = false
    scene_root.add_child(selection)
    for x in range(BridgeLayout.COLS):
        for y in range(BridgeLayout.ROWS):
            var key := Vector2i(x,y)
            var mark := _ellipse(Color(0.40,0.91,0.73,0.28),35,16)
            mark.name = "Legal_%d_%d" % [x,y]
            mark.position = point_for_cell(key)
            mark.visible = false
            scene_root.add_child(mark)
            marks[key] = mark

func _ellipse(color: Color, rx: float, ry: float) -> Polygon2D:
    var result := Polygon2D.new()
    result.color = color
    var points := PackedVector2Array()
    for i in range(16):
        var angle := float(i)*TAU/16.0
        points.append(Vector2(cos(angle)*rx,sin(angle)*ry))
    result.polygon=points
    return result

## Board-coordinate mapping stays in rainy_bridge_layout.gd, shared with
## BattleState terrain and the six-person encounter spawn validator.
static func point_for_cell(cell: Vector2i) -> Vector2:
    return BridgeLayout.point_for_cell(cell)

static func point_for_grid(grid: Vector2) -> Vector2:
    return BridgeLayout.point_for_grid(grid)

func cell_from_screen(screen: Vector2, board: Dictionary) -> Vector2i:
    return BridgeLayout.cell_from_screen(screen, board)

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
    if float(lights.get(id,0.0))>0.0:
        sprite.modulate=Color(1.0,0.88,0.65)
    else: sprite.modulate=Color.WHITE

func set_highlights(cells: Dictionary, show: bool) -> void:
    for cell in marks:
        var mark: Polygon2D=marks[cell]
        mark.visible=show and cells.has(cell)

func set_cursor(cell: Vector2i, valid: bool) -> void:
    selection.visible=valid and cell.x>=0
    if selection.visible: selection.position=point_for_cell(cell)

func pulse_actor(id: int) -> void:
    if actors.has(id):
        lights[id]=0.18

func _process(delta: float) -> void:
    for id in lights:
        lights[id]=maxf(0.0,float(lights[id])-delta)
