@tool
class_name WuxiaLegacyMappingDefinition
extends WuxiaContentDefinition
## Import-only ID mapping, independent of normal runtime card definitions.
@export_multiline var note: String = ""
@export var entries: Array[Resource] = []

func content_kind() -> String:
    return "legacy_mapping"

func to_record() -> Dictionary:
    var mapping: Dictionary = {}
    for entry in entries:
        if not entry is WuxiaLegacyMappingEntryDefinition: return {}
        var d: Dictionary = entry.to_record()
        if d.is_empty() or mapping.has(entry.old_id): return {}
        mapping[entry.old_id] = d
    if mapping.is_empty(): return {}
    return {"schema_version":schema_version,"id":content_id,
        "data":{"schema_version":"1.0","note":note,"mapping":mapping}}

func resolve(old_id: String, old_usage: String = "main") -> Dictionary:
    for entry in entries:
        if entry is WuxiaLegacyMappingEntryDefinition and entry.old_id == old_id:
            return entry.resolve(old_usage).duplicate(true)
    return {}
