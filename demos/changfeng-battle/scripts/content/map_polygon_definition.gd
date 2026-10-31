@tool
class_name WuxiaMapPolygonDefinition
extends Resource
## Freehand world-space obstacle. Vertices use the map viewport's 2D pixels.
@export_enum("rock", "water", "bamboo", "blocked") var terrain_kind: String = "blocked"
@export var vertices: PackedVector2Array = PackedVector2Array()

func to_record() -> Dictionary:
    if vertices.size() < 3 or vertices.size() > 64:
        return {}
    var positions: Array = []
    for point in vertices:
        if not is_finite(point.x) or not is_finite(point.y):
            return {}
        positions.append([point.x,point.y])
    return {"kind":terrain_kind,"vertices":positions}
