extends RefCounted
## Imports native Resources into existing domain catalogs, without owning gameplay.
## All entries are checked before any record becomes visible to a consumer.

const Manifest = preload("res://scripts/content/content_manifest.gd")
const Definition = preload("res://scripts/content/content_definition.gd")
const DEFAULT_MANIFEST = "res://data/content_manifest.tres"
# Production manifests are immutable for the lifetime of one running game.
# Returning deep copies keeps battle-owned catalogs independent.
static var _default_cache_ready: bool = false
static var _default_cache: Dictionary = {}


var definitions: Dictionary = {"character": {}, "buff": {}, "item": {}, "skill": {}, "technique": {}, "effect_handler": {}}
var load_error: String = ""

func _init(path: String = DEFAULT_MANIFEST) -> void:
    if path == DEFAULT_MANIFEST and _default_cache_ready:
        definitions = _default_cache.duplicate(true)
        return
    if not ResourceLoader.exists(path):
        load_error = "Native content manifest missing: " + path
        return
    var manifest: Resource = ResourceLoader.load(path)
    if import_manifest(manifest) and path == DEFAULT_MANIFEST:
        _default_cache = definitions.duplicate(true)
        _default_cache_ready = true

func import_manifest(manifest: Resource) -> bool:
    var staged: Dictionary = {"character": {}, "buff": {}, "item": {}, "skill": {}, "technique": {}, "effect_handler": {}}
    load_error = ""
    if not manifest is Manifest:
        return _fail("Native content manifest has wrong resource type")
    var ids: Dictionary = {}
    for kind in ["character", "buff", "item", "skill", "technique", "effect_handler"]:
        var property_name: String = kind + "s"
        var records: Array = manifest.get(property_name)
        for i in range(records.size()):
            var definition: Resource = records[i]
            if not definition is Definition or definition.content_kind() != kind:
                return _fail("Wrong native content type in " + property_name + "[" + str(i) + "]")
            var id: String = definition.content_id
            if definition.schema_version != 1 or not _valid_id(id) or ids.has(id):
                return _fail("Invalid schema version or duplicate native content ID: " + id)
            var record: Variant = definition.to_record()
            if not record is Dictionary or record.get("schema_version") != 1 or record.get("id") != id:
                return _fail("Native definition produced invalid data: " + id)
            staged[kind][id] = record.duplicate(true)
            ids[id] = true
    definitions = staged
    return true

func _fail(message: String) -> bool:
    load_error = message
    definitions = {"character": {}, "buff": {}, "item": {}, "skill": {}, "technique": {}, "effect_handler": {}}
    return false

func _valid_id(id: String) -> bool:
    if id.is_empty() or id.length() > 128 or id.begins_with(".") or id.ends_with(".") or id.contains(".."):
        return false
    for i in range(id.length()):
        var c: String = id.substr(i, 1)
        if not (c >= "a" and c <= "z") and not (c >= "0" and c <= "9") and c not in ["_", ".", "-"]:
            return false
    return true

func entries(kind: String) -> Dictionary:
    return definitions.get(kind, {}).duplicate(true)
