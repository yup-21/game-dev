@tool
class_name WuxiaTechniqueTriggerDefinition
extends Resource
@export var card_id: String = ""
@export var usage_id: String = ""
@export var ready_stage: String = ""

func to_record() -> Dictionary:
    if card_id.is_empty() or usage_id.is_empty() or ready_stage.is_empty():
        return {}
    return {"card_id": card_id, "usage_id": usage_id, "ready_stage": ready_stage}
