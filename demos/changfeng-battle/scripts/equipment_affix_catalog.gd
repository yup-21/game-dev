extends RefCounted
## Immutable, indexed equipment affixes. A rolled affix belongs to an item UID,
## never to a shared item definition or a character-global stat table.
const Modifiers = preload("res://scripts/stat_modifier_system.gd")
const INDEX_PATH = "res://data/affixes/index.json"
const EQUIPMENT_SLOTS = ["weapon", "armor", "accessory"]
var definitions: Dictionary = {}
var load_error: String = ""

func _init(index_path: String = INDEX_PATH) -> void:
    if not FileAccess.file_exists(index_path):
        load_error = "Affix index missing: " + index_path
        return
    var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
    if not index is Dictionary or index.get("schema_version") != 1 or not index.get("affixes") is Array:
        load_error = "Invalid affix index"
        return
    var directory: String = index_path.get_base_dir() + "/"
    for filename in index.affixes:
        if not filename is String or filename.contains("/") or filename.contains("..") or not filename.ends_with(".json"):
            load_error = "Unsafe affix filename"
            definitions.clear()
            return
        var path: String = directory + filename
        if not FileAccess.file_exists(path):
            load_error = "Missing affix: " + filename
            definitions.clear()
            return
        var definition: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        if not _valid(definition) or definitions.has(str(definition.id)):
            load_error = "Invalid or duplicate affix: " + filename
            definitions.clear()
            return
        definitions[str(definition.id)] = definition.duplicate(true)

func _valid(definition: Variant) -> bool:
    if not definition is Dictionary or definition.get("schema_version") != 1:
        return false
    for key in definition:
        if key not in ["schema_version", "id", "name", "allowed_slots", "modifiers"]:
            return false
    if not definition.get("id") is String or str(definition.id).is_empty():
        return false
    if not definition.get("name") is String or str(definition.name).is_empty():
        return false
    if not definition.get("allowed_slots") is Array or definition.allowed_slots.is_empty():
        return false
    var seen: Dictionary = {}
    for slot in definition.allowed_slots:
        if slot not in EQUIPMENT_SLOTS or seen.has(slot):
            return false
        seen[slot] = true
    if not definition.get("modifiers") is Array or definition.modifiers.is_empty():
        return false
    for modifier in definition.modifiers:
        if not Modifiers.valid_spec(modifier) or modifier.has("stacks"):
            return false
    return true

func get_affix(id: String) -> Dictionary:
    return definitions.get(id, {}).duplicate(true)
