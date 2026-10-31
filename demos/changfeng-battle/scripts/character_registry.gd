extends RefCounted
## Read-only identity catalog. Character IDs, biographies, art references and
## default attributes/learned arts live here; BattleModel owns mutable state.
const SchoolCatalog = preload("res://scripts/school_catalog.gd")
const Modifiers = preload("res://scripts/stat_modifier_system.gd")
const Inventory = preload("res://scripts/inventory_runtime.gd")
const NativeContent = preload("res://scripts/content/content_registry.gd")
const Loadout = preload("res://scripts/content/character_loadout.gd")
var profiles: Dictionary = {}
var by_actor: Dictionary = {}
var by_name: Dictionary = {}
var load_error: String = ""

func _init(manifest_path: String = NativeContent.DEFAULT_MANIFEST) -> void:
    var natives = NativeContent.new(manifest_path)
    if not natives.load_error.is_empty():
        load_error = natives.load_error
        return
    var schools = SchoolCatalog.new()
    if not schools.load_error.is_empty():
        load_error = schools.load_error
        return
    for d in natives.entries("character").values():
        if not _valid(d, schools) or profiles.has(str(d.id)) or by_name.has(str(d.name)):
            load_error = "Invalid or duplicate native character: " + str(d.get("id", ""))
            return
        if int(d.battle_actor_id) >= 0 and by_actor.has(int(d.battle_actor_id)):
            load_error = "Duplicate native actor ID: " + str(d.battle_actor_id)
            return
        profiles[str(d.id)] = d.duplicate(true)
        by_name[str(d.name)] = str(d.id)
        if int(d.battle_actor_id) >= 0:
            by_actor[int(d.battle_actor_id)] = str(d.id)

func _whole(value: Variant, lo: int, hi: int) -> bool:
    if not (value is int or value is float): return false
    var number: float = float(value)
    return is_finite(number) and floor(number)==number and number>=float(lo) and number<=float(hi)

func _valid(d: Variant, schools) -> bool:
    if not d is Dictionary or d.get("schema_version") != 1:
        return false
    for key in ["id","name","title","role","faction","weapon","personality","biography","team_hint","school_id"]:
        if not d.get(key) is String:
            return false
    if str(d.id).is_empty() or str(d.name).is_empty() or not _whole(d.get("battle_actor_id"),-1,1023):
        return false
    var actor_id: int = int(d.battle_actor_id)
    if actor_id < -1 or actor_id > 1023:
        return false
    if not str(d.school_id).is_empty() and schools.get_school(str(d.school_id)).is_empty():
        return false
    var learned: Variant = d.get("learned_schools",[])
    if not learned is Array:
        return false
    if not str(d.school_id).is_empty() and (learned.is_empty() or not learned.has(str(d.school_id))):
        return false
    if str(d.school_id).is_empty() and not learned.is_empty():
        return false
    var seen: Dictionary = {}
    for school_id in learned:
        if not school_id is String or seen.has(school_id) or schools.get_school(str(school_id)).is_empty():
            return false
        seen[school_id]=true
    if not d.get("attributes") is Dictionary or not d.get("passives") is Dictionary or not d.get("techniques") is Dictionary or not d.get("art") is Dictionary:
        return false
    for stat in ["STR","AGI","CON","MND"]:
        if not _whole(d.attributes.get(stat),1,100):
            return false
    for key in ["insight","conceal"]:
        if not _whole(d.passives.get(key),0,2):
            return false
    for art_key in ["portrait","sprite_sheet","sheet_quality","portrait_quality"]:
        if not d.art.get(art_key) is String:
            return false
    for art_key in ["portrait","sprite_sheet"]:
        var location: String = str(d.art[art_key])
        if not location.is_empty() and (not location.begins_with("res://assets/") or ".." in location):
            return false
    for technique in d.techniques:
        if not _whole(d.techniques[technique],1,10):
            return false
    var presentation: Variant = d.get("presentation", {})
    if not presentation is Dictionary:
        return false
    for key in presentation:
        if key != "battle_scene":
            return false
    var scene_path: Variant = presentation.get("battle_scene", "")
    if not scene_path is String:
        return false
    if not str(scene_path).is_empty():
        if not str(scene_path).begins_with("res://scenes/") or ".." in scene_path or not ResourceLoader.exists(scene_path, "PackedScene"):
            return false
    if d.has("starting_loadout"):
        # Treat a character card as invalid before it enters the catalog if its
        # initial inventory cannot be assembled with real item/affix rules.
        var candidate = Inventory.new()
        if not candidate.catalog.load_error.is_empty() or not Loadout.apply(d.starting_loadout, candidate):
            return false
    return true

func get_profile(id: String) -> Dictionary:
    return profiles.get(id, {}).duplicate(true)

func for_actor(actor_id: int) -> Dictionary:
    return get_profile(str(by_actor.get(actor_id, "")))

func for_name(name: String) -> Dictionary:
    return get_profile(str(by_name.get(name, "")))

func actor_ids() -> Array:
    return by_actor.keys().duplicate()

func battle_options(roster: Array, character_ids: Dictionary, builds: Dictionary = {}) -> Dictionary:
    ## Immutable profiles supply defaults; optional persistent CharacterRuntime
    ## builds supply growth, learned schools, equipment and modifiers.
    var output: Dictionary = {"character_ids": {}, "schools": {}, "attributes": {},
        "passives": {}, "techniques": {}, "character_names": {}, "learned_schools": {},
        "modifier_sources": {}, "equipment": {}, "equipment_affixes": {}, "inventories": {}}
    if not roster.is_empty():
        output["combatants"] = []
    var schools = SchoolCatalog.new()
    if not schools.load_error.is_empty(): return {}
    for actor_id in character_ids:
        var id: int = int(actor_id)
        var profile: Dictionary = get_profile(str(character_ids[actor_id]))
        if profile.is_empty() or str(profile.school_id).is_empty():
            return {}
        var build: Variant = builds.get(str(profile.id),{})
        if not build is Dictionary: return {}
        if not build.is_empty() and str(build.get("character_id","")) != str(profile.id): return {}
        var selected: String = str(build.get("school_id",profile.school_id))
        var learned: Variant = build.get("learned_schools",profile.learned_schools)
        if not learned is Array or learned.is_empty() or not learned.has(selected): return {}
        var seen: Dictionary = {}
        for school_id in learned:
            if not school_id is String or schools.get_school(str(school_id)).is_empty() or seen.has(school_id): return {}
            seen[school_id] = true
        var attrs: Variant = build.get("attributes",profile.attributes)
        if not attrs is Dictionary: return {}
        var normalized_attributes: Dictionary = {}
        for stat in ["STR","AGI","CON","MND"]:
            if not _whole(attrs.get(stat),1,100): return {}
            normalized_attributes[stat] = int(attrs[stat])
        var sources: Variant = build.get("modifier_sources",{})
        if not sources is Dictionary: return {}
        for source in sources:
            if not source is String or not sources[source] is Array: return {}
            for spec in sources[source]:
                if not Modifiers.valid_spec(spec): return {}
        var equipment: Variant = build.get("equipment",{})
        if not equipment is Dictionary: return {}
        # A battle owns a validated copy; the mutable overworld inventory is never shared.
        if build.has("inventory"):
            var checked_inventory = Inventory.new()
            if not checked_inventory.restore(build.inventory): return {}
            if checked_inventory.equipment_definitions() != equipment: return {}
            if checked_inventory.modifier_sources() != sources:
                # Sources may also contain permanent growth modifiers.
                for key in checked_inventory.modifier_sources():
                    if sources.get(key) != checked_inventory.modifier_sources()[key]: return {}
            output.inventories[id] = checked_inventory.snapshot()
            output.equipment_affixes[id] = checked_inventory.equipment_affixes()
        output.character_ids[id] = str(profile.id)
        output.schools[id] = selected
        output.learned_schools[id] = learned.duplicate(true)
        output.attributes[id] = normalized_attributes
        output.modifier_sources[id] = sources.duplicate(true)
        output.equipment[id] = equipment.duplicate(true)
        output.passives[id] = profile.passives.duplicate(true)
        output.techniques[id] = {}
        # Typed card attributes are validated before constructing the battle.
        for technique_id in profile.techniques:
            output.techniques[id][str(technique_id)] = int(profile.techniques[technique_id])
        output.character_names[id] = str(profile.name)
    for entry in roster:
        if not entry is Dictionary or not entry.get("id") is int or not output.character_ids.has(int(entry.id)):
            return {}
        var record: Dictionary = entry.duplicate(true)
        record.name = str(output.character_names[int(entry.id)])
        record.character_id = str(output.character_ids[int(entry.id)])
        output.combatants.append(record)
    return output
