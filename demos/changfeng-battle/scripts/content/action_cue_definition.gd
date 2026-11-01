@tool
class_name WuxiaActionCueDefinition
extends Resource
## A named presentation cue only; BattleModel owns semantic outcomes.

@export var cue_name: String = ""
@export var at_sec: float = 0.0

func valid_for(duration_sec: float) -> bool:
    return not cue_name.is_empty() and is_finite(at_sec) \
        and at_sec >= 0.0 and at_sec <= duration_sec
