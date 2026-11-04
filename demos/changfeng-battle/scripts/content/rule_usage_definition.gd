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
@export var animation_action: String = ""
@export var vfx_slot: WuxiaVFXDefinition
@export var vfx_trigger: String = ""
@export var effects: Array[Resource] = []

func to_record() -> Dictionary:
    if not animation_action.is_empty() and (not animation_action.is_valid_identifier() or animation_action != animation_action.to_lower()):
        return {}
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
    if not animation_action.is_empty(): result["animation_action"] = animation_action
    if vfx_slot != null:
        var slot_record: Dictionary = vfx_slot.to_record()
        if vfx_trigger.is_empty() or slot_record.is_empty() or \
                not vfx_slot.resource_path.begins_with("res://") or \
                not ResourceLoader.exists(vfx_slot.resource_path):
            push_error("Rule usage %s has an invalid VFX Resource %s (path=%s, record=%s, trigger=%s)" % \
                [usage_id, vfx_slot.content_id, vfx_slot.resource_path, str(slot_record), vfx_trigger])
            return {}
        result["vfx_slot"] = vfx_slot.content_id
    if not vfx_trigger.is_empty(): result["vfx_trigger"] = vfx_trigger
    if has_once_per_action: result["once_per_action"] = once_per_action
    return result
