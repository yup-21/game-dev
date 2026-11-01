@tool
class_name WuxiaStartingItemDefinition
extends Resource
## Authored inventory seed for a new CharacterRuntime, never an item instance.

@export var item_id: String = ""
@export_range(1, 99, 1) var count: int = 1
@export var equip: bool = false
@export var affixes: Array[String] = []

func to_record() -> Dictionary:
    return {
        "item_id": item_id,
        "count": count,
        "equip": equip,
        "affixes": affixes.duplicate()
    }
