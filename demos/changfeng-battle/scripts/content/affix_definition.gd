@tool
class_name WuxiaAffixDefinition
extends WuxiaContentDefinition
## Editor-authored equipment affix; the roll belongs to the equipped item UID.

@export var display_name: String = ""
@export var allowed_slots: Array[String] = []
@export var modifiers: Array[Dictionary] = []

func content_kind() -> String:
    return "affix"

func to_record() -> Dictionary:
    return {
        "schema_version": schema_version,
        "id": content_id,
        "name": display_name,
        "allowed_slots": allowed_slots.duplicate(),
        "modifiers": modifiers.duplicate(true)
    }
