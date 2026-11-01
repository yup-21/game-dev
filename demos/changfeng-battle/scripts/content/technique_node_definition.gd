@tool
class_name WuxiaTechniqueNodeDefinition
extends Resource
## Stage ability lives outside the card deck and advances its own state.

@export var node_id: String = ""
@export var display_name: String = ""
@export var available: bool = true
@export var unlock_rank: int = 1
@export var same_action_extra_qi: int = 0
@export var reset_on_interrupt: bool = true
@export var stage: String = ""
@export var next_node: String = ""
@export_enum("ACTION", "ATTACK_REACTION", "DEFENSE_REACTION") var timing: String = "ACTION"
@export var cost_qi: int = 0
@export_enum("self", "enemy_actor", "reachable_cell", "pending_root_attack",
    "opponent_unresolved_response_link") var target_kind: String = "self"
@export_range(0, 128, 1) var target_max_distance: int = 0
@export var attack_route: String = ""
@export_range(0, 128, 1) var attack_range: int = 0
@export var effects: Array[Resource] = []
@export var when: Resource

func to_record() -> Dictionary:
    var converted: Array = []
    for effect in effects:
        if not effect is WuxiaEffectDefinition and not effect is WuxiaTechniqueEffectDefinition:
            return {}
        var record: Dictionary = effect.to_record()
        if record.is_empty():
            return {}
        converted.append(record)
    var result: Dictionary = {
        "id": node_id,
        "next": next_node if not next_node.is_empty() else node_id,
        "timing": timing, "cost": {"qi": cost_qi},
        "target": {"kind": target_kind}, "effects": converted
    }
    if target_max_distance > 0: result["target"]["max_distance"] = target_max_distance
    if not attack_route.is_empty():
        result["attack_profile"] = {"route":attack_route, "range":attack_range}
    if not stage.is_empty(): result["stage"] = stage
    if not display_name.is_empty(): result["name"] = display_name
    if not available: result["available"] = false
    if unlock_rank != 1: result["unlock_rank"] = unlock_rank
    if same_action_extra_qi != 0: result["same_action_extra_qi"] = same_action_extra_qi
    if not reset_on_interrupt: result["reset_on_interrupt"] = false
    if when != null:
        if not when is WuxiaConditionDefinition:
            return {}
        var condition: Dictionary = when.to_record()
        if condition.is_empty():
            return {}
        result["when"] = condition
    return result
