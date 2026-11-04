@tool
class_name WuxiaActorAnimationProfile
extends Resource
const CombatScale = preload("res://scripts/combat_scale.gd")
## Character-owned visual contract. Never mutates BattleModel or game state.
## Unlike the historical 6x4 pose sheet, actions may use distinct frame ranges.

## Existing nine-action atlases remain valid during migration.
const REQUIRED_ACTIONS := ["idle", "move", "attack", "guard", "hit",
    "evade", "skill", "combo", "defeat"]
## Native twelve-action contract; attack1..4 are semantic slots, not weapon types.
const BASE_ACTIONS := ["idle", "walk", "run", "attack1", "attack2",
    "attack3", "attack4", "skill", "evade", "guard", "hit", "defeat"]

@export var atlas: Texture2D
@export_range(1, 64) var columns: int = 6
@export_range(1, 64) var rows: int = 4
## Single-size player/normal enemy sprites. Rendered opaque idle height is
## normalized to this many combat units; source atlas pixel resolution may vary.
@export var reference_height_units: float = CombatScale.ACTOR_HEIGHT_UNITS
@export var feet_offset: Vector2 = Vector2(0, -102)
## Final visual feet nudge in world pixels after alpha-based sizing.
## Positive Y moves the visible sprite down; negative Y moves it up.
## Useful when a sword/cape tip hangs lower than the actual boots.
@export var feet_adjust: Vector2 = Vector2.ZERO
@export var actor_scale: Vector2 = Vector2(0.53, 0.53)
@export var faces_left_unflipped: bool = false
@export var clips: Array[Resource] = []

func valid_profile() -> bool:
    if atlas == null or columns < 1 or rows < 1 or columns > 64 or rows > 64:
        return false
    if atlas.get_width() % columns != 0 or atlas.get_height() % rows != 0:
        return false
    if atlas.get_width() < columns or atlas.get_height() < rows:
        return false
    if actor_scale.x <= 0.0 or actor_scale.y <= 0.0 or \
            not is_finite(actor_scale.x) or not is_finite(actor_scale.y) or \
            absf(actor_scale.x - actor_scale.y) > 0.001 or \
            not is_finite(reference_height_units) or \
            absf(reference_height_units - CombatScale.ACTOR_HEIGHT_UNITS) > 0.001:
        return false
    var seen: Dictionary = {}
    for clip in clips:
        if not clip is WuxiaActorAnimationClip:
            return false
        var authored: WuxiaActorAnimationClip = clip as WuxiaActorAnimationClip
        if seen.has(authored.action):
            return false
        if not authored.valid_for(columns * rows):
            return false
        seen[authored.action] = true
    var legacy_complete: bool = true
    var base_complete: bool = true
    for action in REQUIRED_ACTIONS:
        if not seen.has(action):
            legacy_complete = false
    for action in BASE_ACTIONS:
        if not seen.has(action):
            base_complete = false
    return legacy_complete or base_complete

func clip_for(action: String) -> WuxiaActorAnimationClip:
    for clip in clips:
        var authored: WuxiaActorAnimationClip = clip as WuxiaActorAnimationClip
        if authored != null and authored.action == action:
            return authored
    return null
