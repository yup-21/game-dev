@tool
extends Control
## Live 2D cutout preview and left-arm IK handle for the imported candidate.
signal joint_dragged(joint_name: String, logical_point: Vector2)
signal binding_dragged(field_name: String, source_pixel: Vector2)

const Service = preload("res://addons/wuxia_art_importer/rig2d_pose_service.gd")
const HANDLES := ["left_elbow", "left_wrist"]

var rig: Dictionary = {}
var action := ""
var frame_index := 0
var active_joint := ""
var show_bones := true
var binding_part := ""


func _ready() -> void:
    custom_minimum_size = Vector2(0, 280)
    mouse_filter = Control.MOUSE_FILTER_STOP


func set_pose(data: Dictionary, action_id: String, index: int) -> void:
    rig = data
    action = action_id
    frame_index = index
    queue_redraw()


func set_binding_part(name: String) -> void:
    binding_part = name
    active_joint = ""
    queue_redraw()


func _binding_source_rect() -> Rect2:
    var part: Dictionary = rig["parts"][binding_part]
    var texture: Texture2D = rig["textures"][str(part["texture"])]
    var outline: Array = part.get("polygon", [])
    if outline.is_empty():
        return Rect2(Vector2.ZERO, texture.get_size())
    var start := Service.vec(outline[0])
    var stop := start
    var points: Array = outline.duplicate()
    points.append(part["pivot"])
    points.append(part["axis"])
    for item in points:
        start = start.min(Service.vec(item))
        stop = stop.max(Service.vec(item))
    return Rect2(start - Vector2(12, 12), stop - start + Vector2(24, 24)).intersection(
        Rect2(Vector2.ZERO, texture.get_size()))


func _binding_screen(source_pixel: Vector2) -> Vector2:
    var box := _canvas_rect()
    var region := _binding_source_rect()
    return box.position + (source_pixel - region.position) * box.size / region.size


func _binding_pixel(screen_point: Vector2) -> Vector2:
    var box := _canvas_rect()
    var region := _binding_source_rect()
    return region.position + (screen_point - box.position) * region.size / box.size


func _canvas_rect() -> Rect2:
    var frame: Vector2 = Service.vec(rig.get("project", {}).get("canvas", [384, 288]))
    if not binding_part.is_empty() and not rig.is_empty():
        frame = _binding_source_rect().size
    var scale := minf((size.x - 14.0) / frame.x, (size.y - 14.0) / frame.y)
    var pixels := frame * scale
    return Rect2((size - pixels) * 0.5, pixels)


func _to_screen(logical: Vector2) -> Vector2:
    var rect := _canvas_rect()
    var dimensions := Service.vec(rig["project"].get("canvas", [384, 288]))
    return rect.position + logical * rect.size / dimensions


func _to_logical(screen: Vector2) -> Vector2:
    var rect := _canvas_rect()
    var dimensions := Service.vec(rig["project"].get("canvas", [384, 288]))
    return (screen - rect.position) * dimensions / rect.size


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.12, 0.15))
    if rig.is_empty() or action.is_empty():
        draw_string(ThemeDB.fallback_font, Vector2(12, 28), "载入 pose_templates 工程后查看真实角色")
        return
    if not binding_part.is_empty():
        _draw_binding()
        return
    var bounds := _canvas_rect()
    for y in range(8):
        for x in range(8):
            draw_rect(Rect2(bounds.position + Vector2(x, y) * bounds.size / 8.0,
                bounds.size / 8.0), Color(0.19, 0.21, 0.24) if (x + y) % 2 else Color(0.15, 0.17, 0.20))
    var motion: Dictionary = rig["motions"][action]
    var frame: Dictionary = motion["frames"][frame_index]
    var solved := Service.solve_pose(rig, frame)
    var placements: Dictionary = solved["placements"]
    var ordered: Array = rig["parts"].keys()
    ordered.sort_custom(func(a: String, b: String):
        return int(rig["parts"][a]["depth"]) < int(rig["parts"][b]["depth"]))
    for name in ordered:
        var part: Dictionary = rig["parts"][name]
        var texture: Texture2D = rig["textures"][str(part["texture"])]
        var vertices: Array = part.get("polygon", [])
        if vertices.is_empty():
            var dimensions := texture.get_size()
            vertices = [[0, 0], [dimensions.x, 0], [dimensions.x, dimensions.y], [0, dimensions.y]]
        var points := PackedVector2Array()
        var uvs := PackedVector2Array()
        var colors := PackedColorArray()
        for source in vertices:
            points.append(_to_screen(Service.point(part, placements[name], source)))
            uvs.append(Service.vec(source))
            colors.append(Color.WHITE)
        draw_polygon(points, colors, uvs, texture)
    if show_bones:
        var joints: Dictionary = solved["joints"]
        for side in PackedStringArray(["left", "right"]):
            var tint := Color(1.0, 0.66, 0.18) if side == "left" else Color(0.2, 0.8, 1.0)
            for chain in [["shoulder", "elbow", "wrist"], ["hip", "knee", "ankle"]]:
                var a: String = side + "_" + str(chain[0])
                var b: String = side + "_" + str(chain[1])
                var c: String = side + "_" + str(chain[2])
                draw_line(_to_screen(joints[a]), _to_screen(joints[b]), tint, 2.0)
                draw_line(_to_screen(joints[b]), _to_screen(joints[c]), tint, 2.0)
                for key in [a, b, c]:
                    draw_circle(_to_screen(joints[key]), 4.0, tint)
                    draw_circle(_to_screen(joints[key]), 2.0, Color.BLACK)
        for handle in HANDLES:
            draw_arc(_to_screen(joints[handle]), 7.0, 0.0, TAU, 20,
                Color.YELLOW if active_joint == handle else Color.WHITE, 1.5)


func _draw_binding() -> void:
    var part: Dictionary = rig["parts"][binding_part]
    var image: Texture2D = rig["textures"][str(part["texture"])]
    var rect := _canvas_rect()
    var region := _binding_source_rect()
    draw_texture_rect_region(image, rect, region)
    var polygon: Array = part.get("polygon", [])
    if not polygon.is_empty():
        for i in range(polygon.size()):
            var a := _binding_screen(Service.vec(polygon[i]))
            var b := _binding_screen(Service.vec(polygon[(i + 1) % polygon.size()]))
            draw_line(a, b, Color(0.3, 0.95, 0.7), 1.5)
    var pivot := _binding_screen(Service.vec(part["pivot"]))
    var axis := _binding_screen(Service.vec(part["axis"]))
    draw_line(pivot, axis, Color.YELLOW, 2.0)
    for name in ["pivot", "axis"]:
        var location := pivot if name == "pivot" else axis
        draw_circle(location, 6.0, Color.ORANGE if name == "pivot" else Color.CYAN)
        draw_circle(location, 2.5, Color.BLACK)
    draw_string(ThemeDB.fallback_font, Vector2(6, 18), binding_part + " · 橙=旋转原点 / 蓝=骨段末端",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


func _gui_input(event: InputEvent) -> void:
    if rig.is_empty() or action.is_empty():
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            if not binding_part.is_empty():
                var part: Dictionary = rig["parts"][binding_part]
                active_joint = ""
                for field in ["pivot", "axis"]:
                    if event.position.distance_to(_binding_screen(Service.vec(part[field]))) < 12.0:
                        active_joint = field
                        break
                if not active_joint.is_empty():
                    accept_event()
                return
            var frame: Dictionary = rig["motions"][action]["frames"][frame_index]
            var joints: Dictionary = Service.solve_pose(rig, frame)["joints"]
            var closest := 12.0
            active_joint = ""
            for name in HANDLES:
                var distance: float = event.position.distance_to(_to_screen(joints[name]))
                if distance < closest:
                    closest = distance
                    active_joint = name
            if not active_joint.is_empty():
                accept_event()
        else:
            active_joint = ""
            queue_redraw()
    elif event is InputEventMouseMotion and not active_joint.is_empty():
        if not binding_part.is_empty():
            binding_dragged.emit(active_joint, _binding_pixel(event.position))
        else:
            joint_dragged.emit(active_joint, _to_logical(event.position))
        accept_event()
