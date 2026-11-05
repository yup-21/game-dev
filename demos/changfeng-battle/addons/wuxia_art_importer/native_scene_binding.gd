@tool
extends RefCounted
## An explicit, opt-in bridge for art layers in an editor-authored map .tscn.
## Never regenerate a native map or change hand-authored geometry/transforms.

const LAYERS := ["background", "ground", "foreground", "weather"]


static func _property_exists(object: Object, property: String) -> bool:
    for entry in object.get_property_list():
        if str(entry.get("name", "")) == property:
            return true
    return false


static func _valid_path(path: String) -> bool:
    return path.begins_with("res://scenes/") and path.ends_with(".tscn") and \
        not path.contains("..") and FileAccess.file_exists(path)


static func _inspect_root(root: Node, source_map: WuxiaMapDefinition) -> String:
    if not root is Node2D or not _property_exists(root, "source_map"):
        return "目标不是带 source_map 的原生地图场景"
    var map: WuxiaMapDefinition = root.get("source_map") as WuxiaMapDefinition
    if map == null or source_map == null or map.resource_path != source_map.resource_path:
        return "原生场景 source_map 与所选地图 Resource 不一致"
    for name in ["Background", "Ground"]:
        if not root.get_node_or_null(name) is Sprite2D:
            return "原生场景缺少可编辑 Sprite2D 图层：" + name
    for name in ["Foreground", "Weather"]:
        var child := root.get_node_or_null(name)
        if child != null and not child is Sprite2D:
            return "原生场景图层不是 Sprite2D：" + name
    return ""


static func inspect(path: String, source_map: WuxiaMapDefinition,
        required_layers: Array = []) -> Dictionary:
    if not _valid_path(path):
        return {"error": "请选择 res://scenes/ 下已有的原生地图 .tscn"}
    # An open scene can contain unsaved Inspector edits that are not on disk.
    # Never replace that scene with a newly packed disk copy behind the editor.
    if Engine.is_editor_hint() and EditorInterface.get_open_scenes().has(path):
        return {"error": "原生场景仍在 Godot 编辑器中打开；请 Ctrl+S 保存并关闭该场景后再执行导入"}
    var packed := ResourceLoader.load(path) as PackedScene
    if packed == null:
        return {"error": "原生地图场景无法加载：" + path}
    var root := packed.instantiate()
    if root == null:
        return {"error": "原生地图场景无法实例化：" + path}
    var error := _inspect_root(root, source_map)
    if error.is_empty():
        for key in required_layers:
            if not LAYERS.has(str(key)) or not root.get_node_or_null(str(key).capitalize()) is Sprite2D:
                error = "请先在 Godot 场景中添加 Sprite2D 图层：" + str(key).capitalize()
                break
    root.free()
    return {"error": error, "sha256": FileAccess.get_sha256(path)}


## Also exposed separately for in-memory contract tests. Only texture properties
## are assigned; positions, owners, polygons, markers and node order are untouched.
static func bind_layers(root: Node, source_map: WuxiaMapDefinition,
        layers: Dictionary) -> String:
    var error := _inspect_root(root, source_map)
    if not error.is_empty():
        return error
    for key in LAYERS:
        if not layers.has(key):
            continue
        var texture: Texture2D = layers[key] as Texture2D
        if texture == null:
            return "原生图层纹理无效：" + key
        var node_name: String = str(key).capitalize()
        var sprite := root.get_node_or_null(node_name) as Sprite2D
        if sprite == null:
            return "请先在 Godot 场景中添加 Sprite2D 图层：" + node_name
    for key in LAYERS:
        if layers.has(key):
            (root.get_node(key.capitalize()) as Sprite2D).texture = layers[key]
    return ""


static func save(path: String, source_map: WuxiaMapDefinition,
        layers: Dictionary, expected_hash: String) -> String:
    var info := inspect(path, source_map)
    if not str(info["error"]).is_empty():
        return str(info["error"])
    if expected_hash.is_empty() or str(info["sha256"]) != expected_hash:
        return "原生场景自预检后被修改；请重新检查并确认"
    var packed := ResourceLoader.load(path) as PackedScene
    var root := packed.instantiate()
    var error := bind_layers(root, source_map, layers)
    if error.is_empty():
        var result := PackedScene.new()
        if result.pack(root) != OK or ResourceSaver.save(result, path) != OK:
            error = "无法保存原生地图场景：" + path
    root.free()
    return error
