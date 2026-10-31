@tool
class_name WuxiaMapDefinition
extends WuxiaContentDefinition
## No tile artwork or 15x10 authored mask. Collisions use native polygons.
@export var background: Texture2D
@export var viewport_size: Vector2i = Vector2i(1600,1000)
@export var area_bounds: Rect2 = Rect2(100,100,1400,800)
@export var image_rotation_degrees: float = 0.0
@export var image_scale: float = 1.0
@export var obstacles: Array[Resource] = []
@export var markers: Array[Resource] = []

func content_kind() -> String:
    return "map"

func to_record() -> Dictionary:
    if background == null or background.resource_path.is_empty() or \
            viewport_size.x < 100 or viewport_size.y < 100 or \
            area_bounds.size.x < 100 or area_bounds.size.y < 100:
        return {}
    var normalized: Array = []
    for obstacle in obstacles:
        if not obstacle is WuxiaMapPolygonDefinition:
            return {}
        var entry: Dictionary = obstacle.to_record()
        if entry.is_empty():
            return {}
        normalized.append(entry)
    var anchors: Array = []
    var seen_markers: Dictionary = {}
    for marker in markers:
        if not marker is WuxiaMapMarkerDefinition: return {}
        var record: Dictionary = marker.to_record()
        if record.is_empty() or seen_markers.has(str(record.id)) or not area_bounds.has_point(marker.position):
            return {}
        seen_markers[str(record.id)] = true
        anchors.append(record)
    return {"schema_version":schema_version,"id":content_id,
        "background":background.resource_path,
        "source_size":[background.get_width(),background.get_height()],
        "viewport":[viewport_size.x,viewport_size.y],
        "bounds":[area_bounds.position.x,area_bounds.position.y,
            area_bounds.size.x,area_bounds.size.y],
        "rotation_degrees":image_rotation_degrees,
        "image_scale":image_scale,
        "obstacles":normalized,"markers":anchors}
