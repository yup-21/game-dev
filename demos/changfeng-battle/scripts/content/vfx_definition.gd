@tool
class_name WuxiaVFXDefinition
extends WuxiaAssetDefinition
## One native VFX Resource for texture atlases or authored 2D scenes.
## The inherited asset identity, grid and frame order remain authoritative.

func _init() -> void:
    asset_kind = "vfx"

func to_record() -> Dictionary:
    if asset_kind != "vfx" or content_id.is_empty() or resource == null:
        return {}
    if resource is Texture2D:
        var image := resource as Texture2D
        if columns < 1 or rows < 1 or columns > 64 or rows > 64 or \
                image.get_width() < columns or image.get_height() < rows or \
                image.get_width() % columns != 0 or image.get_height() % rows != 0:
            return {}
        if frame_indices.size() > 256:
            return {}
        for frame in frame_indices:
            if frame < 0 or frame >= columns * rows:
                return {}
    elif resource is PackedScene:
        if columns != 1 or rows != 1 or not frame_indices.is_empty():
            return {}
        var scene := resource as PackedScene
        var node: Node = scene.instantiate()
        if not node is Node2D:
            if node != null:
                node.free()
            return {}
        node.free()
    else:
        return {}
    return super.to_record()
