@tool
class_name WuxiaNativeMapRegion
extends Node2D
## Author geometry with native Godot nodes. A validated Resource snapshot keeps
## existing MapBake/content consumers and the independent map checks compatible.
@export var source_map: WuxiaMapDefinition
@export_tool_button("同步原生节点到地图 .tres") var sync_map_button = sync_to_resource

func _ready() -> void:
    if not Engine.is_editor_hint():
        call_deferred("_launch_when_run_alone")

func _launch_when_run_alone() -> void:
    # F6 on a region starts the existing explorer in this map; instances inside
    # that explorer remain ordinary map nodes.
    if get_tree().current_scene != self or source_map == null:
        return
    var packed := load("res://scenes/pingjiang_exploration.tscn") as PackedScene
    if packed == null:
        return
    var explorer := packed.instantiate()
    explorer.initial_region_id = source_map.content_id
    get_tree().root.add_child(explorer)
    get_tree().current_scene = explorer
    queue_free()

func build_definition() -> WuxiaMapDefinition:
    if source_map == null:
        push_error("Native map scene has no WuxiaMapDefinition source: " + name)
        return null
    var walkable := get_node_or_null("WalkableArea/Boundary") as CollisionPolygon2D
    var obstacles_node := get_node_or_null("Obstacles")
    var markers_node := get_node_or_null("Markers")
    var exits_node := get_node_or_null("Exits")
    if walkable == null or obstacles_node == null or markers_node == null or exits_node == null:
        push_error("Native map scene is missing required editable nodes: " + name)
        return null
    var result := WuxiaMapDefinition.new()
    result.schema_version = source_map.schema_version
    result.content_id = source_map.content_id
    result.background = source_map.background
    result.scene_art = source_map.scene_art
    result.viewport_size = source_map.viewport_size
    result.pixels_per_unit = source_map.pixels_per_unit
    result.primary_axis = source_map.primary_axis
    result.area_bounds = source_map.area_bounds
    result.image_rotation_degrees = source_map.image_rotation_degrees
    result.image_scale = source_map.image_scale
    for vertex in walkable.polygon:
        result.walkable_outline.append(to_local(walkable.to_global(vertex)))
    for child in obstacles_node.get_children():
        if not child is WuxiaNativeMapObstacle:
            push_error("Unexpected obstacle node: " + str(child.name))
            return null
        var shape: WuxiaMapPolygonDefinition = child.to_definition()
        if shape == null:
            return null
        shape.vertices.clear()
        var collision := child.get_node("CollisionPolygon2D") as CollisionPolygon2D
        for vertex in collision.polygon:
            shape.vertices.append(to_local(collision.to_global(vertex)))
        result.obstacles.append(shape)
    var pending_markers: Dictionary = {}
    for child in markers_node.get_children():
        if not child is WuxiaNativeMapMarker:
            push_error("Unexpected marker node: " + str(child.name))
            return null
        if pending_markers.has(child.name):
            return null
        var anchor: WuxiaMapMarkerDefinition = child.to_definition()
        anchor.position = to_local(child.to_global(Vector2.ZERO))
        pending_markers[child.name] = anchor
    for child in exits_node.get_children():
        if not child is WuxiaNativeMapExit:
            push_error("Unexpected exit node: " + str(child.name))
            return null
        var marker: WuxiaMapMarkerDefinition = child.to_definition()
        if marker == null:
            return null
        marker.position = to_local(child.to_global(Vector2.ZERO))
        if pending_markers.has(child.name):
            return null
        pending_markers[child.name] = marker
    # Stable Resource ordering avoids unrelated changes to the existing .tres.
    for old_marker in source_map.markers:
        if pending_markers.has(old_marker.marker_id):
            result.markers.append(pending_markers[old_marker.marker_id])
            pending_markers.erase(old_marker.marker_id)
    for marker in pending_markers.values():
        result.markers.append(marker)
    if result.to_record().is_empty():
        push_error("Invalid native scene geometry or markers: " + name)
        return null
    return result

func sync_to_resource() -> void:
    var snapshot := build_definition()
    if snapshot == null or source_map.resource_path.is_empty():
        return
    source_map.walkable_outline = snapshot.walkable_outline
    source_map.obstacles = snapshot.obstacles
    source_map.markers = snapshot.markers
    source_map.emit_changed()
    var status := ResourceSaver.save(source_map, source_map.resource_path)
    if status != OK:
        push_error("Failed to save native map geometry to " + source_map.resource_path + ": " + str(status))
