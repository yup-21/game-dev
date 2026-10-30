extends RefCounted
## Read-only identity catalog. Character IDs, biographies, art references and
## default attributes/learned arts live here; BattleModel owns mutable state.
const SchoolCatalog = preload("res://scripts/school_catalog.gd")
const BASE := "res://data/characters/"
var profiles: Dictionary = {}
var by_actor: Dictionary = {}
var by_name: Dictionary = {}
var load_error: String = ""

func _init(index_path: String = BASE + "index.json") -> void:
    if not FileAccess.file_exists(index_path):
        load_error = "Character index missing: " + index_path
        return
    var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
    if not index is Dictionary or index.get("schema_version") != 1 or not index.get("characters") is Array:
        load_error = "Invalid character index"
        return
    var schools = SchoolCatalog.new()
    if not schools.load_error.is_empty():
        load_error = schools.load_error
        return
    for entry in index.characters:
        if not entry is String or entry.contains("/") or entry.contains("..") or not entry.ends_with(".json"):
            load_error = "Unsafe character file path"
            return
        var path: String = BASE + entry
        if not FileAccess.file_exists(path):
            load_error = "Missing character definition: " + entry
            return
        var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        if not _valid(d, schools) or profiles.has(d.id) or by_name.has(d.name):
            load_error = "Invalid or duplicate character definition: " + entry
            return
        if int(d.battle_actor_id) >= 0 and by_actor.has(int(d.battle_actor_id)):
            load_error = "Duplicate battle actor ID: " + str(d.battle_actor_id)
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
    if actor_id >= 0 and schools.get_school(str(d.school_id)).is_empty():
        return false
    if actor_id < 0 and not str(d.school_id).is_empty():
        return false
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
    return true

func get_profile(id: String) -> Dictionary:
    return profiles.get(id, {}).duplicate(true)

func for_actor(actor_id: int) -> Dictionary:
    return get_profile(str(by_actor.get(actor_id, "")))

func for_name(name: String) -> Dictionary:
    return get_profile(str(by_name.get(name, "")))

func actor_ids() -> Array:
    return by_actor.keys().duplicate()

func battle_options(roster: Array, character_ids: Dictionary) -> Dictionary:
    ## Materialize defaults for the encounter. Dynamic stats never return to
    ## this catalog and all callers receive deep copies.
    var output: Dictionary = {"character_ids": {}, "schools": {}, "attributes": {},
        "passives": {}, "techniques": {}, "character_names": {}}
    if not roster.is_empty():
        output["combatants"] = []
    for actor_id in character_ids:
        var id: int = int(actor_id)
        var profile: Dictionary = get_profile(str(character_ids[actor_id]))
        if profile.is_empty() or int(profile.battle_actor_id) != id or str(profile.school_id).is_empty():
            return {}
        output.character_ids[id] = str(profile.id)
        output.schools[id] = str(profile.school_id)
        output.attributes[id] = profile.attributes.duplicate(true)
        output.passives[id] = profile.passives.duplicate(true)
        output.techniques[id] = profile.techniques.duplicate(true)
        output.character_names[id] = str(profile.name)
    for entry in roster:
        if not entry is Dictionary or not entry.get("id") is int or not output.character_ids.has(int(entry.id)):
            return {}
        var record: Dictionary = entry.duplicate(true)
        record.name = str(output.character_names[int(entry.id)])
        record.character_id = str(output.character_ids[int(entry.id)])
        output.combatants.append(record)
    return output
