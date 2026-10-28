extends SceneTree
const Model = preload("res://scripts/battle_model.gd")
const Policy = preload("res://scripts/enemy_ai.gd")
var failed: int = 0

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var evidence: Array = []
	for seed_value in [2026, 13, 241]:
		for first_actor in [0, 1]:
			var original: Dictionary = play(seed_value, first_actor)
			var replay: Dictionary = play(seed_value, first_actor)
			if original != replay:
				failed += 1
				push_error("FAIL: deterministic replay seed %d first %d" % [seed_value, first_actor])
			else:
				print("PASS: replay seed %d first %d winner %d actions %d requests %d tick %d" % [seed_value, first_actor, original.winner, original.actions, original.trace.size(), original.tick])
			evidence.append(original)
	var file: FileAccess = FileAccess.open("res://checks/tingfeng-playthrough-results.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(evidence, "\t"))
	print("RESULTS: %d FAIL - symmetric tingfeng playthroughs and seeded replay" % failed)
	quit(0 if failed == 0 else 1)

func play(seed_value: int, first_actor: int) -> Dictionary:
	var model = Model.new()
	model.reset(seed_value, first_actor, "tingfeng")
	var policy = Policy.new()
	var trace: Array = []
	var violation: String = ""
	while str(model.state.outcome) == "playing" and trace.size() < 1800 and int(model.state.action_no) < 300:
		if model.state.animation_pending: model.acknowledge_animation(model.state.animation_ticket)
		var view: Dictionary = model.snapshot(0)
		var who: int = int(view.responder_id) if str(view.phase) == "CLASH" else int(view.active_id)
		var context: Dictionary = model.decision_context(who)
		var decision: Dictionary = policy.choose_action(context)
		if decision.is_empty() or not context.legal_actions.has(decision):
			violation = "policy produced no legal action: " + str(context)
			break
		var tick: int = int(model.state.global_tick)
		var request: Dictionary = model.request(str(decision.kind), who, decision)
		var result: Dictionary = model.submit(request)
		if not bool(result.get("success", false)):
			violation = "legal AI request rejected: " + str(result) + " " + str(decision)
			break
		if decision.kind != "END_ACTION" and int(model.state.global_tick) != tick:
			violation = "time advanced inside active decision"
			break
		var stable: Dictionary = decision.duplicate(true)
		for field in ["battle_id", "action_id", "request_id", "expected_revision", "request_version"]: stable.erase(field)
		stable.target_cell = str(stable.target_cell) if stable.has("target_cell") else ""
		trace.append(stable)
		for actor in model.state.actors:
			var zones: Array = actor.hand + actor.draw_pile + actor.discard_pile + actor.resolving
			var unique: Dictionary = {}
			for uid in zones: unique[uid] = true
			if zones.size() != 12 or unique.size() != 12 or actor.qi_u < 0 or actor.hp_u < 0:
				violation = "card conservation or nonnegative resource invariant"
		if not violation.is_empty(): break
	if not violation.is_empty() or str(model.state.outcome) == "playing":
		failed += 1
		push_error("FAIL: seed %d first %d tick %d action %d: %s" % [seed_value, first_actor, model.state.global_tick, model.state.action_no, violation if not violation.is_empty() else "duel did not finish"])
	var hp: Array = []
	for actor in model.state.actors: hp.append(actor.hp_u)
	return {"seed": seed_value, "first_actor": first_actor, "winner": int(model.state.winner_id), "tick": int(model.state.global_tick), "actions": int(model.state.action_no), "hp_u": hp, "trace": trace, "violation": violation}
