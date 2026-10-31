@tool
class_name WuxiaLegacyMappingEntryDefinition
extends Resource
@export var old_id: String = ""
@export var card_id: String = ""
@export var usage_id: String = ""
@export_multiline var note: String = ""
@export var alternative_old_usage: String = ""
@export var alternative_new_usage: String = ""

func to_record() -> Dictionary:
    if old_id.is_empty() or card_id.is_empty() or usage_id.is_empty():
        return {}
    var data: Dictionary = {"card_id":card_id,"usage_id":usage_id}
    if not note.is_empty(): data["note"] = note
    return data

func resolve(old_usage: String) -> Dictionary:
    var resolved: String = usage_id
    if not alternative_old_usage.is_empty() and old_usage == alternative_old_usage:
        resolved = alternative_new_usage
    return {"definition_id":card_id,"card_id":card_id,"usage_id":resolved}
