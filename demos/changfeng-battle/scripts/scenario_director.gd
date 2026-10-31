extends RefCounted
const CharacterRegistry = preload("res://scripts/character_registry.gd")
const Native = preload("res://scripts/content/content_registry.gd")
var characters = CharacterRegistry.new()
## Read-only encounter data. No new combat engine or duplicate AI is created here.
var encounters: Dictionary = {}
var load_error: String = ""

func _init(path: String = "res://data/demo_scenario.json") -> void:
	if not characters.load_error.is_empty():
		load_error=characters.load_error
		return
	if path != "res://data/demo_scenario.json" and not FileAccess.file_exists(path):
		load_error="Encounter catalog missing: "+path
		return
	var parsed: Variant = Native.new().document("r25_demo_scenario") if path == "res://data/demo_scenario.json" else JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema_version")!=1 or not parsed.get("encounters") is Array:
		load_error="Invalid encounter catalog"
		return
	for entry in parsed.encounters:
		if not _register_entry(entry): return
	# Custom encounter fixtures remain independent of production native content.
	if path != "res://data/demo_scenario.json": return
	var native = Native.new()
	if not native.load_error.is_empty():
		load_error = native.load_error
		return
	for entry in native.entries("encounter").values():
		if not _register_entry(entry): return

func _register_entry(entry: Variant) -> bool:
	if not entry is Dictionary or not entry.get("id") is String or str(entry.id).is_empty() or encounters.has(entry.id):
		load_error="Invalid encounter ID"
		return false
	if not entry.get("combatants") is Array or entry.combatants.size()<2 or entry.combatants.size()>8:
		load_error="Invalid encounter roster"
		return false
	if not _valid_integer(entry.get("seed",0)) or not entry.get("schools",{}) is Dictionary:
		load_error="Invalid encounter seed / schools"
		return false
	if entry.has("map_id"):
		if not entry.map_id is String or not str(entry.map_id).is_valid_identifier():
			load_error="Invalid map ID"
			return false
	if entry.has("map_definition_path"):
		var map_path: String = str(entry.map_definition_path)
		if not map_path.begins_with("res://data/maps/") or not map_path.ends_with(".tres") or \
				map_path.contains("..") or not ResourceLoader.exists(map_path):
			load_error="Invalid native map path"
			return false
	var normalized: Dictionary=entry.duplicate(true)
	if normalized.has("seed"): normalized.seed=int(normalized.seed)
	for actor in normalized.combatants:
		if not actor is Dictionary or not _valid_integer(actor.get("id")) or not _valid_integer(actor.get("team_id")):
			load_error="Invalid encounter actor numbers"
			return false
		var cell: Variant=actor.get("cell")
		if not cell is Array or cell.size()!=2 or not _valid_integer(cell[0]) or not _valid_integer(cell[1]):
			load_error="Invalid encounter cell numbers"
			return false
		actor.id=int(actor.id)
		actor.team_id=int(actor.team_id)
		actor.cell=[int(cell[0]),int(cell[1])]
		if actor.has("recruit_at_story") and (actor.get("recruit_at_story") != true or int(actor.team_id) != 0 or not actor.has("character_id")):
			load_error="Invalid story recruitment actor"
			return false
		if actor.has("character_id"):
			var definition: Dictionary=characters.get_profile(str(actor.character_id))
			if definition.is_empty() or str(actor.get("name",""))!=str(definition.name):
				load_error="Encounter refers to unknown or mismatched character"
				return false
	encounters[str(entry.id)]=normalized
	return true

func _valid_integer(value: Variant) -> bool:
	if value is int: return true
	# A float at 2^63 cannot be represented by Godot's signed 64-bit int.
	return (value is float and is_finite(value) and value==floor(value)
		and value>=-9223372036854775808.0 and value<9223372036854775808.0)

func encounter(id: String) -> Dictionary:
	return encounters.get(id,{}).duplicate(true)

func battle_options(id: String, builds: Dictionary = {}) -> Dictionary:
	var definition: Dictionary=encounter(id)
	if definition.is_empty(): return {}
	var roster: Array=definition.combatants.duplicate(true)
	var ids: Dictionary={}
	for actor in roster:
		if actor.has("character_id"):
			ids[int(actor.id)]=str(actor.character_id)
	if not ids.is_empty():
		var configured: Dictionary=characters.battle_options(roster,ids,builds)
		if definition.has("map_definition_path"):
			configured["map_definition_path"]=str(definition.map_definition_path)
		elif definition.has("map_id"):
			configured["map_definition_path"]="res://data/maps/"+str(definition.map_id)+".json"
		return configured
	# Legacy/custom encounter fixtures remain supported without profiles.
	var schools: Dictionary={}
	for key in definition.get("schools",{}):
		schools[int(key)]=str(definition.schools[key])
	var configured: Dictionary={"combatants":roster,"schools":schools}
	if definition.has("map_definition_path"):
		configured["map_definition_path"]=str(definition.map_definition_path)
	elif definition.has("map_id"):
		configured["map_definition_path"]="res://data/maps/"+str(definition.map_id)+".json"
	return configured
