@tool
extends VBoxContainer
## Select a WuxiaMapDefinition in Inspector; click vertices and save the .tres.
const Canvas = preload("res://addons/wuxia_map_editor/map_painter_canvas.gd")
var map_resource: WuxiaMapDefinition
var canvas: Control
var kinds: OptionButton
var marker_kinds: OptionButton
var marker_id: LineEdit
var actions: Array[String] = []
var status: Label

func _ready() -> void:
    var heading := Label.new()
    heading.text = "武侠 · 多边形地图画笔"
    add_child(heading)
    var toolbar := HBoxContainer.new()
    add_child(toolbar)
    kinds = OptionButton.new()
    for kind in ["blocked","water","rock","bamboo"]:
        kinds.add_item(kind)
    toolbar.add_child(kinds)
    var start := Button.new()
    start.text = "新障碍"
    start.pressed.connect(_start)
    toolbar.add_child(start)
    var finish := Button.new()
    finish.text = "封闭"
    finish.pressed.connect(_finish)
    toolbar.add_child(finish)
    var undo := Button.new()
    undo.text = "撤回末项"
    undo.pressed.connect(_undo)
    toolbar.add_child(undo)
    var anchors := HBoxContainer.new()
    add_child(anchors)
    marker_kinds = OptionButton.new()
    for kind in ["spawn","story_trigger","vfx_anchor"]:
        marker_kinds.add_item(kind)
    anchors.add_child(marker_kinds)
    marker_id = LineEdit.new()
    marker_id.placeholder_text = "唯一标记 ID（英文/数字/下划线）"
    marker_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    anchors.add_child(marker_id)
    var place := Button.new()
    place.text = "点选位置"
    place.pressed.connect(_begin_marker)
    anchors.add_child(place)
    var save := Button.new()
    save.text = "保存 .tres"
    save.pressed.connect(_save)
    add_child(save)
    status = Label.new()
    status.text = "在 Inspector 中选择 WuxiaMapDefinition。左键加点，右键撤点。"
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(status)
    canvas = Canvas.new()
    canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
    canvas.connect("polygon_ready",_accept_polygon)
    canvas.connect("marker_ready",_accept_marker)
    add_child(canvas)

func edit_map(value: Object) -> void:
    map_resource = value as WuxiaMapDefinition
    actions.clear()
    if canvas != null:
        canvas.call("edit_map",map_resource)
    if status != null:
        status.text = "当前地图：" + (map_resource.content_id if map_resource != null else "未选择")

func _start() -> void:
    if map_resource == null: return
    canvas.call("begin_polygon",kinds.get_item_text(kinds.selected))
    status.text = "左键追加顶点，右键撤点，双击或点“封闭”完成。"

func _begin_marker() -> void:
    if map_resource == null: return
    var id: String = marker_id.text.strip_edges()
    if not id.is_valid_identifier():
        status.text = "标记 ID 须是合法标识符，且不可为空。"
        return
    for existing in map_resource.markers:
        if existing is WuxiaMapMarkerDefinition and existing.marker_id == id:
            status.text = "标记 ID 已存在：" + id
            return
    canvas.call("begin_marker",marker_kinds.get_item_text(marker_kinds.selected))
    status.text = "在地图上点击标记位置：" + id

func _accept_marker(point: Vector2, kind: String) -> void:
    if map_resource == null: return
    var marker := WuxiaMapMarkerDefinition.new()
    marker.marker_id = marker_id.text.strip_edges()
    marker.marker_kind = kind
    marker.position = point
    map_resource.markers.append(marker)
    if map_resource.to_record().is_empty():
        map_resource.markers.remove_at(map_resource.markers.size()-1)
        status.text = "标记与地图边界或内容约束冲突。"
        return
    actions.append("marker")
    map_resource.emit_changed()
    canvas.queue_redraw()
    status.text = "已放置 " + marker.marker_id + "，保存后可在运行时按 ID 查找。"

func _finish() -> void:
    if not bool(canvas.call("finish_polygon")):
        status.text = "至少需要 3 个顶点。"

func _accept_polygon(vertices: PackedVector2Array, kind: String) -> void:
    if map_resource == null: return
    var polygon := WuxiaMapPolygonDefinition.new()
    polygon.terrain_kind = kind
    polygon.vertices = vertices
    map_resource.obstacles.append(polygon)
    actions.append("polygon")
    map_resource.emit_changed()
    canvas.queue_redraw()
    status.text = "已添加 " + kind + "，可继续绘制或保存。"

func _undo() -> void:
    if map_resource == null or actions.is_empty(): return
    var kind: String = actions.pop_back()
    if kind == "marker" and not map_resource.markers.is_empty():
        map_resource.markers.remove_at(map_resource.markers.size()-1)
    elif kind == "polygon" and not map_resource.obstacles.is_empty():
        map_resource.obstacles.remove_at(map_resource.obstacles.size()-1)
    map_resource.emit_changed()
    canvas.queue_redraw()
    status.text = "已撤回最后一个障碍。"

func _save() -> void:
    if map_resource == null or map_resource.resource_path.is_empty():
        status.text = "请先将地图资源保存为 data/maps/*.tres。"
        return
    if map_resource.to_record().is_empty():
        status.text = "地图资源无效：请检查边界、障碍和标记。"
        return
    var result: Error = ResourceSaver.save(map_resource,map_resource.resource_path)
    status.text = "地图已保存。" if result == OK else "保存失败：" + str(result)
