@tool
class_name WuxiaActorAnimationClip
extends Resource
## One presentation-only action, with absolute frame indices into its atlas.

@export_enum("idle", "move", "attack", "guard", "hit", "evade", "skill", "combo", "defeat")
var action: String = "idle"
@export var frames: PackedInt32Array = PackedInt32Array()
@export_range(1.0, 60.0, 0.5) var loop_fps: float = 12.0
@export var loop: bool = false

func valid_for(capacity: int) -> bool:
    if frames.is_empty() or frames.size() > 256 or loop_fps <= 0.0 or loop_fps > 60.0:
        return false
    if loop and action not in ["idle", "move"]:
        return false
    for index in frames:
        if index < 0 or index >= capacity:
            return false
    return true
