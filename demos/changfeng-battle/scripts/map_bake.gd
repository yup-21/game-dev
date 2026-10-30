extends RefCounted
## Offline-authored terrain bake for one whole-image scene. The artwork and
## the tile mask are aligned through one fixed, horizontal orthographic lattice:
## cell centres, hit rectangles and actor feet use the SAME coordinates.
const DEFAULT_PATH := "res://data/maps/rainy_bridge.json"
const BLOCKED := ["water","rock","bamboo"]
var id: String = ""
var image_path: String = ""
var source_size: Vector2i = Vector2i.ZERO
var viewport_size: Vector2 = Vector2.ZERO
var origin: Vector2 = Vector2.ZERO
var step: Vector2 = Vector2.ZERO
var image_rotation_degrees: float = 0.0
var image_scale: float = 1.0
var width: int = 0
var height: int = 0
var terrain: Dictionary = {}
var tiles: Dictionary = {}
var error: String = ""

func _init(path: String = DEFAULT_PATH) -> void:
    if path.is_empty() or not FileAccess.file_exists(path):
        error = "Missing baked map: " + path
        return
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not data is Dictionary or int(data.get("schema_version",0))!=1:
        error = "Invalid baked map schema: " + path
        return
    var grid: Variant = data.get("grid",{})
    var transform_data: Variant = data.get("art_transform",{})
    var lines: Variant = data.get("rows",[])
    var legend: Variant = data.get("terrain_legend",{})
    if not grid is Dictionary or not transform_data is Dictionary or not lines is Array or not legend is Dictionary:
        error = "Malformed map properties"
        return
    width = int(grid.get("columns",0))
    height = int(grid.get("rows",0))
    if width!=15 or height!=10 or lines.size()!=height:
        error = "Battle map requires 15 by 10 authored tiles"
        return
    if not _valid_pair(grid.get("first_center")) or not _valid_pair(grid.get("cell_size")) or not _valid_pair(data.get("viewport")) or not _valid_pair(data.get("source_size")):
        error = "Missing pixel-space calibration"
        return
    origin = _vec(grid.first_center)
    step = _vec(grid.cell_size)
    viewport_size = _vec(data.viewport)
    source_size = Vector2i(_vec(data.source_size))
    image_rotation_degrees = float(transform_data.get("rotation_degrees",0.0))
    image_scale = float(transform_data.get("scale",1.0))
    image_path = str(data.get("background",""))
    id = str(data.get("id",""))
    if id.is_empty() or not image_path.begins_with("res://assets/scenes/battle/") or image_path.contains("..") or not ResourceLoader.exists(image_path) or step.x<=0.0 or step.y<=0.0 or image_scale<1.0 or image_scale>1.5 or absf(image_rotation_degrees)>15.0:
        error = "Invalid artwork path or calibration"
        return
    for y in range(height):
        var line: Variant = lines[y]
        if not line is String or line.length()!=width:
            error = "Every authored row must have 15 cells"
            terrain.clear()
            return
        for x in range(width):
            var symbol: String = line.substr(x,1)
            if not legend.has(symbol):
                error = "Unknown terrain mark at %d,%d" % [x,y]
                terrain.clear()
                return
            var point := Vector2i(x,y)
            var kind: String = str(legend[symbol])
            var center := cell_center(point)
            var walkable: bool = not BLOCKED.has(kind)
            terrain[point] = kind
            tiles[point] = {
                "cell":point, "terrain":kind, "walkable":walkable,
                "foot_anchor":center, "bounds":cell_rect(point),
                "move_cost":1 if walkable else 0
            }

func _valid_pair(pair: Variant) -> bool:
    return pair is Array and pair.size()==2 and (pair[0] is float or pair[0] is int) and (pair[1] is float or pair[1] is int) and is_finite(float(pair[0])) and is_finite(float(pair[1]))

func _vec(pair: Array) -> Vector2:
    return Vector2(float(pair[0]),float(pair[1]))

func cell_center(cell: Vector2i) -> Vector2:
    return origin + Vector2(float(cell.x)*step.x,float(cell.y)*step.y)

func grid_position(position: Vector2) -> Vector2:
    return origin + Vector2(position.x*step.x,position.y*step.y)

func cell_rect(cell: Vector2i) -> Rect2:
    return Rect2(cell_center(cell)-step*0.5,step)

func cell_polygon(cell: Vector2i) -> PackedVector2Array:
    var box := cell_rect(cell)
    return PackedVector2Array([box.position,box.position+Vector2(box.size.x,0.0),
        box.end,box.position+Vector2(0.0,box.size.y)])

func cell_at_screen(screen: Vector2, navigable_only: bool = true) -> Vector2i:
    var offset: Vector2 = screen-origin+step*0.5
    var cell := Vector2i(floori(offset.x/step.x),floori(offset.y/step.y))
    if not tiles.has(cell) or not cell_rect(cell).has_point(screen):
        return Vector2i(-1,-1)
    if navigable_only and not bool(tiles[cell].walkable):
        return Vector2i(-1,-1)
    return cell

func is_walkable(cell: Vector2i) -> bool:
    return tiles.has(cell) and bool(tiles[cell].walkable)

func baked_terrain() -> Dictionary:
    return terrain.duplicate(true)
