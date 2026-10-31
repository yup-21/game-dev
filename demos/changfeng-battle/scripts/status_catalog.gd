extends RefCounted
## Optional, independent buff catalog. Add one JSON file and index entry.
const Modifiers = preload("res://scripts/stat_modifier_system.gd")
const DEFAULT_INDEX = "res://data/buffs/index.json"
var definitions: Dictionary = {}
var load_error: String = ""

func _init(index_path: String = DEFAULT_INDEX) -> void:
    if not FileAccess.file_exists(index_path):
        load_error = "Buff index missing: " + index_path
        return
    var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
    if not index is Dictionary or index.get("schema_version") != 1 or not index.get("buffs") is Array:
        load_error = "Invalid buff index"
        return
    var root: String = index_path.get_base_dir() + "/"
    for filename in index.buffs:
        if not filename is String or filename.contains("/") or filename.contains("..") or not filename.ends_with(".json"):
            load_error = "Unsafe buff file name"
            return
        var path: String = root + filename
        if not FileAccess.file_exists(path):
            load_error = "Missing buff definition: " + filename
            return
        var definition: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        if not _valid(definition) or definitions.has(str(definition.id)):
            load_error = "Invalid or duplicate buff definition: " + filename
            return
        definitions[str(definition.id)] = definition.duplicate(true)

func _whole(value: Variant, minimum: int, maximum: int) -> bool:
    return Modifiers._whole(value,minimum,maximum)

func _valid(d: Variant) -> bool:
    if not d is Dictionary or d.get("schema_version") != 1: return false
    for key in d:
        if key not in ["schema_version","id","name","public","stack_limit","expiry","modifiers"]: return false
    if not d.get("id") is String or str(d.id).is_empty() or not d.get("name") is String or str(d.name).is_empty(): return false
    if not d.get("public") is bool or not _whole(d.get("stack_limit"),1,99): return false
    var expiry: Variant = d.get("expiry")
    if not expiry is Dictionary: return false
    if expiry.get("kind") == "permanent":
        if expiry.size() != 1: return false
    elif expiry.get("kind") == "global_ticks_after_apply":
        if expiry.size() != 2 or not _whole(expiry.get("duration"),1,1000000): return false
    else:
        return false
    if not d.get("modifiers",[]) is Array: return false
    for modifier in d.get("modifiers",[]):
        if not Modifiers.valid_spec(modifier) or modifier.has("stacks"): return false
    return true

func get_buff(id: String) -> Dictionary:
    return definitions.get(id,{}).duplicate(true)
