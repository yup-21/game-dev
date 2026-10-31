extends RefCounted
## Legacy authored skill IDs are resolved only at import boundaries.
## Never touches a live CardInstance UID or combat rule state.
const SchoolCatalog = preload("res://scripts/school_catalog.gd")
const Native = preload("res://scripts/content/content_registry.gd")

static func resolve_legacy(legacy_id: String, old_usage: String = "main") -> Dictionary:
    var registry = Native.new()
    if not registry.load_error.is_empty(): return {}
    var mapping: Resource = registry.resource_for("legacy_mapping", "r38_legacy_skill_ids")
    if not mapping is WuxiaLegacyMappingDefinition: return {}
    var catalog = SchoolCatalog.new()
    if not catalog.load_error.is_empty() or not catalog.validate_legacy_mapping(
            mapping.to_record().get("data",{})):
        return {}
    return mapping.resolve(legacy_id, old_usage)
