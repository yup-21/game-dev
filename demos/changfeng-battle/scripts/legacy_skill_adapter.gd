extends RefCounted
## Migrates saved definition/usage references only. UIDs and live battle state are never read.
const SchoolCatalog = preload("res://scripts/school_catalog.gd")
const Native = preload("res://scripts/content/content_registry.gd")

static func resolve_legacy(legacy_id: String, old_usage: String = "main") -> Dictionary:
	var catalog = SchoolCatalog.new()
	if not catalog.load_error.is_empty(): return {}
	var data = Native.new().document("r25_legacy_id_map")
	if not data is Dictionary: return {}
	var entry: Dictionary = data.get("mapping",{}).get(legacy_id,{})
	if entry.is_empty(): return {}
	var definition_id: String = str(entry.card_id)
	var usage_id: String = "evasion" if legacy_id == "step_01" and old_usage == "evasion" else str(entry.usage_id)
	return {"definition_id":definition_id,"card_id":definition_id,"usage_id":usage_id}.duplicate(true)
