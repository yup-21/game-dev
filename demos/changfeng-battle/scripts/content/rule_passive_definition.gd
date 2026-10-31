@tool
class_name WuxiaRulePassiveDefinition
extends Resource
@export var passive_id: String = ""
@export var display_name: String = ""
@export var ranks: Dictionary = {}

func to_record() -> Dictionary:
    if passive_id.is_empty() or display_name.is_empty(): return {}
    return {"id":passive_id,"name":display_name,"ranks":ranks.duplicate(true)}
