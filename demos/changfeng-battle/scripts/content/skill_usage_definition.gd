@tool
class_name WuxiaSkillUsageDefinition
extends Resource
## An action/reaction entrance to a reusable skill's effects.

@export var usage_id: String = ""
@export var display_name: String = ""
@export_enum("ACTION", "ATTACK_REACTION", "DEFENSE_REACTION") var timing: String = "ACTION"
@export var cost_qi: int = 0
@export var cost_hp: int = 0
@export_enum("self", "enemy_actor", "reachable_cell", "pending_root_attack",
    "opponent_unresolved_response_link") var target_kind: String = "self"
@export var target_max_distance: int = 1
@export_enum("thrust", "sweep", "crushing") var attack_route: String = "thrust"
@export var attack_break_bonus: int = 0
@export var once_per_action: bool = false
@export var effects: Array[Resource] = []
@export var when: Resource

func to_record() -> Dictionary:
    var converted: Array = []
    for effect in effects:
        if not effect is WuxiaEffectDefinition:
            return {}
        var record: Dictionary = effect.to_record()
        if record.is_empty():
            return {}
        converted.append(record)
    var target: Dictionary = {"kind": target_kind}
    if target_kind in ["enemy_actor", "reachable_cell"]:
        target["max_distance"] = target_max_distance
    var result: Dictionary = {
        "id": usage_id, "name": display_name, "timing": timing,
        "cost": {"qi": cost_qi, "hp": cost_hp}, "target": target,
        "effects": converted, "once_per_action": once_per_action
    }
    if target_kind == "enemy_actor":
        result["attack_profile"] = {
            "route": attack_route, "break_bonus": attack_break_bonus,
            "range": target_max_distance
        }
    if when != null:
        if not when is WuxiaConditionDefinition:
            return {}
        var condition: Dictionary = when.to_record()
        if condition.is_empty():
            return {}
        result["when"] = condition
    return result
