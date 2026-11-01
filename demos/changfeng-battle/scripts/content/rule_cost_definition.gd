@tool
class_name WuxiaRuleCostDefinition
extends Resource
@export var qi: int = 0
@export var has_hp: bool = false
@export var hp: int = 0

func to_record() -> Dictionary:
    var value: Dictionary = {"qi":qi}
    if has_hp: value["hp"] = hp
    return value
