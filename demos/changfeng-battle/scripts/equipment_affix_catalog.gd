extends RefCounted
## Immutable, indexed equipment affixes. A rolled affix belongs to an item UID,
## never to a shared item definition or a character-global stat table.
const Modifiers = preload("res://scripts/stat_modifier_system.gd")
const NativeContent = preload("res://scripts/content/content_registry.gd")
const EQUIPMENT_SLOTS = ["weapon", "armor", "accessory"]
var definitions: Dictionary = {}
var load_error: String = ""

func _init(manifest_path: String = NativeContent.DEFAULT_MANIFEST) -> void:
    var native = NativeContent.new(manifest_path)
    if not native.load_error.is_empty():
        load_error = native.load_error
        return
    for definition in native.entries("affix").values():
        if not _valid(definition) or definitions.has(str(definition.id)):
            load_error = "Invalid or duplicate native affix"
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
