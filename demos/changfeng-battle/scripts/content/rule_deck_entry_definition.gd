@tool
class_name WuxiaRuleDeckEntryDefinition
extends Resource
@export var card_id: String = ""
@export_range(1, 12, 1) var count: int = 1

func to_record() -> Dictionary:
    if card_id.is_empty() or count < 1 or count > 12: return {}
    return {"card_id": card_id, "count": count}
