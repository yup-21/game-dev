@tool
class_name WuxiaActorAnimationProfile
extends Resource
## Character-owned visual contract. Never mutates BattleModel or game state.
## Unlike the historical 6x4 pose sheet, actions may use distinct frame ranges.

const REQUIRED_ACTIONS := ["idle", "move", "attack", "guard", "hit",
    "evade", "skill", "combo", "defeat"]

@export var atlas: Texture2D
@export_range(1, 64) var columns: int = 6
@export_range(1, 64) var rows: int = 4
@export var feet_offset: Vector2 = Vector2(0, -102)
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
    if actor_scale.x <= 0.0 or actor_scale.y <= 0.0:
        return false
    var seen: Dictionary = {}
    for clip in clips:
        if not clip is WuxiaActorAnimationClip:
            return false
        var authored: WuxiaActorAnimationClip = clip as WuxiaActorAnimationClip
        if not REQUIRED_ACTIONS.has(authored.action) or seen.has(authored.action):
            return false
        if not authored.valid_for(columns * rows):
            return false
        seen[authored.action] = true
    for action in REQUIRED_ACTIONS:
        if not seen.has(action):
            return false
    return true

func clip_for(action: String) -> WuxiaActorAnimationClip:
    for clip in clips:
        var authored: WuxiaActorAnimationClip = clip as WuxiaActorAnimationClip
        if authored != null and authored.action == action:
            return authored
    return null
