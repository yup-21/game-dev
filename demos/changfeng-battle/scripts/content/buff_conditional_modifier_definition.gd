@tool
class_name WuxiaBuffConditionalModifierDefinition
extends Resource
## Reactive to status lifecycle only; never runs arbitrary script content.
@export var when: Resource
@export var modifiers: Array[Dictionary] = []

func to_record() -> Dictionary:
    if not when is WuxiaConditionDefinition or modifiers.is_empty():
        return {}
    var condition: Dictionary = when.to_record()
    if condition.is_empty(): return {}
    return {"when":condition,"modifiers":modifiers.duplicate(true)}
