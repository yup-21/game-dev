@tool
class_name WuxiaRuleUsageDefinition
extends Resource
@export var usage_id: String = ""
@export var display_name: String = ""
@export_enum("ACTION","ATTACK_REACTION","DEFENSE_REACTION") var timing: String = "ACTION"
@export var cost: WuxiaRuleCostDefinition
@export var target: WuxiaRuleTargetDefinition
@export var attack_profile: WuxiaRuleAttackProfileDefinition
@export var has_once_per_action: bool = false
@export var once_per_action: bool = false
@export var effects: Array[Resource] = []

func to_record() -> Dictionary:
    if usage_id.is_empty() or cost == null or target == null: return {}
    var cost_data: Dictionary = cost.to_record()
    var target_data: Dictionary = target.to_record()
    if cost_data.is_empty() or target_data.is_empty(): return {}
    var effect_data: Array = []
    for entry in effects:
        if not entry is WuxiaRuleEffectDefinition: return {}
        var d: Dictionary = entry.to_record()
        if d.is_empty(): return {}
        effect_data.append(d)
    var result: Dictionary = {"id":usage_id,"timing":timing,
        "cost":cost_data,"target":target_data,"effects":effect_data}
    if not display_name.is_empty(): result["name"] = display_name
    if attack_profile != null:
        var profile: Dictionary = attack_profile.to_record()
        if profile.is_empty(): return {}
        result["attack_profile"] = profile
    if has_once_per_action: result["once_per_action"] = once_per_action
    return result
