@tool
class_name WuxiaNativeMapObstacle
extends StaticBody2D
## Polygon vertices remain editable with Godot's native collision handles.
@export_enum("blocked", "water", "rock", "bamboo") var terrain_kind: String = "blocked"

func to_definition() -> WuxiaMapPolygonDefinition:
    var shape := get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
    if shape == null:
        return null
    var result := WuxiaMapPolygonDefinition.new()
    result.terrain_kind = terrain_kind
    for vertex in shape.polygon:
        result.vertices.append(position + shape.position + vertex)
    return result
