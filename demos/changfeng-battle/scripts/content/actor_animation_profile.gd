@tool
class_name WuxiaActorAnimationProfile
extends Resource
const CombatScale = preload("res://scripts/combat_scale.gd")
## A character-owned visual action library. Legacy nine-action resources stay valid.

const REQUIRED_ACTIONS := ["idle", "walk", "run", "attack1", "attack2",
    "attack3", "attack4", "skill", "evade", "guard", "hit", "defeat"]
const LEGACY_REQUIRED_ACTIONS := ["idle", "move", "attack", "guard", "hit",
    "evade", "skill", "combo", "defeat"]
const LEGACY_ALIASES := {
    "walk": "move", "run": "move",
    "attack1": "attack", "attack2": "attack",
    "attack3": "attack", "attack4": "attack"
}

@export var atlas: Texture2D
@export_range(1, 64) var columns: int = 6
@export_range(1, 64) var rows: int = 4
@export var reference_height_units: float = CombatScale.ACTOR_HEIGHT_UNITS
@export var feet_offset: Vector2 = Vector2(0, -102)
@export var feet_adjust: Vector2 = Vector2.ZERO
@export var actor_scale: Vector2 = Vector2(0.53, 0.53)
@export var faces_left_unflipped: bool = false
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
    var modern := true
    for action in REQUIRED_ACTIONS:
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
    return clip_for(str(LEGACY_ALIASES.get(action, "")))

func idle_atlas() -> Texture2D:
    var idle: WuxiaActorAnimationClip = clip_for("idle")
    return idle.effective_atlas(atlas) if idle != null else atlas

func idle_columns() -> int:
    var idle: WuxiaActorAnimationClip = clip_for("idle")
    return idle.effective_columns(columns) if idle != null else columns

func idle_rows() -> int:
    var idle: WuxiaActorAnimationClip = clip_for("idle")
    return idle.effective_rows(rows) if idle != null else rows
