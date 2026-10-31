extends SceneTree
## Check modifier composition, cap policy, status cleanup and future authored buffs.
const Model = preload("res://scripts/battle_model.gd")
const StatusCatalog = preload("res://scripts/status_catalog.gd")
const Modifiers = preload("res://scripts/stat_modifier_system.gd")
const UNIT: int = 10000
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("R13 MODIFIER FAIL: " + label)

func _run() -> void:
	var model = Model.new()
	var actor = model.state.get_actor(0)
	check(model.cards.statuses.has("iron_body"),"independent buff auto-registered")
	check(actor.attributes.CON == 10 and actor.max_hp_u == 20*UNIT,"unchanged initial derived stats")
	# A status without stat modifiers must not clobber runtime/test-derived fields.
	actor.stats.hp_regen_u_per_100 = 0
	check(model.statuses.add(0,"opening"),"apply legacy non-modifying status")
	check(actor.stats.hp_regen_u_per_100 == 0,"legacy status application preserves derived override")
	model.statuses.remove(0,"opening")
	check(actor.stats.hp_regen_u_per_100 == 0,"legacy status removal preserves derived override")
	actor.stats.hp_regen_u_per_100 = int(model.attributes.derive(actor.attributes).hp_regen_u_per_100)
	check(model.statuses.add(0,"iron_body"),"apply buff")
	check(actor.attributes.CON == 12 and actor.max_hp_u == 22*UNIT,"one stack modifies CON and max HP")
	check(model.statuses.add(0,"iron_body"),"stack same buff")
	check(actor.attributes.CON == 14 and actor.max_hp_u == 24*UNIT,"two stacks compose")
	check(model.statuses.add(0,"iron_body"),"third application refreshes status")
	check(actor.attributes.CON == 14,"buff stack limit remains two")
	actor.modifier_sources["growth:training"] = [{"stat":"STR","op":"flat","value":3}]
	actor.modifier_sources["equipment:sword"] = [{"stat":"attack","op":"percent_bp","value":1000}]
	model.attributes.recalculate(actor)
	check(actor.attributes.STR == 13 and actor.stats.attack == 14,"growth plus equipment percentage")
	actor.modifier_sources.erase("equipment:sword")
	model.attributes.recalculate(actor)
	check(actor.stats.attack == 13,"equipment removal recomputes from base")
	var expiry: int = int(actor.statuses.iron_body.expiry)
	model.state.global_tick = expiry
	model.statuses.resolve_time_boundary(model.resolver)
	check(not model.statuses.has(0,"iron_body"),"buff expires")
	check(actor.attributes.CON == 10 and actor.max_hp_u == 20*UNIT,"expiry clears modifiers")
	check(actor.hp_u <= actor.max_hp_u,"max HP shrink clamps current HP")
	actor.modifier_sources.erase("growth:training")
	model.attributes.recalculate(actor)
	check(actor.stats.attack == 10,"permanent growth removal restores base")
	model.cards.statuses["lasting_training"] = {
		"expiry":{"kind":"permanent"},"stack_limit":1,
		"modifiers":[{"stat":"MND","op":"flat","value":2}]
	}
	check(model.statuses.add(0,"lasting_training"),"permanent status supported")
	model.state.global_tick += 100000
	model.statuses.resolve_time_boundary(model.resolver)
	check(model.statuses.has(0,"lasting_training") and actor.attributes.MND == 12,"permanent status persists")
	model.statuses.remove(0,"lasting_training")
	check(actor.attributes.MND == 10,"permanent status removal recomputes")
	check(not Modifiers.valid_spec({"stat":"unknown","op":"flat","value":1}),"unknown modifier attribute rejected")

	var dir: String = "user://r13-buff-validation/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var bad: Dictionary = {
		"schema_version":1,"id":"bad_buff","name":"错误","public":true,
		"stack_limit":2,"expiry":{"kind":"permanent"},
		"modifiers":[{"stat":"unknown","op":"flat","value":1}]
	}
	var path: String = dir + "bad.json"
	var index_path: String = dir + "index.json"
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(bad))
		file.close()
	var index_file = FileAccess.open(index_path,FileAccess.WRITE)
	if index_file != null:
		index_file.store_string(JSON.stringify({"schema_version":1,"buffs":["bad.json"]}))
		index_file.close()
	check(not StatusCatalog.new(index_path).load_error.is_empty(),"invalid authored buff rejected")
	for candidate in [path,index_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	print("R13_MODIFIER_PASS failures=",failures)
	quit(0 if failures == 0 else 1)

func _initialize() -> void:
	call_deferred("_run")
