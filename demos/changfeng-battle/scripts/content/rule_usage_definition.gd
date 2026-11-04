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
@export var vfx_slot: String = ""
@export var vfx_trigger: String = ""
## Legacy explicit PackedScene binding; distinct from the native VFX atlas slot.
@export var animation_id: String = ""
@export var vfx_scene: PackedScene
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
    if not vfx_slot.is_empty(): result["vfx_slot"] = vfx_slot
    if not vfx_trigger.is_empty(): result["vfx_trigger"] = vfx_trigger
    # Both action fields are explicit; mismatched duplicates are a configuration error.
    if not animation_id.is_empty():
        if not animation_id.is_valid_identifier() or animation_id != animation_id.to_lower() \
                or (not animation_action.is_empty() and animation_id != animation_action):
            return {}
        result["animation_id"] = animation_id
    if vfx_scene != null:
        if not vfx_slot.is_empty() or not vfx_scene.resource_path.begins_with("res://") \
                or not ResourceLoader.exists(vfx_scene.resource_path):
            return {}
        result["vfx_path"] = vfx_scene.resource_path
    if has_once_per_action: result["once_per_action"] = once_per_action
    return result
