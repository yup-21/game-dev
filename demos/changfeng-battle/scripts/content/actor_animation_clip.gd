@tool
class_name WuxiaActorAnimationClip
extends Resource
## A visual-only action. Its optional atlas can be independent of the profile atlas.
## Root offsets move Sprite2D locally, never the combat actor or hitbox.

@export var action: String = "idle"
@export var atlas: Texture2D
@export_range(1, 64) var columns: int = 1
@export_range(1, 64) var rows: int = 1
@export var frames: PackedInt32Array = PackedInt32Array()
@export_range(1.0, 60.0, 0.5) var loop_fps: float = 12.0
@export var loop: bool = false
## Optional per-frame seconds. Ratios are preserved when a non-loop semantic
## event specifies a total duration; loops use their authored total seconds.
@export var frame_durations: PackedFloat32Array = PackedFloat32Array()
## Optional local visual offsets, one per frame, in world pixels.
@export var root_offsets: PackedVector2Array = PackedVector2Array()

func effective_atlas(fallback: Texture2D) -> Texture2D:
    return atlas if atlas != null else fallback

func effective_columns(fallback: int) -> int:
    return columns if atlas != null else fallback

func effective_rows(fallback: int) -> int:
    return rows if atlas != null else fallback

func valid_for(fallback_capacity: int) -> bool:
    if action.is_empty() or action.length() > 64 or not action.is_valid_identifier() or action != action.to_lower():
        return false
    if frames.is_empty() or frames.size() > 256 or not is_finite(loop_fps) \
            or loop_fps <= 0.0 or loop_fps > 60.0 or (action == "defeat" and loop):
        return false
    var capacity: int = fallback_capacity
    if atlas != null:
        if columns < 1 or rows < 1 or columns > 64 or rows > 64 \
                or atlas.get_width() < columns or atlas.get_height() < rows \
                or atlas.get_width() % columns != 0 or atlas.get_height() % rows != 0:
            return false
        capacity = columns * rows
    if capacity < 1:
        return false
    for index in frames:
        if index < 0 or index >= capacity:
            return false
    if not frame_durations.is_empty():
        if frame_durations.size() != frames.size():
            return false
        for duration in frame_durations:
            if not is_finite(duration) or duration <= 0.0:
                return false
    if not root_offsets.is_empty():
        if root_offsets.size() != frames.size():
            return false
        for offset in root_offsets:
            if not is_finite(offset.x) or not is_finite(offset.y):
                return false
        if not loop and action != "defeat" and root_offsets[-1].length() > 0.01:
            return false
    return true
