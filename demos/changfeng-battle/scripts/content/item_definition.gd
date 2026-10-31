@tool
class_name WuxiaItemDefinition
extends WuxiaContentDefinition
## Equipment / consumable definition. Item UIDs and stack counts stay in InventoryRuntime.

@export var display_name: String = ""
@export_multiline var description: String = ""
@export_enum("consumable", "equipment") var kind: String = "consumable"
@export_enum("weapon", "armor", "accessory") var slot: String = "weapon"
@export_range(1, 99, 1) var stack_limit: int = 1
@export var modifiers: Array[Dictionary] = []
@export var effects: Array[Dictionary] = []
@export var affix_pool: Array[String] = []
@export_range(0, 3, 1) var max_affixes: int = 0

func content_kind() -> String:
    return "item"

func to_record() -> Dictionary:
    var record: Dictionary = {
        "schema_version": schema_version,
        "id": content_id,
        "name": display_name,
        "description": description,
        "kind": kind,
        "stack_limit": 1 if kind == "equipment" else stack_limit
    }
    if kind == "equipment":
        record["slot"] = slot
        record["modifiers"] = modifiers.duplicate(true)
        if not affix_pool.is_empty() or max_affixes > 0:
            record["affix_pool"] = affix_pool.duplicate()
            record["max_affixes"] = max_affixes
    else:
        record["effects"] = effects.duplicate(true)
    return record
