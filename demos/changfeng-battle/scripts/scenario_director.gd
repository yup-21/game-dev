extends RefCounted
const CharacterRegistry = preload("res://scripts/character_registry.gd")
var characters = CharacterRegistry.new()
## Read-only encounter data. No new combat engine or duplicate AI is created here.
var encounters: Dictionary = {}
var load_error: String = ""

func _init(path: String = "res://data/demo_scenario.json") -> void:
	if not characters.load_error.is_empty():
		load_error=characters.load_error
		return
	if not FileAccess.file_exists(path):
		load_error="Encounter catalog missing: "+path
		return
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema_version")!=1 or not parsed.get("encounters") is Array:
		load_error="Invalid encounter catalog"
		return
	for entry in parsed.encounters:
		if not entry is Dictionary or not entry.get("id") is String or str(entry.id).is_empty() or encounters.has(entry.id):
			load_error="Invalid encounter ID"
			return
		if not entry.get("combatants") is Array or entry.combatants.size()<2 or entry.combatants.size()>8:
			load_error="Invalid encounter roster"
			return
		if not _valid_integer(entry.get("seed",0)) or not entry.get("schools",{}) is Dictionary:
			load_error="Invalid encounter seed / schools"
			return
		if entry.has("map_id"):
			if not entry.map_id is String or not str(entry.map_id).is_valid_identifier():
				load_error="Invalid map ID"
				return
		var normalized: Dictionary=entry.duplicate(true)
		if normalized.has("seed"): normalized.seed=int(normalized.seed)
		for actor in normalized.combatants:
			if not actor is Dictionary or not _valid_integer(actor.get("id")) or not _valid_integer(actor.get("team_id")):
				load_error="Invalid encounter actor numbers"
				return
			var cell: Variant=actor.get("cell")
			if not cell is Array or cell.size()!=2 or not _valid_integer(cell[0]) or not _valid_integer(cell[1]):
				load_error="Invalid encounter cell numbers"
				return
			actor.id=int(actor.id)
			actor.team_id=int(actor.team_id)
			actor.cell=[int(cell[0]),int(cell[1])]
			if actor.has("character_id"):
				var definition: Dictionary=characters.get_profile(str(actor.character_id))
				if definition.is_empty() or str(actor.get("name",""))!=str(definition.name):
					load_error="Encounter refers to unknown or mismatched character"
					return
		encounters[entry.id]=normalized

func _valid_integer(value: Variant) -> bool:
	if value is int: return true
	# A float at 2^63 cannot be represented by Godot's signed 64-bit int.
	return (value is float and is_finite(value) and value==floor(value)
		and value>=-9223372036854775808.0 and value<9223372036854775808.0)

func encounter(id: String) -> Dictionary:
	return encounters.get(id,{}).duplicate(true)

func battle_options(id: String) -> Dictionary:
	var definition: Dictionary=encounter(id)
	if definition.is_empty(): return {}
	var roster: Array=definition.combatants.duplicate(true)
	var ids: Dictionary={}
	for actor in roster:
		if actor.has("character_id"):
			ids[int(actor.id)]=str(actor.character_id)
	if not ids.is_empty():
		var configured: Dictionary=characters.battle_options(roster,ids)
		if definition.has("map_id"):
			configured["map_definition_path"]="res://data/maps/"+str(definition.map_id)+".json"
		return configured
	# Legacy/custom encounter fixtures remain supported without profiles.
	var schools: Dictionary={}
	for key in definition.get("schools",{}):
		schools[int(key)]=str(definition.schools[key])
	var configured: Dictionary={"combatants":roster,"schools":schools}
	if definition.has("map_id"):
		configured["map_definition_path"]="res://data/maps/"+str(definition.map_id)+".json"
	return configured
