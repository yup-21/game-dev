extends SceneTree
## A character's identity and art must not depend on its encounter slot.
const Registry = preload("res://scripts/character_registry.gd")
const Scenario = preload("res://scripts/scenario_director.gd")
const Model = preload("res://scripts/battle_model.gd")
const Art = preload("res://scripts/hd2d_art_catalog.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("R12 IDENTITY FAIL: " + label)

func _write(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

func _run() -> void:
	var registry = Registry.new()
	check(registry.load_error.is_empty(),"canonical registry loads")
	var hero: Dictionary = registry.get_profile("shen_changfeng")
	var pursuer: Dictionary = registry.get_profile("pursuer_captain")
	var encounter: Dictionary = {
		"id":"r12_dynamic_duel","seed":2026,"schools":{},
		"combatants":[
			{"id":71,"name":hero.name,"character_id":hero.id,"team_id":0,"controller":"PLAYER","cell":[6,4]},
			{"id":72,"name":pursuer.name,"character_id":pursuer.id,"team_id":1,"controller":"AI","cell":[8,4]}
		]
	}
	var encounter_path: String = "user://r12-dynamic-encounter.json"
	check(_write(encounter_path,{"schema_version":1,"encounters":[encounter]}),"write dynamic encounter")
	var director = Scenario.new(encounter_path)
	check(director.load_error.is_empty(),"scenario permits relocated character IDs")
	var opts: Dictionary = director.battle_options("r12_dynamic_duel")
	check(opts.get("character_ids",{}).get(71,"") == "shen_changfeng","actor 71 maps to original character")
	var battle = Model.new()
	battle.reset(2026,-1,"tingfeng",opts)
	var actor = battle.state.get_actor(71)
	check(battle.state.outcome == "playing" and actor != null,"dynamic actor duel starts")
	if actor != null:
		check(actor.character_id == "shen_changfeng" and actor.school_id == hero.school_id,"character data independent of actor ID")
	check(Art.sheet_for_character("shen_changfeng") == Art.sheet_for_actor(0),"art resolves by character identity")
	check(Art.avatar_for_character("shen_changfeng") != null,"character avatar available for relocated actor")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(encounter_path))

	var dir: String = "user://r12-characters/"
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir)) == OK,"create custom definition directory")
	var added_hero: Dictionary = hero.duplicate(true)
	added_hero.id = "extension_hero"
	added_hero.name = "新侠客"
	added_hero.battle_actor_id = -1
	var added_pursuer: Dictionary = pursuer.duplicate(true)
	added_pursuer.id = "extension_pursuer"
	added_pursuer.name = "新追兵"
	added_pursuer.battle_actor_id = -1
	var hero_path: String = dir + "hero.json"
	var pursuer_path: String = dir + "pursuer.json"
	var index_path: String = dir + "index.json"
	check(_write(hero_path,added_hero) and _write(pursuer_path,added_pursuer)
		and _write(index_path,{"schema_version":1,"characters":["hero.json","pursuer.json"]}),"write two unbound character definitions")
	var added = Registry.new(index_path,dir)
	check(added.load_error.is_empty() and added.profiles.size() == 2,"new character definitions validate")
	var dynamic_options: Dictionary = added.battle_options([], {81:"extension_hero",82:"extension_pursuer"})
	check(dynamic_options.get("character_ids",{}).size() == 2,"unbound characters materialize battle options")
	for path in [hero_path,pursuer_path,index_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	print("R12_IDENTITY_PASS failures=",failures)
	quit(0 if failures == 0 else 1)
