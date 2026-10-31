extends SceneTree
## Prove new authored content can load without editing runtime code.
const Catalog = preload("res://scripts/school_catalog.gd")
const Combos = preload("res://scripts/combo_resolver.gd")
const Combatant = preload("res://scripts/combatant_state.gd")
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("R11 FAIL: " + label)

func _initialize() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/school_forms.json"))
	var expanded: Dictionary = raw.duplicate(true)
	var school: Dictionary = expanded.schools[0].duplicate(true)
	school.id = "extension_sword"
	school.name = "扩展流派测试"
	school.core_forms = ["extension_flow", "extension_final"]
	for entry in school.deck.cards:
		if entry.card_id == "wind_flow": entry.card_id = "extension_flow"
		if entry.card_id == "wind_final": entry.card_id = "extension_final"
	expanded.schools.append(school)
	for i in range(2):
		var form: Dictionary = expanded.cards[i].duplicate(true)
		form.id = school.core_forms[i]
		form.school_id = school.id
		expanded.cards.append(form)
	var extra: Dictionary = expanded.combos[0].duplicate(true)
	extra.id = "extension_repeat_combo"
	extra.max_activations_per_action = 2
	for step in extra.sequence:
		if step.card_id == "wind_flow": step.card_id = "extension_flow"
		if step.card_id == "wind_final": step.card_id = "extension_final"
	expanded.combos.append(extra)
	var tmp: String = "user://r11-expanded-catalog.json"
	var file := FileAccess.open(tmp,FileAccess.WRITE)
	check(file != null,"create temporary catalog")
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(expanded))
	file.close()
	var catalog = Catalog.new(tmp)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	check(catalog.load_error.is_empty(),"accept extended catalog: " + catalog.load_error)
	if not catalog.load_error.is_empty():
		quit(1)
		return
	check(catalog.schools.size() == 11 and catalog.forms.size() == 22 and catalog.combos.size() == 8,"grow catalog by JSON only")
	check(catalog.deck_for("extension_sword",[]).size() == 5,"resolve new school deck")
	var actor = Combatant.new()
	actor.attack_history = [{
		"definition_id":extra.sequence[0].card_id,
		"usage_id":extra.sequence[0].usage_id,
		"resolved":true,"interrupted":false,"hit":true
	}]
	var resolver = Combos.new({"combos":[extra]},null)
	var next_card: String = str(extra.sequence[1].card_id)
	var next_usage: String = str(extra.sequence[1].usage_id)
	check(resolver.declaration(actor,next_card,next_usage).get("id","") == extra.id,"first activation")
	actor.combo_used.append(extra.id)
	check(resolver.declaration(actor,next_card,next_usage).get("id","") == extra.id,"second activation")
	actor.combo_used.append(extra.id)
	check(resolver.declaration(actor,next_card,next_usage).is_empty(),"third activation rejected")
	check(Catalog.new().schools.size() == 10,"original catalog unmodified")
	print("R11_CATALOG_PASS failures=",failures)
	quit(0 if failures == 0 else 1)
