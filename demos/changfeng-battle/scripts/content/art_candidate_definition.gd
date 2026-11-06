@tool
class_name WuxiaArtCandidateDefinition
extends Resource
## An editor-only description of ONE unimported source image. Never put these
## resources into ContentManifest: they are not runtime art bindings.
const CombatScale = preload("res://scripts/combat_scale.gd")

@export_enum("concept", "portrait", "sprite", "scene_layer", "vfx", "ui") var asset_kind: String = "concept"
@export var owner_id: String = ""
## Repository-relative path under art-production/candidates, not a res:// URL.
@export var source_path: String = ""
@export var source_pixel_size: Vector2i = Vector2i.ZERO
## A sprite/animated VFX must declare its actual grid before promotion.
## 0 means not yet measured, not a hidden 1x1 default.
@export_range(0, 64) var columns: int = 0
@export_range(0, 64) var rows: int = 0
## Explicitly calibrated source-grid geometry. Zero cell size keeps historical
## divisible-grid metadata readable; AI originals need not be divisible.
@export var grid_origin: Vector2i = Vector2i.ZERO
@export var grid_cell_size: Vector2i = Vector2i.ZERO
@export var grid_gap: Vector2i = Vector2i.ZERO
@export var grid_cell_offsets: Dictionary = {}
@export var action_id: String = ""
@export var frame_indices: PackedInt32Array = PackedInt32Array()
## Optional authored clips for multi-action sheets. Unlike a runtime Profile,
## a partial candidate is valid while other actions are still in production.
@export var clips: Array[Resource] = []
@export var feet_offset: Vector2 = Vector2.ZERO
@export var feet_offset_set: bool = false
## Opaque standing silhouette measured from a reference pose, not cell height.
@export_range(0.0, 8192.0) var reference_visible_height_px: float = 0.0
## Per-candidate view adjustment. 0 computes from silhouette where possible.
@export_range(0.0, 32.0) var display_scale_override: float = 0.0
@export var target_world_height_px: float = CombatScale.ACTOR_HEIGHT_UNITS * CombatScale.PIXELS_PER_UNIT


func display_scale() -> float:
    if display_scale_override > 0.0:
        return display_scale_override
    if asset_kind == "sprite" and reference_visible_height_px > 0.0:
        return target_world_height_px / reference_visible_height_px
    return 0.0 # Undetermined: do not silently assume that cell height is actor height.


func source_absolute_path() -> String:
    if not source_path.begins_with("art-production/candidates/") \
            or source_path.contains("\\") or source_path.contains(".."):
        return ""
    var project_dir: String = ProjectSettings.globalize_path("res://").rstrip("/")
    return project_dir.path_join("../../").path_join(source_path).simplify_path()


func validate_source() -> String:
    var path: String = source_absolute_path()
    if path.is_empty() or not FileAccess.file_exists(path):
        return "Missing candidate source: " + source_path
    var measured := Vector2i.ZERO
    if path.get_extension().to_lower() == "gif":
        var file := FileAccess.open(path, FileAccess.READ)
        if file == null or file.get_length() < 13 or \
                file.get_buffer(6).get_string_from_ascii() not in ["GIF87a", "GIF89a"]:
            return "Unreadable candidate GIF: " + source_path
        measured = Vector2i(file.get_16(), file.get_16())
        if asset_kind != "sprite" or columns != 0 or rows != 0 or \
                action_id.is_empty() or not action_id.is_valid_identifier():
            return "GIF candidate must declare action_id and use no atlas grid: " + source_path
    else:
        var image: Image = Image.load_from_file(path)
        if image == null or image.is_empty():
            return "Unreadable candidate image: " + source_path
        measured = Vector2i(image.get_size())
    if measured != source_pixel_size:
        return "Candidate pixel dimensions changed: " + source_path
    if (columns == 0) != (rows == 0):
        return "Incomplete candidate atlas grid: " + source_path
    if columns > 0:
        if grid_cell_size == Vector2i.ZERO:
            if source_pixel_size.x % columns != 0 or source_pixel_size.y % rows != 0:
                return "Candidate image not divisible by declared grid: " + source_path
        else:
            if grid_cell_size.x <= 0 or grid_cell_size.y <= 0:
                return "Invalid candidate cell size: " + source_path
            for index in range(columns * rows):
                var offset: Variant = grid_cell_offsets.get(index, Vector2i.ZERO)
                if not offset is Vector2i:
                    return "Invalid candidate cell offset: " + source_path
                var cell_offset: Vector2i = offset
                var origin: Vector2i = grid_origin + Vector2i(index % columns, index / columns) * \
                    (grid_cell_size + grid_gap) + cell_offset
                if origin.x < 0 or origin.y < 0 or origin.x + grid_cell_size.x > source_pixel_size.x \
                        or origin.y + grid_cell_size.y > source_pixel_size.y:
                    return "Candidate grid cell exceeds source canvas: " + source_path
    if not frame_indices.is_empty():
        if columns == 0:
            return "Frame indices require an explicit candidate grid: " + source_path
        for index in frame_indices:
            if index < 0 or index >= columns * rows:
                return "Out-of-range candidate frame index: " + source_path
    var actions: Dictionary = {}
    for entry in clips:
        if not entry is WuxiaActorAnimationClip:
            return "Invalid candidate action Clip: " + source_path
        var clip := entry as WuxiaActorAnimationClip
        if columns == 0 or actions.has(clip.action) or not clip.valid_for(columns * rows):
            return "Invalid or duplicated candidate action Clip: " + source_path
        actions[clip.action] = true
    if asset_kind == "sprite" and target_world_height_px <= 0.0:
        return "Invalid candidate world height: " + source_path
    if not is_finite(reference_visible_height_px) or reference_visible_height_px < 0.0 \
            or not is_finite(display_scale_override) or display_scale_override < 0.0:
        return "Invalid candidate visual scale: " + source_path
    return ""
