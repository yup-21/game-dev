@tool
class_name WuxiaNativeMapMarker
extends Marker2D
## Editable spawn/story/VFX anchor. The node name is the stable marker ID.
@export_enum("spawn", "story_trigger", "vfx_anchor") var marker_kind: String = "spawn"
@export_range(0.0, 300.0, 1.0) var radius: float = 24.0

func to_definition() -> WuxiaMapMarkerDefinition:
    var result := WuxiaMapMarkerDefinition.new()
    result.marker_id = name
    result.marker_kind = marker_kind
    result.position = position
    result.radius = radius
    return result
