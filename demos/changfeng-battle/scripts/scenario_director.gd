extends RefCounted
const JsonNumbers=preload("res://scripts/json_number_codec.gd")
## Read-only encounter data. No new combat engine or duplicate AI is created here.
var encounters: Dictionary = {}
var load_error: String = ""

func _init(path: String = "res://data/demo_scenario.json") -> void:
	if not FileAccess.file_exists(path):
		load_error="Encounter catalog missing: "+path
		return
	var parsed: Variant=JsonNumbers.normalize(JSON.parse_string(FileAccess.get_file_as_string(path)))
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
		if not entry.get("seed",0) is int or not entry.get("schools",{}) is Dictionary:
			load_error="Invalid encounter seed / schools"
			return
		encounters[entry.id]=entry.duplicate(true)

func encounter(id: String) -> Dictionary:
	return encounters.get(id,{}).duplicate(true)

func battle_options(id: String) -> Dictionary:
	var definition: Dictionary=encounter(id)
	if definition.is_empty(): return {}
	var schools: Dictionary={}
	for key in definition.get("schools",{}):
		schools[int(key)]=str(definition.schools[key])
	var options: Dictionary={"combatants":definition.combatants.duplicate(true),"schools":schools}
	var extra_path: String=str(definition.get("bonus_cards_file",""))
	if not extra_path.is_empty():
		if not FileAccess.file_exists(extra_path): return {}
		var parsed: Variant=JsonNumbers.normalize(JSON.parse_string(FileAccess.get_file_as_string(extra_path)))
		if not parsed is Dictionary or not parsed.get("cards") is Array: return {}
		options["card_definitions"]=parsed.cards.duplicate(true)
	return options
