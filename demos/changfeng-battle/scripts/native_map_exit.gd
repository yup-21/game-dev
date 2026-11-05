@tool
class_name WuxiaNativeMapExit
extends Area2D
## Native Area2D makes the exit position and radius editable in the 2D viewport.
@export_enum("north", "south", "east", "west") var exit_side: String = "north"
@export var target_zone_id: String = ""
@export var target_entry_id: String = ""

func to_definition() -> WuxiaMapMarkerDefinition:
    var shape := get_node_or_null("Radius") as CollisionShape2D
    if shape == null or not shape.shape is CircleShape2D:
        return null
    var result := WuxiaMapMarkerDefinition.new()
    result.marker_id = name
    result.marker_kind = "zone_exit"
    result.position = position
    result.radius = (shape.shape as CircleShape2D).radius
    result.exit_side = exit_side
    result.target_zone_id = target_zone_id
    result.target_entry_id = target_entry_id
    return result
