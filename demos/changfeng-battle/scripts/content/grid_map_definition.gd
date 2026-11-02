@tool
class_name WuxiaGridMapDefinition
extends WuxiaContentDefinition
const CombatScale = preload("res://scripts/combat_scale.gd")
## Authored GRID terrain + calibrated background. FREE maps remain polygons.
@export var background: Texture2D
@export var scene_art: WuxiaSceneArtProfile
@export var source_size: Vector2i = Vector2i.ZERO
@export var viewport_size: Vector2i = Vector2i(1600, 1000)
@export var pixels_per_unit: float = CombatScale.PIXELS_PER_UNIT
@export var rotation_degrees: float = 0.0
@export var image_scale: float = 1.0
@export var columns: int = 15
@export var rows_count: int = 10
@export var first_center: Vector2 = Vector2.ZERO
@export var cell_size: Vector2 = Vector2.ONE
@export var painted_rows: Array[String] = []
@export var terrain_keys: Array[Resource] = []
@export_multiline var notes: String = ""

func content_kind() -> String:
    return "map"

func to_record() -> Dictionary:
    if background == null or background.resource_path.is_empty() or columns != 15 or rows_count != 10:
        return {}
    if source_size.x <= 0 or source_size.y <= 0 or viewport_size.x <= 0 or viewport_size.y <= 0 or \
            not CombatScale.valid_map_pixels_per_unit(pixels_per_unit):
        return {}
    if painted_rows.size() != rows_count or terrain_keys.is_empty():
        return {}
    var legend: Dictionary = {}
    for key in terrain_keys:
        if not key is WuxiaGridTerrainKeyDefinition or not key.valid_key():
            return {}
        if legend.has(key.symbol):
            return {}
        legend[key.symbol] = key.terrain_kind
    var authored_rows: Array = []
    for line in painted_rows:
        if line.length() != columns:
            return {}
        for i in range(line.length()):
            if not legend.has(line.substr(i, 1)):
                return {}
        authored_rows.append(line)
    return {"schema_version":schema_version, "id":content_id,
        "background":background.resource_path,
        "source_size":[source_size.x,source_size.y],
        "viewport":[viewport_size.x,viewport_size.y],
        "pixels_per_unit":pixels_per_unit,
        "art_transform":{"rotation_degrees":rotation_degrees,"scale":image_scale},
        "grid":{"columns":columns,"rows":rows_count,
            "first_center":[first_center.x,first_center.y],
            "cell_size":[cell_size.x,cell_size.y]},
        "terrain_legend":legend, "rows":authored_rows, "notes":notes}
