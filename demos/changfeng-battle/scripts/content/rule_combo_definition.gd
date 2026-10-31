@tool
class_name WuxiaRuleComboDefinition
extends Resource
@export var combo_id: String = ""
@export var display_name: String = ""
@export var mode: String = ""
@export var sequence: Array[Resource] = []
@export var scope: String = ""
@export var has_max_activations: bool = false
@export var max_activations_per_action: int = 1
@export var effects: Array[Resource] = []
@export var attack_card_id: String = ""
@export var attack_usage_id: String = ""
@export var target_has_status: String = ""
@export var has_target_posture_at_least: bool = false
@export var target_posture_at_least: int = 0

func to_record() -> Dictionary:
    if combo_id.is_empty() or display_name.is_empty() or mode.is_empty(): return {}
    var d: Dictionary = {"id":combo_id,"name":display_name,"mode":mode}
    if not sequence.is_empty():
        var steps: Array = []
        for entry in sequence:
            if not entry is WuxiaRuleComboStepDefinition: return {}
            var step: Dictionary = entry.to_record()
            if step.is_empty(): return {}
            steps.append(step)
        d["sequence"] = steps
    if not scope.is_empty(): d["scope"] = scope
    if has_max_activations: d["max_activations_per_action"] = max_activations_per_action
    var effects_data: Array = []
    for effect in effects:
        if not effect is WuxiaRuleEffectDefinition: return {}
        var e: Dictionary = effect.to_record()
        if e.is_empty(): return {}
        effects_data.append(e)
    d["effects"] = effects_data
    if not attack_card_id.is_empty(): d["attack_card_id"] = attack_card_id
    if not attack_usage_id.is_empty(): d["attack_usage_id"] = attack_usage_id
    if not target_has_status.is_empty(): d["target_has_status"] = target_has_status
    if has_target_posture_at_least: d["target_posture_at_least"] = target_posture_at_least
    return d
