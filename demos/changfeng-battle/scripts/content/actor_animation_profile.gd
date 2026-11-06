@tool
class_name WuxiaActorAnimationProfile
extends Resource
const CombatScale = preload("res://scripts/combat_scale.gd")
## A character-owned visual action library. Legacy nine-action resources stay valid.

## Keep the historical constant stable for existing art contracts and tests.
const REQUIRED_ACTIONS := ["idle", "move", "attack", "guard", "hit",
    "evade", "skill", "combo", "defeat"]
const LEGACY_REQUIRED_ACTIONS := REQUIRED_ACTIONS
const MODERN_REQUIRED_ACTIONS := ["idle", "walk", "run", "attack1", "attack2",
    "attack3", "attack4", "skill", "evade", "guard", "hit", "defeat"]
# Stable public name consumed by earlier twelve-action fixtures.
const BASE_ACTIONS := MODERN_REQUIRED_ACTIONS

@export var atlas: Texture2D
## Preferred authorable animation source. Each action and its frame timing live in
## Godot SpriteFrames; legacy Clip indices are read only when this is empty.
@export var native_frames: SpriteFrames
@export_range(1, 64) var columns: int = 6
@export_range(1, 64) var rows: int = 4
@export var reference_height_units: float = CombatScale.ACTOR_HEIGHT_UNITS
@export var feet_offset: Vector2 = Vector2(0, -102)
@export var feet_adjust: Vector2 = Vector2.ZERO
@export var actor_scale: Vector2 = Vector2(0.53, 0.53)
## Default: normalize the authored idle silhouette to 200 world pixels.
## Disable only when an explicitly authored uniform actor_scale is desired.
@export var auto_fit_height: bool = true
@export var faces_left_unflipped: bool = false
## Optional, single-step resource mappings. Only a direct existing Clip may be
## selected as a target. Missing mappings never use an engine-defined alias.
@export var action_fallbacks: Dictionary = {}
@export var clips: Array[Resource] = []

func valid_profile() -> bool:
    if columns < 1 or rows < 1 or columns > 64 or rows > 64:
        return false
    if atlas != null and (atlas.get_width() < columns or atlas.get_height() < rows \
            or atlas.get_width() % columns != 0 or atlas.get_height() % rows != 0):
        return false
    if actor_scale.x <= 0.0 or actor_scale.y <= 0.0 \
            or not is_finite(actor_scale.x) or not is_finite(actor_scale.y) \
            or absf(actor_scale.x - actor_scale.y) > 0.001 \
            or not is_finite(reference_height_units) \
            or absf(reference_height_units - CombatScale.ACTOR_HEIGHT_UNITS) > 0.001:
        return false
    if native_frames != null:
        if not native_frames.has_animation("idle") or \
                native_frames.get_frame_count("idle") == 0:
            return false
        for action in native_frames.get_animation_names():
            if not action.is_valid_identifier() or action != action.to_lower() or \
                    native_frames.get_frame_count(action) < 1 or \
                    native_frames.get_frame_count(action) > 256 or \
                    not is_finite(native_frames.get_animation_speed(action)) or \
                    native_frames.get_animation_speed(action) <= 0:
                return false
            for index in range(native_frames.get_frame_count(action)):
                if native_frames.get_frame_texture(action, index) == null or \
                        native_frames.get_frame_duration(action, index) <= 0.0:
                    return false
        return true
    var seen: Dictionary = {}
    var expected_cell := Vector2i.ZERO
    for entry in clips:
        if not entry is WuxiaActorAnimationClip:
            return false
        var clip: WuxiaActorAnimationClip = entry as WuxiaActorAnimationClip
        var texture: Texture2D = clip.effective_atlas(atlas)
        if texture == null or seen.has(clip.action) or not clip.valid_for(
                columns * rows if clip.atlas == null and atlas != null else 0):
            return false
        var cell := Vector2i(texture.get_width() / clip.effective_columns(columns),
            texture.get_height() / clip.effective_rows(rows))
        if expected_cell == Vector2i.ZERO:
            expected_cell = cell
        elif expected_cell != cell:
            # Different sheet dimensions are fine, but each pose's pixel scale
            # must use the same reference cell to prevent visual size jumps.
            return false
        seen[clip.action] = true
    # Reject invalid mappings immediately, even if a direct action is present.
    # A target must exist as a physical Clip, so chained mappings cannot occur.
    for action in action_fallbacks:
        if not action is String or not action.is_valid_identifier() or action != action.to_lower():
            return false
        var target: Variant = action_fallbacks[action]
        if not target is String or not target.is_valid_identifier() or target != target.to_lower() \
                or str(action) == str(target) or not seen.has(str(target)):
            return false
    if not action_fallbacks.is_empty():
        for required in MODERN_REQUIRED_ACTIONS:
            if not seen.has(required) and not action_fallbacks.has(required):
                return false
    var modern := true
    for action in MODERN_REQUIRED_ACTIONS:
        if not seen.has(action):
            modern = false
            break
    if modern:
        return true
    for action in LEGACY_REQUIRED_ACTIONS:
        if not seen.has(action):
            return false
    return true

func clip_for(action: String) -> WuxiaActorAnimationClip:
    for entry in clips:
        var clip: WuxiaActorAnimationClip = entry as WuxiaActorAnimationClip
        if clip != null and clip.action == action:
            return clip
    return null

func resolved_clip_for(action: String) -> WuxiaActorAnimationClip:
    var exact: WuxiaActorAnimationClip = clip_for(action)
    if exact != null:
        return exact
    if not action_fallbacks.has(action):
        return null
    # One level only: look up a real clip, never follow another mapping.
    return clip_for(str(action_fallbacks[action]))

func idle_atlas() -> Texture2D:
    if native_frames != null and native_frames.has_animation("idle") and \
            native_frames.get_frame_count("idle") > 0:
        return native_frames.get_frame_texture("idle", 0)
    var idle: WuxiaActorAnimationClip = clip_for("idle")
    return idle.effective_atlas(atlas) if idle != null else atlas

func idle_columns() -> int:
    if native_frames != null:
        return 1
    var idle: WuxiaActorAnimationClip = clip_for("idle")
    return idle.effective_columns(columns) if idle != null else columns

func idle_rows() -> int:
    if native_frames != null:
        return 1
    var idle: WuxiaActorAnimationClip = clip_for("idle")
    return idle.effective_rows(rows) if idle != null else rows
