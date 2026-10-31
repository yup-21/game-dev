@tool
class_name WuxiaEffectDefinition
extends Resource
## Inspector-authored effect component; no executable expressions in content data.

@export var effect_type: String = ""
@export var target: String = "self"
@export var amount: float = 0.0
@export var parameters: Dictionary = {}
@export var effects: Array[Resource] = []
@export var on_hit: Array[Resource] = []

func to_record(depth: int = 0) -> Dictionary:
    if depth > 6 or effect_type.is_empty() or parameters.has("type") or parameters.has("target"):
        return {}
    var record: Dictionary = parameters.duplicate(true)
    record["type"] = effect_type
    record["target"] = target
    if effect_type in ["deal_damage", "gain_qi", "add_shield", "heal_hp",
            "r20_qi_by_status", "deal_posture", "recover_posture"]:
        if parameters.has("amount"):
            return {}
        record["amount"] = amount
    for key in ["effects", "on_hit"]:
        var children: Array = get(key)
        if children.is_empty():
            continue
        if record.has(key):
            return {}
        var normalized: Array = []
        for item in children:
            if not item is WuxiaEffectDefinition:
                return {}
            var child: Dictionary = item.to_record(depth + 1)
            if child.is_empty():
                return {}
            normalized.append(child)
        record[key] = normalized
    return record
