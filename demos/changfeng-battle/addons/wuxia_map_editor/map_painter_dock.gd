@tool
extends VBoxContainer
## Select a WuxiaMapDefinition in Inspector; click vertices and save the .tres.
const Canvas = preload("res://addons/wuxia_map_editor/map_painter_canvas.gd")
var map_resource: WuxiaMapDefinition
var native_region: Node2D
var canvas: Control
var kinds: OptionButton
var marker_kinds: OptionButton
var marker_id: LineEdit
var actions: Array[String] = []
var previous_walkable: PackedVector2Array = PackedVector2Array()
var status: Label


## Reflection keeps this dock compatible before the native-map PR is merged.
static func is_native_map(object: Object) -> bool:
    if not object is Node2D or not object.has_method("build_definition") or \
            not object.has_method("sync_to_resource"):
        return false
    for entry in object.get_property_list():
        if str(entry.get("name", "")) == "source_map":
            return object.get("source_map") is WuxiaMapDefinition
    return false

func _ready() -> void:
    var heading := Label.new()
    heading.text = "武侠 · 多边形地图画笔"
    add_child(heading)
    var walkable := Button.new()
    walkable.text = "重画可走区"
    walkable.tooltip_text = "以新版地图合成贴图为底，点击描出角色脚点可达区域。"
    walkable.pressed.connect(_start_walkable)
    add_child(walkable)
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
    var validate_native := Button.new()
    validate_native.text = "检查当前原生地图节点"
    validate_native.pressed.connect(_validate_native)
    add_child(validate_native)
    status = Label.new()
    status.text = "在 Inspector 中选择 WuxiaMapDefinition。左键加点，右键撤点。"
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(status)
    canvas = Canvas.new()
    canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
    canvas.connect("polygon_ready",_accept_polygon)
    canvas.connect("walkable_ready",_accept_walkable)
    canvas.connect("marker_ready",_accept_marker)
    add_child(canvas)

func edit_map(value: Object) -> void:
    native_region = value as Node2D if is_native_map(value) else null
    map_resource = native_region.get("source_map") as WuxiaMapDefinition if native_region != null else value as WuxiaMapDefinition
    actions.clear()
    previous_walkable = PackedVector2Array()
    if canvas != null:
        canvas.call("edit_map",map_resource)
    if status != null:
        status.text = "原生地图场景：请在 2D 视图直接编辑 Boundary、Obstacles、Markers、Exits；本画笔只读。" \
            if native_region != null else "当前地图：" + (map_resource.content_id if map_resource != null else "未选择")


func _validate_native() -> void:
    if native_region == null or map_resource == null:
        status.text = "请先在场景树选中带 source_map 的原生地图根节点。"
        return
    var snapshot: WuxiaMapDefinition = native_region.call("build_definition") as WuxiaMapDefinition
    if snapshot == null or snapshot.to_record().is_empty():
        status.text = "原生节点校验失败：检查 CollisionPolygon2D、标记和出入口。"
        return
    status.text = "原生节点合法，当前与 .tres 一致。" if snapshot.to_record() == map_resource.to_record() \
        else "原生节点合法但与 .tres 不同：请先保存 .tscn，再用根节点 Inspector 的同步按钮更新 .tres。"

func _start_walkable() -> void:
    if map_resource == null or native_region != null: return
    canvas.call("begin_walkable")
    status.text = "在合成贴图上描绘完整可走区，双击或“封闭”完成；无需重画15×10旧网格。"

func _start() -> void:
    if map_resource == null or native_region != null: return
    canvas.call("begin_polygon",kinds.get_item_text(kinds.selected))
    status.text = "左键追加顶点，右键撤点，双击或点“封闭”完成。"

func _begin_marker() -> void:
    if map_resource == null or native_region != null: return
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
    if map_resource == null or native_region != null: return
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
    if native_region != null: return
    if not bool(canvas.call("finish_polygon")):
        status.text = "至少需要 3 个顶点。"

func _accept_walkable(vertices: PackedVector2Array) -> void:
    if map_resource == null or native_region != null: return
    var old_outline := map_resource.walkable_outline.duplicate()
    map_resource.walkable_outline = vertices
    if map_resource.to_record().is_empty():
        map_resource.walkable_outline = old_outline
        status.text = "可走区无效：请检查顶点位置和自交。"
        return
    previous_walkable = old_outline
    actions.append("walkable")
    map_resource.emit_changed()
    canvas.queue_redraw()
    status.text = "已更新可走区，保存后 GRID/FREE 将从相同轮廓生成合法地形。"

func _accept_polygon(vertices: PackedVector2Array, kind: String) -> void:
    if map_resource == null or native_region != null: return
    var polygon := WuxiaMapPolygonDefinition.new()
    polygon.terrain_kind = kind
    polygon.vertices = vertices
    map_resource.obstacles.append(polygon)
    actions.append("polygon")
    map_resource.emit_changed()
    canvas.queue_redraw()
    status.text = "已添加 " + kind + "，可继续绘制或保存。"

func _undo() -> void:
    if map_resource == null or native_region != null or actions.is_empty(): return
    var kind: String = actions.pop_back()
    if kind == "walkable":
        map_resource.walkable_outline = previous_walkable.duplicate()
    elif kind == "marker" and not map_resource.markers.is_empty():
        map_resource.markers.remove_at(map_resource.markers.size()-1)
    elif kind == "polygon" and not map_resource.obstacles.is_empty():
        map_resource.obstacles.remove_at(map_resource.obstacles.size()-1)
    map_resource.emit_changed()
    canvas.queue_redraw()
    status.text = "已撤回最后一个障碍。"

func _save() -> void:
    if native_region != null:
        status.text = "原生地图请 Ctrl+S 保存 .tscn，并用根节点 Inspector 同步 .tres；此处不覆盖原生几何。"
        return
    if map_resource == null or map_resource.resource_path.is_empty():
        status.text = "请先将地图资源保存为 data/maps/*.tres。"
        return
    if map_resource.to_record().is_empty():
        status.text = "地图资源无效：请检查边界、障碍和标记。"
        return
    var result: Error = ResourceSaver.save(map_resource,map_resource.resource_path)
    if result == OK:
        actions.clear()
    status.text = "地图已保存。" if result == OK else "保存失败：" + str(result)
