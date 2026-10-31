extends "res://checks/test_tingfeng.gd"
const Legacy = preload("res://scripts/legacy_skill_adapter.gd")
var exercised: Array = []

func school(a: String, b: String = "tingfeng", first: int = 0, extra: Dictionary = {}):
	var opts: Dictionary = extra.duplicate(true)
	opts.schools = {0:a, 1:b}
	var model = Model.new()
	model.reset(311, first, "tingfeng", opts)
	ack(model)
	for actor in model.state.actors:
		actor.stats.hp_regen_u_per_100 = 0
	for cell in model.state.terrain: model.state.terrain[cell] = "grass"
	adjacent(model)
	return model

func use(model, actor_id: int, definition_id: String, usage_id: String) -> bool:
	var chosen: Dictionary = option(model, actor_id, "PLAY_CARD", definition_id, usage_id)
	var result: Dictionary = send(model, chosen)
	return bool(result.get("success", false))

func clock(model, ticks: int) -> void:
	model.state.mode = "TIMELINE"
	model.state.phase = "TIMELINE"
	model.turns.advance_time(ticks)

func conserved(model, who: int) -> bool:
	var a = model.state.get_actor(who)
	var zones: Array = a.hand + a.draw_pile + a.discard_pile + a.resolving
	var unique: Dictionary = {}
	for uid in zones: unique[uid] = true
	return zones.size() == 12 and unique.size() == 12

func run_tests() -> void:
	test_catalog_decks()
	test_every_usage()
	test_school_combos()
	test_focus_declaration()
	test_seal_clock()
	test_scorch_clock()
	test_spatial_blood_draw()
	test_legacy_and_scope()
	test_first_insight()
	test_school_policy()
	test_path_equivalence()
	var f = FileAccess.open("res://captures/checks/wuxue-usage-evidence.json", FileAccess.WRITE)
	if f != null: f.store_string(JSON.stringify(exercised, "\t"))
	print("SCHOOL TESTS: %d PASS / %d FAIL" % [passed, failed])
	quit(0 if failed == 0 else 1)

func test_catalog_decks() -> void:
	var base = fresh()
	var combo_ids: Array = []
	for combo in base.cards.combos: combo_ids.append(str(combo.get("id", "")))
	check(base.cards.definitions.size() == 6 and base.cards.statuses.has_all(["opening","hand_exposed"]) and combo_ids.has_all(["probe_to_follow","opening_to_expose"]), "original five forms, two base statuses and combos remain available")
	var catalog = base.cards.catalog
	check(catalog.load_error.is_empty() and catalog.schools.size() == 10 and catalog.forms.size() == 20 and catalog.statuses.size() == 3 and catalog.combos.size() == 7, "V3 catalog complete and validated")
	check(base.school_options().size() == 11 and base.snapshot().school_catalog.size() == 11, "eleven public school options")
	for entry in catalog.schools:
		var id: String = str(entry.id) if entry is Dictionary else str(entry)
		var model = school(id, "needle" if id != "needle" else "saber")
		for actor in model.state.actors:
			var selected: String = id if actor.id == 0 else ("needle" if id != "needle" else "saber")
			var expected: Dictionary = {}
			for item in catalog.deck_for(selected, []).duplicate(true): expected[str(item.card_id)] = int(item.count)
			var actual: Dictionary = {}
			for uid in actor.hand + actor.draw_pile:
				var definition_id: String = str(model.cards.instances[uid].definition_id)
				actual[definition_id] = int(actual.get(definition_id, 0)) + 1
			check(actual == expected and conserved(model, actor.id) and actor.school_id == selected, "%s actor %d independent selected deck" % [id, actor.id])
		check(model.state.terrain.size() == 150, id + " original 15x10 board")
	var only = school("saber", "saber")
	check(not only.cards.definitions.has("needle_rain") and only.cards.definitions.has("saber_charge"), "actual definitions include only selected school forms")

func test_every_usage() -> void:
	var catalog = fresh().cards.catalog
	for definition in catalog.forms.values():
		for usage in definition.usages:
			var first: int = 1 if str(usage.timing) == "DEFENSE_REACTION" else 0
			var model = school(str(definition.school_id), "tingfeng", first)
			fixture(model, 0, [str(definition.id), "tf_probe"])
			fixture(model, 1, ["tf_probe"])
			var minimum: int = int(usage.get("target", {}).get("min_distance", 1))
			model.state.get_actor(1).cell = Vector2i(6 + maxi(1, minimum), 4)
			if str(usage.timing) != "ACTION":
				check(bool(send(model, option(model, first, "BASIC_ATTACK")).get("success", false)), "reaction fixture root " + str(definition.id) + ":" + str(usage.id))
				if str(usage.timing) == "ATTACK_REACTION":
					send(model, option(model, 1, "PASS_REACTION"))
			var accepted: bool = use(model, 0, str(definition.id), str(usage.id))
			check(accepted, "real legal usage " + str(definition.id) + ":" + str(usage.id))
			if accepted:
				pass_clash(model)
				exercised.append({"definition_id":definition.id,"usage_id":usage.id,"tick":model.state.global_tick,"conserved":conserved(model, 0)})
			check(conserved(model, 0) and conserved(model, 1), "usage conservation " + str(definition.id) + ":" + str(usage.id))
	check(exercised.size() == 41, "all 41 V3 usages actually submitted")

func test_school_combos() -> void:
	var catalog = fresh().cards.catalog
	for combo in catalog.combos:
		var first: Dictionary = combo.sequence[0]
		var second: Dictionary = combo.sequence[1]
		var definition: Dictionary = catalog.forms[str(first.card_id)]
		var model = school(str(definition.school_id))
		fixture(model, 0, [str(first.card_id), str(second.card_id)])
		fixture(model, 1, [])
		if definition.school_id == "needle": model.state.get_actor(1).cell = Vector2i(8, 4)
		if definition.school_id == "whip": model.state.get_actor(1).cell = Vector2i(9, 4)
		check(use(model, 0, str(first.card_id), str(first.usage_id)), "combo first " + str(combo.id))
		pass_clash(model)
		check(use(model, 0, str(second.card_id), str(second.usage_id)), "combo second " + str(combo.id))
		pass_clash(model)
		var found: bool = false
		for event in model.state.events:
			if event.type == "COMBO_TRIGGERED" and str(event.get("combo_id", "")) == str(combo.id): found = true
		check(found, "real resolved combo " + str(combo.id))

func test_focus_declaration() -> void:
	for basic in [true, false]:
		var model = school("saber")
		fixture(model, 0, ["saber_charge", "saber_river"])
		fixture(model, 1, ["tf_step"])
		check(use(model, 0, "saber_charge", "charge") and model.statuses.stacks(0, "focus") == 2, "focus acquired from legal charge")
		var attack: Dictionary = option(model, 0, "BASIC_ATTACK") if basic else option(model, 0, "PLAY_CARD", "saber_river", "reap")
		check(bool(send(model, attack).get("success", false)) and not model.statuses.has(0, "focus"), "focus consumed on %s declaration" % ("basic" if basic else "card"))
		check(int(model.state.attack.get("attack_bonus", 0)) == 2, "focus grants exactly two root bonus damage")
		var before: int = model.state.get_actor(1).hp_u
		var evasion: Dictionary = option(model, 1, "PLAY_CARD", "tf_step", "evasion", Vector2i(7, 5))
		check(bool(send(model, evasion).get("success", false)), "legal evasion forces focus attack MISS")
		pass_clash(model)
		check(model.state.get_actor(1).hp_u == before and not model.statuses.has(0, "focus"), "MISS never refunds focus")

func sealed():
	var model = school("finger", "taixu")
	fixture(model, 0, ["finger_seal"])
	fixture(model, 1, [])
	check(use(model, 0, "finger_seal", "seal"), "seal applied by legal hit")
	pass_clash(model)
	for actor in model.state.actors: actor.qi_u = 0
	return model

func test_seal_clock() -> void:
	var large = sealed()
	var sliced = sealed()
	clock(large, 200)
	for ticks in [70, 30, 49, 1, 50]: clock(sliced, ticks)
	check(large.state.get_actor(1).qi_u == 37500 and large.state.get_actor(0).qi_u == 60000, "seal150 half recovery then normal recovery")
	check(large.state.get_actor(1).qi_u == sliced.state.get_actor(1).qi_u and not large.statuses.has(1, "qi_seal"), "seal large and sliced advance identical")
	var odd = sealed()
	var odd_sliced = sealed()
	for model in [odd, odd_sliced]: model.state.get_actor(1).stats.qi_regen_u_per_100 = 30300
	clock(odd, 177)
	for i in range(177): clock(odd_sliced, 1)
	check(odd.state.get_actor(1).qi_u == odd_sliced.state.get_actor(1).qi_u, "seal fractional recovery partition invariant")

	var active = sealed()
	send(active, option(active, 0, "END_ACTION"))
	fixture(active, 1, ["taixu_breath"], 2)
	check(use(active, 1, "taixu_breath", "breathe") and active.state.get_actor(1).qi_u == 3 * UNIT and active.statuses.has(1, "qi_seal"), "seal never halves active gain_qi")

func scorched():
	var model = school("ember", "ember")
	fixture(model, 0, ["ember_fire", "ember_fire"])
	fixture(model, 1, [])
	for i in range(2):
		check(use(model, 0, "ember_fire", "spark"), "scorch applied by legal spark")
		pass_clash(model)
	model.state.get_actor(1).shield_u = 10 * UNIT
	return model

func test_scorch_clock() -> void:
	var model = scorched()
	var hp: int = model.state.get_actor(1).hp_u
	clock(model, 100)
	check(model.state.get_actor(1).hp_u == hp - 2 * UNIT and model.state.get_actor(1).shield_u == 10 * UNIT and model.statuses.stacks(1, "scorch") == 1, "scorch100 bypasses shield for2 and decays")
	clock(model, 100)
	check(model.state.get_actor(1).hp_u == hp - 3 * UNIT and not model.statuses.has(1, "scorch"), "scorch200 deals1 and clears")
	var large = scorched()
	var slices = scorched()
	slices.state.get_actor(1).stats.charge_speed = 130
	clock(large, 200)
	for i in range(20): clock(slices, 10)
	check(large.state.get_actor(1).hp_u == slices.state.get_actor(1).hp_u, "scorch global cadence ignores speed and advance partition")
	var ticks: Array = []
	var status_damage: int = 0
	for event in model.state.events:
		if event.type == "SCORCH_TICK": ticks.append(int(event.get("tick", -1)))
		if event.type == "HP_DAMAGED" and event.get("damage_kind", "") == "status": status_damage += 1
	check(ticks == [100, 200] and status_damage == 2, "scorch events report exact global ticks and status damage")
	var draw = scorched()
	# Both sides acquire scorch through real card play, then a low-HP clock fixture.
	send(draw, option(draw, 0, "END_ACTION"))
	fixture(draw, 1, ["ember_fire"])
	check(use(draw, 1, "ember_fire", "spark"), "opposite side applies legal scorch")
	pass_clash(draw)
	for actor in draw.state.actors: actor.hp_u = UNIT
	clock(draw, 100)
	check(draw.state.outcome == "draw" and draw.state.winner_id == -1, "same tick scorch deaths produce draw")

	var refresh = scorched()
	send(refresh, option(refresh, 0, "END_ACTION"))
	send(refresh, option(refresh, 1, "END_ACTION"))
	fixture(refresh, 0, ["ember_fire"])
	check(refresh.state.global_tick == 100 and use(refresh, 0, "ember_fire", "spark"), "scorch can be refreshed by a real hit at100")
	pass_clash(refresh)
	check(int(refresh.state.get_actor(1).statuses.get("scorch", {}).get("next_tick", -1)) == 200, "scorch refresh preserves nearest scheduled tick")
	var expiry = scorched()
	expiry.state.get_actor(1).statuses.scorch.expiry = 100
	var before_expiry: int = expiry.state.get_actor(1).hp_u
	clock(expiry, 100)
	check(expiry.state.get_actor(1).hp_u == before_expiry - 2 * UNIT and not expiry.statuses.has(1, "scorch"), "periodic damage precedes expiration at same tick")

func test_spatial_blood_draw() -> void:
	var model = school("needle")
	fixture(model, 0, ["needle_rain"])
	fixture(model, 1, [])
	for distance in [2, 3, 4]:
		model.state.get_actor(1).cell = Vector2i(6 + distance, 4)
		check(not option(model, 0, "PLAY_CARD", "needle_rain", "shoot").is_empty(), "orthogonal ranged distance%d legal" % distance)
	for cell in [Vector2i(7, 4), Vector2i(11, 4), Vector2i(8, 5)]:
		model.state.get_actor(1).cell = cell
		check(option(model, 0, "PLAY_CARD", "needle_rain", "shoot").is_empty(), "ranged rejects minimum/range/diagonal " + str(cell))
	model.state.get_actor(1).cell = Vector2i(9, 4)
	model.state.terrain[Vector2i(7, 4)] = "rock"
	check(option(model, 0, "PLAY_CARD", "needle_rain", "shoot").is_empty(), "wall blocks ranged ray")
	model.state.terrain[Vector2i(7, 4)] = "grass"
	var blocker = load("res://scripts/combatant_state.gd").new(2, "blocker", Vector2i(7, 4))
	model.state.actors.append(blocker)
	var blocked: bool = true
	for candidate in model.legal_actions(0):
		if candidate.get("usage_id", "") == "shoot" and candidate.get("target_id", -1) == 1: blocked = false
	check(blocked, "living actor blocks ranged ray")
	model = school("saber")
	fixture(model, 0, ["saber_river"])
	fixture(model, 1, [])
	model.state.terrain[Vector2i(8, 4)] = "rock"
	check(use(model, 0, "saber_river", "reap"), "push attack legal before wall")
	pass_clash(model)
	check(model.state.get_actor(1).cell == Vector2i(7, 4), "forced move stops at first wall")
	model = school("saber")
	fixture(model, 0, ["saber_river"])
	fixture(model, 1, [])
	# Longer force fixture exercises the shared resolver's cell-by-cell movement.
	for usage in model.cards.definitions.saber_river.usages:
		if usage.id == "reap": usage.effects[1].effects[0].max_distance = 3
	model.state.terrain[Vector2i(9, 4)] = "rock"
	check(use(model, 0, "saber_river", "reap"), "long force fixture submitted through normal card path")
	pass_clash(model)
	check(model.state.get_actor(1).cell == Vector2i(8, 4), "multi-cell force stops before intermediate wall")
	model = school("whip")
	fixture(model, 0, ["whip_coil"])
	fixture(model, 1, [])
	model.state.get_actor(1).cell = Vector2i(9, 4)
	check(use(model, 0, "whip_coil", "pull"), "pull attack distance3")
	pass_clash(model)
	check(model.state.get_actor(1).cell == Vector2i(8, 4), "pull moves exactly one cell toward attacker")
	model = school("blood")
	fixture(model, 0, ["blood_finish", "blood_burn"])
	fixture(model, 1, [])
	model.state.get_actor(0).hp_u = 3 * UNIT
	check(option(model, 0, "PLAY_CARD", "blood_finish", "finisher").is_empty(), "blood fee cannot kill own actor")
	model.state.get_actor(0).hp_u = 2 * UNIT
	check(option(model, 0, "PLAY_CARD", "blood_burn", "convert").is_empty(), "blood utility fee cannot suicide")
	model.state.get_actor(0).hp_u = 12 * UNIT
	check(use(model, 0, "blood_finish", "finisher"), "finisher accepts legal blood payment")
	pass_clash(model)
	check(model.state.get_actor(0).hp_u == 9 * UNIT and model.state.get_actor(1).hp_u == 12 * UNIT, "low HP condition evaluates after cost:12-3 then8 damage")
	for setup in [{"school":"needle", "card":"needle_hidden", "usage":"draw", "delta":0}, {"school":"taixu", "card":"taixu_breath", "usage":"cycle", "delta":1}]:
		model = school(setup.school)
		fixture(model, 0, [str(setup.card), str(setup.card)])
		var before: int = model.state.get_actor(0).hand.size()
		check(use(model, 0, str(setup.card), str(setup.usage)), "draw utility submitted " + str(setup.school))
		check(model.state.get_actor(0).hand.size() == before + int(setup.delta) and conserved(model, 0), "draw consumes source and preserves12 " + str(setup.school))
		check(option(model, 0, "PLAY_CARD", str(setup.card), str(setup.usage)).is_empty(), "once per ACTION shared across duplicate copies " + str(setup.school))
	model = school("taixu")
	fixture(model, 0, ["taixu_breath", "taixu_breath"], 2)
	check(use(model, 0, "taixu_breath", "breathe") and model.state.get_actor(0).qi_u == 3 * UNIT, "active recovery remains full value")
	check(option(model, 0, "PLAY_CARD", "taixu_breath", "breathe").is_empty(), "recovery once shared across copies")

func test_legacy_and_scope() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy_id_map.json"))
	var count: int = 0
	for old_id in data.mapping:
		var expected: Dictionary = data.mapping[old_id]
		var actual: Dictionary = Legacy.resolve_legacy(str(old_id))
		check(actual.get("definition_id", "") == str(expected.card_id) and actual.get("card_id", "") == str(expected.card_id) and actual.get("usage_id", "") == str(expected.usage_id), "legacy static reference " + str(old_id))
		count += 1
	check(count == 40 and Legacy.resolve_legacy("unknown").is_empty() and Legacy.resolve_legacy("step_01", "evasion").get("usage_id", "") == "evasion", "40 old IDs and unknown/alternate usage")

	var invalid = Model.new()
	invalid.reset(311, 0, "tingfeng", {"schools":{0:"missing_school",1:"needle"}})
	check(not invalid.cards.load_error.is_empty() and invalid.state.phase == "FINISHED" and event_has(invalid, "RULE_ERROR"), "invalid school produces structured catalog failure")

func test_first_insight() -> void:
	var model = school("tingfeng", "tingfeng", 0, {"passives":{1:{"insight":1}}})
	check(known_count(model, 1, 0) == 1, "first ACTION insight reveals exactly one card")
	model.visibility.refresh_intel(0, true)
	model.visibility.refresh_intel(0, true)
	check(known_count(model, 1, 0) == 1, "same hand_generation never reveals second card")
	send(model, option(model, 0, "END_ACTION"))
	send(model, option(model, 1, "END_ACTION"))
	check(known_count(model, 1, 0) == 1, "new hand_generation refreshes one insight card")




func test_school_policy() -> void:
	for setup in [{"school":"taixu","cards":["taixu_breath"],"qi":2,"expected":"breathe"}, {"school":"saber","cards":["saber_charge","saber_river"],"qi":6,"expected":"charge"}, {"school":"needle","cards":["needle_hidden"],"qi":3,"expected":"draw"}]:
		var model = school(str(setup.school))
		fixture(model, 0, setup.cards, int(setup.qi))
		model.state.get_actor(1).cell = Vector2i(9, 4)
		var context: Dictionary = model.decision_context(0)
		var before: String = var_to_str(context)
		var decision: Dictionary = Policy.new().choose_action(context)
		check(decision.get("usage_id", "") == setup.expected and context.legal_actions.has(decision) and before == var_to_str(context), "generic visible effect policy " + str(setup.expected))
	var ranged = school("needle")
	fixture(ranged, 0, ["needle_rain"])
	fixture(ranged, 1, [])
	send(ranged, option(ranged, 0, "BASIC_ATTACK"))
	pass_clash(ranged)
	var retreat: Dictionary = Policy.new().choose_action(ranged.decision_context(0))
	check(retreat.kind == "MOVE" and absi(retreat.target_cell.x - 7) + absi(retreat.target_cell.y - 4) >= 2, "policy moves out to minimum ranged distance")
	var risk = school("blood")
	fixture(risk, 0, ["blood_burn"], 1)
	risk.state.get_actor(0).hp_u = 4 * UNIT
	check(Policy.new().choose_action(risk.decision_context(0)).get("usage_id", "") != "convert", "policy avoids unsafe blood recovery")

func test_path_equivalence() -> void:
	var model = fresh()
	for actor in model.state.actors:
		var batch: Dictionary = model.state.reachable_paths(actor.cell, actor.id)
		var equal: bool = true
		for cell in model.state.terrain:
			if batch.get(cell, []) != model.state.find_path(actor.cell, cell, actor.id):
				equal = false
				print("PATH MISMATCH: actor%d goal%s batch%s original%s" % [actor.id, cell, batch.get(cell, []), model.state.find_path(actor.cell, cell, actor.id)])
		check(equal, "reachable_paths equals find_path across all150 cells actor%d" % actor.id)
