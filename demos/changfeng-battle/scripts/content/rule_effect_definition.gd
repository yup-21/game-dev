@tool
class_name WuxiaRuleEffectDefinition
extends Resource
## Typed semantic effect and recursively typed nested effect branches.
@export var effect_type: String = ""
@export var parameters: Dictionary = {}
@export var effects: Array[Resource] = []
@export var on_hit: Array[Resource] = []
@export var on_success: Array[Resource] = []
@export var on_contested: Array[Resource] = []
@export var on_failure: Array[Resource] = []
@export var preserve_empty_effects: bool = false
@export var preserve_empty_on_hit: bool = false
@export var preserve_empty_on_success: bool = false
@export var preserve_empty_on_contested: bool = false
@export var preserve_empty_on_failure: bool = false

func to_record(depth: int = 0) -> Dictionary:
    if effect_type.is_empty() or depth > 6 or parameters.has("type"): return {}
    var d: Dictionary = parameters.duplicate(true)
    d["type"] = effect_type
    for key in ["effects","on_hit","on_success","on_contested","on_failure"]:
        var children: Array = get(key)
        if children.is_empty() and not bool(get("preserve_empty_" + key)): continue
        if d.has(key): return {}
        var values: Array = []
        for item in children:
            if not item is WuxiaRuleEffectDefinition: return {}
            var child: Dictionary = item.to_record(depth + 1)
            if child.is_empty(): return {}
            values.append(child)
        d[key] = values
    return d
