extends RefCounted
## Item definitions are immutable data. Runtime inventory owns all mutable instances.
const Modifiers = preload("res://scripts/stat_modifier_system.gd")
const Affixes = preload("res://scripts/equipment_affix_catalog.gd")
const DEFAULT_INDEX = "res://data/items/index.json"
const SLOTS = ["weapon","armor","accessory"]
const CONSUMABLE_EFFECTS = ["heal_hp","gain_qi","add_shield"]
var definitions: Dictionary = {}
var affixes
var load_error: String = ""

func _init(index_path: String = DEFAULT_INDEX, affix_catalog = null) -> void:
    affixes = Affixes.new() if affix_catalog == null else affix_catalog
    if not affixes.load_error.is_empty():
        load_error = affixes.load_error
        return
    if not FileAccess.file_exists(index_path):
        load_error = "Item index missing: " + index_path
        return
    var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
    if not index is Dictionary or index.get("schema_version") != 1 or not index.get("items") is Array:
        load_error = "Invalid item index"
        return
    var base: String = index_path.get_base_dir() + "/"
    for filename in index.items:
        if not filename is String or filename.contains("/") or filename.contains("..") or not filename.ends_with(".json"):
            load_error = "Unsafe item file name"
            return
        var file_path: String = base + filename
        if not FileAccess.file_exists(file_path):
            load_error = "Missing item definition: " + filename
            return
        var definition: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
        if not _valid(definition) or definitions.has(str(definition.id)):
            load_error = "Invalid or duplicated item definition: " + filename
            return
        definitions[str(definition.id)] = definition.duplicate(true)

func _valid(definition: Variant) -> bool:
    if not definition is Dictionary or definition.get("schema_version") != 1: return false
    for key in definition:
        if key not in ["schema_version","id","name","description","kind","slot","stack_limit","modifiers","effects","affix_pool","max_affixes"]: return false
    for key in ["id","name","description","kind"]:
        if not definition.get(key) is String or str(definition[key]).is_empty(): return false
    if definition.kind not in ["equipment","consumable"]: return false
    if definition.kind == "equipment":
        if definition.get("slot") not in SLOTS or definition.get("stack_limit") != 1: return false
        if not definition.get("modifiers") is Array or definition.modifiers.is_empty(): return false
        if definition.has("effects"): return false
        if definition.has("affix_pool") != definition.has("max_affixes"): return false
        if definition.has("affix_pool"):
            if not definition.affix_pool is Array or definition.affix_pool.is_empty(): return false
            if not Modifiers._whole(definition.max_affixes,1,3): return false
            if definition.affix_pool.size() < int(definition.max_affixes): return false
            var seen: Dictionary = {}
            for id in definition.affix_pool:
                if not id is String or seen.has(id): return false
                var affix: Dictionary = affixes.get_affix(str(id))
                if affix.is_empty() or not affix.allowed_slots.has(definition.slot): return false
                seen[id] = true
        for modifier in definition.modifiers:
            if not Modifiers.valid_spec(modifier) or modifier.has("stacks"): return false
    else:
        if definition.has("slot") or definition.has("modifiers") or definition.has("affix_pool") or definition.has("max_affixes"): return false
        if not Modifiers._whole(definition.get("stack_limit"),1,99): return false
        if not definition.get("effects") is Array or definition.effects.is_empty(): return false
        for effect in definition.effects:
            if not effect is Dictionary or effect.size()!=2 or effect.get("type") not in CONSUMABLE_EFFECTS: return false
            if not Modifiers._whole(effect.get("amount"),1,100): return false
    return true

func get_item(id: String) -> Dictionary:
    return definitions.get(id,{}).duplicate(true)
