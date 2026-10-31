@tool
extends Control
## Small canvas drawing map-space vertices. No tile paint or JSON export.
signal polygon_ready(vertices: PackedVector2Array, terrain_kind: String)
var map_resource: WuxiaMapDefinition
var active: bool = false
var terrain_kind: String = "blocked"
var draft: PackedVector2Array = PackedVector2Array()

func _init() -> void:
    custom_minimum_size = Vector2(500,340)
    mouse_filter = Control.MOUSE_FILTER_STOP

func edit_map(value: WuxiaMapDefinition) -> void:
    map_resource = value
    draft.clear()
    active = false
    queue_redraw()

func begin_polygon(kind: String) -> void:
    terrain_kind = kind
    draft.clear()
    active = true
    queue_redraw()

func finish_polygon() -> bool:
    if not active or draft.size() < 3: return false
    polygon_ready.emit(draft.duplicate(),terrain_kind)
    draft.clear()
    active = false
    queue_redraw()
    return true

func cancel_polygon() -> void:
    draft.clear()
    active = false
    queue_redraw()

func _image_rect() -> Rect2:
    if map_resource == null: return Rect2()
    var native_size: Vector2 = Vector2(map_resource.viewport_size)
    if native_size.x <= 0.0 or native_size.y <= 0.0: return Rect2()
    var scale_factor: float = minf(size.x/native_size.x,size.y/native_size.y)
    var painted: Vector2 = native_size*scale_factor
    return Rect2((size-painted)*0.5,painted)

func _screen_point(point: Vector2, rect: Rect2) -> Vector2:
    return rect.position + Vector2(point.x*rect.size.x/float(map_resource.viewport_size.x),
        point.y*rect.size.y/float(map_resource.viewport_size.y))

func _draw_path(vertices: PackedVector2Array, rect: Rect2, color: Color, closed: bool) -> void:
    var mapped := PackedVector2Array()
    for point in vertices:
        mapped.append(_screen_point(point,rect))
    if mapped.size() < 2: return
    if closed:
        draw_colored_polygon(mapped,Color(color.r,color.g,color.b,0.15))
        mapped.append(mapped[0])
    draw_polyline(mapped,color,2.0,true)
    for point in mapped:
        draw_circle(point,3.0,color)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color(0.09,0.11,0.12))
    if map_resource == null or map_resource.background == null:
        return
    var rect: Rect2 = _image_rect()
    draw_texture_rect(map_resource.background,rect,false)
    var bounds: Rect2 = map_resource.area_bounds
    var p0: Vector2 = _screen_point(bounds.position,rect)
    var p1: Vector2 = _screen_point(bounds.end,rect)
    draw_rect(Rect2(p0,p1-p0),Color(0.35,0.95,0.67),false,2.0)
    for obstacle in map_resource.obstacles:
        if obstacle is WuxiaMapPolygonDefinition:
            _draw_path(obstacle.vertices,rect,Color(1.0,0.53,0.30),true)
    if not draft.is_empty():
        _draw_path(draft,rect,Color(1.0,0.97,0.50),false)

func _gui_input(event: InputEvent) -> void:
    if not active or map_resource == null or not event is InputEventMouseButton or \
            not event.pressed:
        return
    if event.button_index == MOUSE_BUTTON_RIGHT:
        if not draft.is_empty(): draft.remove_at(draft.size()-1)
        queue_redraw()
        accept_event()
        return
    if event.button_index != MOUSE_BUTTON_LEFT: return
    var rect: Rect2 = _image_rect()
    if not rect.has_point(event.position): return
    var point: Vector2 = (event.position-rect.position)*Vector2(
        float(map_resource.viewport_size.x)/rect.size.x,
        float(map_resource.viewport_size.y)/rect.size.y)
    if not map_resource.area_bounds.has_point(point): return
    if event.double_click and draft.size() >= 3:
        finish_polygon()
    else:
        draft.append(point)
        queue_redraw()
    accept_event()
