extends RefCounted
## Persistent character build. No BattleState references or UI dependencies.
const Registry = preload("res://scripts/character_registry.gd")
const Schools = preload("res://scripts/school_catalog.gd")
const Inventory = preload("res://scripts/inventory_runtime.gd")
const Modifiers = preload("res://scripts/stat_modifier_system.gd")
var character_id: String = ""
var attributes: Dictionary = {}
var school_id: String = ""
var learned_schools: Array = []
var growth_sources: Dictionary = {}
var inventory
var load_error: String = ""

func _init(id: String, source_registry = null, item_catalog = null) -> void:
    var registry = Registry.new() if source_registry == null else source_registry
    var profile: Dictionary = registry.get_profile(id)
    inventory = Inventory.new(item_catalog)
    if profile.is_empty() or not inventory.catalog.load_error.is_empty():
        load_error = "Unknown character or item catalog: " + id
        return
    character_id = id
    attributes = profile.attributes.duplicate(true)
    school_id = str(profile.school_id)
    learned_schools = profile.learned_schools.duplicate(true)

func learn_school(id: String) -> bool:
    var schools = Schools.new()
    if schools.get_school(id).is_empty() or learned_schools.has(id): return false
    learned_schools.append(id)
    return true

func switch_school(id: String) -> bool:
    if not learned_schools.has(id): return false
    school_id = id
    return true

func set_attribute(stat: String, value: int) -> bool:
    if stat not in ["STR","AGI","CON","MND"] or value < 1 or value > 100: return false
    attributes[stat] = value
    return true

func set_growth(source: String, entries: Array) -> bool:
    if not source.begins_with("growth:") or source.length() <= 7: return false
    for entry in entries:
        if not Modifiers.valid_spec(entry): return false
    if entries.is_empty(): growth_sources.erase(source)
    else: growth_sources[source] = entries.duplicate(true)
    return true

func battle_build() -> Dictionary:
    var sources: Dictionary = inventory.modifier_sources()
    for source in growth_sources:
        sources[source] = growth_sources[source].duplicate(true)
    return {"character_id":character_id,"attributes":attributes.duplicate(true),
        "school_id":school_id,"learned_schools":learned_schools.duplicate(true),
        "modifier_sources":sources,"equipment":inventory.equipment_definitions()}

func snapshot() -> Dictionary:
    return {"schema_version":1,"character_id":character_id,
        "attributes":attributes.duplicate(true),"school_id":school_id,
        "learned_schools":learned_schools.duplicate(true),
        "growth_sources":growth_sources.duplicate(true),
        "inventory":inventory.snapshot()}

func restore(data: Variant) -> bool:
    if not data is Dictionary or data.get("schema_version") != 1 or str(data.get("character_id","")) != character_id:
        return false
    var attrs: Variant = data.get("attributes")
    var learned: Variant = data.get("learned_schools")
    var selected: Variant = data.get("school_id")
    var growth: Variant = data.get("growth_sources")
    if not attrs is Dictionary or not learned is Array or not selected is String or not growth is Dictionary: return false
    if attrs.size() != 4: return false
    for stat in ["STR","AGI","CON","MND"]:
        if not Modifiers._whole(attrs.get(stat),1,100): return false
    var schools = Schools.new()
    var seen: Dictionary = {}
    for school in learned:
        if not school is String or schools.get_school(str(school)).is_empty() or seen.has(school): return false
        seen[school] = true
    if not selected.is_empty() and not seen.has(selected): return false
    for source in growth:
        if not source is String or not str(source).begins_with("growth:") or not growth[source] is Array: return false
        for spec in growth[source]:
            if not Modifiers.valid_spec(spec): return false
    var restored = Inventory.new(inventory.catalog)
    if not restored.restore(data.get("inventory",{})): return false
    # Atomic assign only after every content reference has been checked.
    attributes = {}
    for stat in ["STR","AGI","CON","MND"]:
        attributes[stat] = int(attrs[stat])
    school_id = str(selected)
    learned_schools = learned.duplicate(true)
    growth_sources = growth.duplicate(true)
    inventory = restored
    return true
