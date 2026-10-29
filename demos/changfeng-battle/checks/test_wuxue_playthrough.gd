extends SceneTree
const Model = preload("res://scripts/battle_model.gd")
const Policy = preload("res://scripts/enemy_ai.gd")
var failed: int = 0

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var cases: Array = []
	var catalog = Model.new().cards.catalog
	for entry in catalog.schools: cases.append([str(entry.id), "tingfeng", 2026, 0])
	cases.append_array([["saber", "needle", 13, 1], ["ember", "finger", 241, 0], ["blood", "taixu", 89, 1], ["tide", "tide", 47, 0], ["taixu", "taixu", 93, 1], ["needle", "needle", 113, 0]])
	var evidence: Array = []
	for setup in cases:
		var result: Dictionary = play(setup)
		evidence.append(result)
		store_evidence(evidence)
		print("DUEL: %s vs %s seed%d first%d outcome%s winner%d actions%d requests%d tick%d" % [setup[0], setup[1], setup[2], setup[3], result.outcome, result.winner, result.actions, result.requests, result.tick])
	for setup in [["saber", "needle", 13, 1], ["tide", "tide", 47, 0]]:
		var a: Dictionary = {}
		for previous in evidence:
			if previous.schools == [setup[0],setup[1]] and previous.seed == setup[2] and previous.first_actor == setup[3]: a = previous
		var b: Dictionary = play(setup)
		if a != b:
			failed += 1
			push_error("FAIL: seeded replay " + str(setup))
		else: print("PASS: seeded replay " + str(setup))
	store_evidence(evidence)
	print("SCHOOL PLAYTHROUGHS: %d FAIL" % failed)
	quit(0 if failed == 0 else 1)

func store_evidence(evidence: Array) -> void:
	var file = FileAccess.open("res://captures/checks/wuxue-playthrough-results.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(evidence, "\t"))

func play(setup: Array) -> Dictionary:
	var model = Model.new()
	model.reset(int(setup[2]), int(setup[3]), "tingfeng", {"schools":{0:str(setup[0]),1:str(setup[1])}})
	var policy = Policy.new()
	var trace: Array = []
	var violation: String = ""
	while str(model.state.outcome) == "playing" and trace.size() < 2200 and int(model.state.action_no) < 300:
		if model.state.animation_pending: model.acknowledge_animation(model.state.animation_ticket)
		var view: Dictionary = model.snapshot(0)
		var who: int = int(view.responder_id) if str(view.phase) == "CLASH" else int(view.active_id)
		var context: Dictionary = model.decision_context(who)
		var decision: Dictionary = policy.choose_action(context)
		if decision.is_empty() or not context.legal_actions.has(decision):
			violation = "policy produced no legal action"
			break
		var tick: int = int(model.state.global_tick)
		var result: Dictionary = model.submit(model.request(str(decision.kind), who, decision))
		if not bool(result.get("success", false)):
			violation = "legal request rejected:" + str(result)
			break
		if decision.kind != "END_ACTION" and int(model.state.global_tick) != tick:
			violation = "time advanced within decision"
			break
		var stable: Dictionary = decision.duplicate(true)
		for field in ["battle_id", "action_id", "request_id", "expected_revision", "request_version"]: stable.erase(field)
		if stable.has("target_cell"): stable.target_cell = str(stable.target_cell)
		trace.append(stable)
		for actor in model.state.actors:
			var zones: Array = actor.hand + actor.draw_pile + actor.discard_pile + actor.resolving
			var unique: Dictionary = {}
			for uid in zones: unique[uid] = true
			if zones.size() != 12 or unique.size() != 12 or actor.qi_u < 0 or actor.hp_u < 0: violation = "conservation/nonnegative invariant"
		if not violation.is_empty(): break
	if not violation.is_empty() or str(model.state.outcome) == "playing":
		failed += 1
		push_error("FAIL: %s vs %s seed%d action%d: %s" % [setup[0], setup[1], setup[2], model.state.action_no, violation if not violation.is_empty() else "duel did not finish"])
	var hp: Array = []
	for actor in model.state.actors: hp.append(actor.hp_u)
	return {"schools":[setup[0],setup[1]],"seed":setup[2],"first_actor":setup[3],"outcome":model.state.outcome,"winner":model.state.winner_id,"actions":model.state.action_no,"requests":trace.size(),"tick":model.state.global_tick,"hp_u":hp,"trace":trace,"violation":violation}
