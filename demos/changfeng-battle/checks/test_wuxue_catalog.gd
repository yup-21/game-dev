extends SceneTree
const Catalog = preload("res://scripts/school_catalog.gd")
const Legacy = preload("res://scripts/legacy_skill_adapter.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	var c = Catalog.new()
	check(c.load_error.is_empty(),"load_error=" + c.load_error)
	check(c.schools.size() == 10 and c.forms.size() == 20 and c.statuses.size() == 3 and c.combos.size() == 7,"catalog counts")
	if not c.load_error.is_empty():
		quit(1)
		return
	var options: Array = c.options()
	check(options.size() == 11 and options[0].id == "tingfeng","eleven options")
	options[1].name = "mutated"
	check(c.options()[1].name != "mutated","options copied")
	var usages: int = 0
	for school in c.schools:
		var copy: Dictionary = c.get_school(school.id)
		copy.core_forms[0] = "mutated"
		check(c.get_school(school.id).core_forms[0] != "mutated","school copied: " + school.id)
		var deck: Array = c.deck_for(school.id,[])
		var total: int = 0
		for entry in deck: total += int(entry.count)
		check(total == 12,"deck count: " + school.id)
		deck[0].count = 1000
		check(c.deck_for(school.id,[])[0].count != 1000,"deck copied: " + school.id)
	var default_deck: Array = [{"card_id":"tf_probe","count":12}]
	var default_copy: Array = c.deck_for("tingfeng",default_deck)
	default_copy[0].count = 1
	check(default_deck[0].count == 12,"default deck copied")
	for form in c.forms.values():
		for usage in form.usages:
			usages += 1
			for effect in usage.effects: check(not str(effect.type).begins_with("damage_if_"),"legacy bonus removed")
			if usage.target.kind == "enemy_actor":
				check(usage.attack_profile.range == usage.target.max_distance,"range normalized")
				check(usage.target.line_mode == "orthogonal" and usage.target.blocks_actors,"orthogonal actor-blocking LOS")
	check(usages == 41,"41 usages")
	var shield_bonus: Dictionary = c.forms.tide_return.usages[0].effects[0].conditional_bonus
	check(shield_bonus.if_self_shield_gt == 0 and shield_bonus.bonus == 1 and shield_bonus.size() == 2,"shield bonus")
	check(c.forms.blood_finish.usages[1].effects[0].conditional_bonus.if_self_hp_pct_lt_after_cost == 0.5,"low HP ratio")
	check(c.forms.ember_burst.usages[1].effects[0].conditional_bonus.consume_on_hit == "scorch","status consumed on hit")
	check(c.forms.saber_river.usages[0].effects[1].effects[0].direction == "away_from_attacker","push normalized")
	check(c.forms.whip_coil.usages[1].effects[1].effects[0].max_distance == 1,"pull normalized")
	var mapping: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy_id_map.json")).mapping
	for id in mapping:
		var mapped: Dictionary = Legacy.resolve_legacy(id)
		check(mapped.get("definition_id") == mapping[id].card_id and mapped.get("card_id") == mapping[id].card_id and mapped.get("usage_id") == mapping[id].usage_id and mapped.size() == 3,"old ID: " + id)
	check(Legacy.resolve_legacy("step_01","evasion").usage_id == "evasion","step_01 evasion")
	check(Legacy.resolve_legacy("card:0:0001").is_empty(),"UID never mapped")
	check(Legacy.resolve_legacy("missing").is_empty(),"unknown ID")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/school_forms.json"))
	var bad_cases: Array = []
	var bad: Dictionary = raw.duplicate(true)
	bad.cards[0].usages[0].effects[0].amount = -1
	bad_cases.append(bad)
	bad = raw.duplicate(true)
	bad.schools[0].deck.cards[0].card_id = "missing"
	bad_cases.append(bad)
	bad = raw.duplicate(true)
	bad.schools[0].deck.cards[0].card_id = "tf_change"
	bad_cases.append(bad)
	bad = raw.duplicate(true)
	bad.combos[0].sequence[0].usage_id = "missing"
	bad_cases.append(bad)
	bad = raw.duplicate(true)
	bad.cards[0].usages[0].effects.append({"type":"apply_status","status_id":"missing"})
	bad_cases.append(bad)
	bad = raw.duplicate(true)
	bad.cards[0].usages[0].effects.append({"type":"damage_if_shield","bonus":1})
	bad.cards[0].usages[0].effects.append({"type":"damage_if_low_hp","threshold_percent":50,"bonus":1})
	bad_cases.append(bad)
	bad = raw.duplicate(true)
	bad.cards[0].usages[0].cost.qi = "1"
	bad_cases.append(bad)
	bad = raw.duplicate(true)
	bad.cards[0].usages[0].effects[0].script = "ignored?"
	bad_cases.append(bad)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures/checks"))
	var scratch: String = "res://captures/checks/catalog-invalid.json"
	for invalid in bad_cases:
		var file = FileAccess.open(scratch,FileAccess.WRITE)
		file.store_string(JSON.stringify(invalid))
		file.close()
		var rejected = Catalog.new(scratch)
		check(not rejected.load_error.is_empty() and rejected.forms.is_empty() and rejected.schools.is_empty(),"invalid schema/reference rejected atomically")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	print("CATALOG CHECK: %d checks, %d failures; schools=10 forms=20 statuses=3 combos=7 usages=41 legacy=40" % [checks,failures])
	quit(0 if failures == 0 else 1)
