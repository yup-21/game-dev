extends SceneTree
## Watch instances without retaining them, including every subsystem replaced by reset.
const Model = preload("res://scripts/battle_model.gd")
const COMPONENTS: Array = ["state", "cards", "attributes", "statuses", "visibility", "hooks", "costs", "rules", "combos", "audit", "turns", "reactions", "resolver", "techniques", "conditions", "abilities"]
const GRAPH_OPTIONS: Dictionary = {"technique_catalog_path": "res://checks/fixtures/technique_graph.json", "techniques": {0: {"test_chain": 3}}}
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		push_error("FAIL: " + title)

func watch(model) -> Dictionary:
	var refs: Dictionary = {}
	for component in COMPONENTS:
		refs[component] = weakref(model.get(component))
	refs["card_catalog"] = weakref(model.cards.catalog)
	refs["card_registry"] = weakref(model.cards.registry)
	refs["rng"] = weakref(model.state.rng)
	for actor in model.state.actors:
		refs["actor_%d" % actor.id] = weakref(actor)
	return refs

func check_released(refs: Dictionary, title: String) -> void:
	var retained: Array = []
	for name in refs:
		if refs[name].get_ref() != null: retained.append(name)
	check(retained.is_empty(), "%s releases all %d watched instances; retained=%s" % [title, refs.size(), retained])

func find_option(model, actor_id: int, kind: String, uid: String = "") -> Dictionary:
	for option in model.legal_actions(actor_id):
		if str(option.kind) != kind: continue
		if not uid.is_empty() and str(option.get("card_uid", "")) != uid: continue
		return option
	return {}

func send(model, option: Dictionary) -> bool:
	if option.is_empty(): return false
	var result: Dictionary = model.submit(model.request(str(option.kind), int(option.actor_id), option))
	if model.state.animation_pending: model.acknowledge_animation(model.state.animation_ticket)
	return bool(result.get("success", false))

func exercise(model, title: String, resolve_clash: bool) -> void:
	check(model.state.outcome == "playing", title + " loads equipped technique graph")
	var actor = model.state.get_actor(0)
	var target = model.state.get_actor(1)
	actor.cell = Vector2i(6, 4)
	target.cell = Vector2i(7, 4)
	actor.qi_u = 60000
	var guard_uid: String = model.cards.create_instance(actor, "tf_guard")
	var shield_before: int = actor.shield_u
	check(send(model, find_option(model, 0, "PLAY_CARD", guard_uid)), title + " enumerates and submits a card")
	check(actor.shield_u > shield_before, title + " applies card effects through live rules")
	var hp_before: int = target.hp_u
	check(send(model, find_option(model, 0, "USE_ABILITY")), title + " enumerates and submits a technique")
	check(model.state.mode == "CLASH", title + " opens technique clash")
	if resolve_clash:
		for _i in range(2):
			var responder: int = int(model.state.clash.get("priority_actor_id", -1))
			check(send(model, find_option(model, responder, "PASS_REACTION")), title + " submits reaction pass")
		check(model.state.mode == "ACTION" and target.hp_u < hp_before and actor.technique_states.test_chain.node == "two", title + " resolves effects and advances technique")

func run_tests() -> void:
	var model = Model.new()
	var refs: Dictionary = watch(model)
	refs["model"] = weakref(model)
	check(model.state.outcome == "playing", "default model initializes")
	model = null
	check_released(refs, "default model disposal")
	# Reuse one model while replacing both idle and mid-clash subsystem graphs.
	model = Model.new()
	refs = watch(model)
	for generation in range(4):
		model.reset(2026 + generation, 0, "tingfeng", GRAPH_OPTIONS)
		check_released(refs, "reset %d" % generation)
		exercise(model, "generation %d" % generation, generation % 2 == 0)
		refs = watch(model)
	refs["model"] = weakref(model)
	model = null
	check_released(refs, "mid-clash model disposal")
	await process_frame
	await process_frame
	print("MODEL LIFECYCLE: %d PASS / %d FAIL" % [passed, failed])
	quit(0 if failed == 0 else 1)
