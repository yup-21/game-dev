@tool
class_name WuxiaConditionDefinition
extends Resource
## Inspector-authored deterministic condition tree; never evaluates code.
@export_enum("leaf", "all", "any", "not") var mode: String = "leaf"
@export_enum("has_status", "self_status", "target_status", "timing",
    "previous_attack_tag", "technique_node", "qi_at_least",
    "attribute_at_least", "previous_attack_hit", "same_action_continuation") var predicate: String = "has_status"
@export var text_value: String = ""
@export var numeric_value: float = 0.0
@export var bool_value: bool = true
@export_enum("STR", "AGI", "CON", "MND") var attribute: String = "STR"
@export var technique_id: String = ""
@export var children: Array[Resource] = []

func to_record(depth: int = 0) -> Dictionary:
    if depth > 8:
        return {}
    if mode != "leaf":
        if mode == "not" and children.size() != 1:
            return {}
        if mode in ["all", "any"] and (children.is_empty() or children.size() > 32):
            return {}
        var normalized: Array = []
        for child in children:
            if not child is WuxiaConditionDefinition:
                return {}
            var spec: Dictionary = child.to_record(depth + 1)
            if spec.is_empty():
                return {}
            normalized.append(spec)
        if mode == "not":
            return {"not":normalized[0]}
        return {mode:normalized}
    if not children.is_empty():
        return {}
    var record: Dictionary = {"type":predicate}
    match predicate:
        "has_status", "self_status", "target_status", "timing", "previous_attack_tag":
            if text_value.is_empty():
                return {}
            record["value"] = text_value
        "technique_node":
            if text_value.is_empty() or technique_id.is_empty():
                return {}
            record["value"] = text_value
            record["technique_id"] = technique_id
        "attribute_at_least":
            if numeric_value < 0.0 or not is_finite(numeric_value):
                return {}
            record["value"] = numeric_value
            record["stat"] = attribute
        "qi_at_least":
            if numeric_value < 0.0 or not is_finite(numeric_value):
                return {}
            record["value"] = numeric_value
        "previous_attack_hit", "same_action_continuation":
            record["value"] = bool_value
        _:
            return {}
    return record
