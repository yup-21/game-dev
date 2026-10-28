extends SceneTree
## Targeted migration tests. Fixtures may arrange authoritative state; all gameplay uses submit.
const Model = preload("res://scripts/battle_model.gd")
const Policy = preload("res://scripts/enemy_ai.gd")
const UNIT: int = 10000
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		push_error("FAIL: " + title)

func fresh(seed: int = 2026, options: Dictionary = {}):
	var model = Model.new()
	model.reset(seed, 0, "tingfeng", options)
	ack(model)
	return model

func ack(model) -> void:
	if model.state.animation_pending: model.acknowledge_animation(model.state.animation_ticket)

func send(model, option: Dictionary) -> Dictionary:
	if option.is_empty(): return {"success": false, "error_code": "FIXTURE_OPTION_MISSING"}
	var result: Dictionary = model.submit(model.request(str(option.get("kind", "")), int(option.get("actor_id", -1)), option))
	ack(model)
	return result

func option(model, actor_id: int, kind: String, definition_id: String = "", usage_id: String = "", cell: Vector2i = Vector2i(-99, -99), link_id: int = -1) -> Dictionary:
	for candidate in model.legal_actions(actor_id):
		if str(candidate.get("kind", "")) != kind: continue
		if not definition_id.is_empty():
			var uid: String = str(candidate.get("card_uid", candidate.get("card_id", "")))
			if str(model.cards.instances.get(uid, {}).get("definition_id", "")) != definition_id: continue
		if not usage_id.is_empty() and str(candidate.get("usage_id", "")) != usage_id: continue
		if cell != Vector2i(-99, -99) and candidate.get("target_cell", Vector2i(-99, -99)) != cell: continue
		if link_id >= 0 and int(candidate.get("link_id", -1)) != link_id: continue
		return candidate
	return {}

func fixture(model, actor_id: int, ids: Array, qi: int = 6) -> void:
	var actor = model.state.get_actor(actor_id)
	actor.hand.clear()
	actor.draw_pile.clear()
	actor.discard_pile.clear()
	actor.resolving.clear()
	actor.qi_u = qi * UNIT
	var selected: Array = []
	for definition_id in ids:
		for uid in model.cards.instances:
			var instance: Dictionary = model.cards.instances[uid]
			if int(instance.get("owner_actor_id", instance.get("owner", -1))) == actor_id and str(instance.get("definition_id", "")) == definition_id and not selected.has(uid):
				selected.append(uid)
				break
	for uid in model.cards.instances:
		var instance: Dictionary = model.cards.instances[uid]
		if int(instance.get("owner_actor_id", instance.get("owner", -1))) == actor_id:
			if selected.has(uid): actor.hand.append(uid)
			else: actor.draw_pile.append(uid)
	model.visibility.refresh_intel(actor_id, true)

func adjacent(model) -> void:
	model.state.get_actor(0).cell = Vector2i(6, 4)
	model.state.get_actor(1).cell = Vector2i(7, 4)

func pass_clash(model) -> void:
	var count: int = 0
	while str(model.state.phase) == "CLASH" and count < 10:
		var who: int = int(model.snapshot(0).get("responder_id", -1))
		var result: Dictionary = send(model, option(model, who, "PASS_REACTION"))
		if not bool(result.get("success", false)):
			check(false, "clash pass available: " + str(result))
			return
		count += 1
	check(count < 10, "clash resolves in bounded passes")

func event_has(model, event_type: String) -> bool:
	for event in model.state.logs:
		if str(event.get("type", "")) == event_type: return true
	return false

func status(model, actor_id: int, status_id: String) -> void:
	var events: Array = []
	model.resolver.add_status(actor_id, status_id, events)

func known_count(model, observer: int, target: int) -> int:
	var count: int = 0
	for actor in model.snapshot(observer).actors:
		if int(actor.id) == target:
			for card in actor.observed_hand:
				if bool(card.get("known", false)): count += 1
	return count

func authority(model) -> String:
	var actors: Array = []
	for actor in model.state.actors:
		actors.append([actor.hp_u, actor.qi_u, actor.shield_u, actor.gauge, actor.cell, actor.hand.duplicate(), actor.draw_pile.duplicate(), actor.discard_pile.duplicate(), actor.resolving.duplicate(), actor.statuses.duplicate(true)])
	return var_to_str([actors, model.state.revision, model.state.global_tick, model.state.phase, model.state.active_id, model.state.clash, model.state.logs, model.state.processed_requests, model.cards.instances])

func run_tests() -> void:
	test_schema_and_requests()
	test_ctb()
	test_usages_and_combos()
	test_chain()
	test_spatial_and_intercept()
	test_intelligence()
	test_hooks()
	test_policy()
	print("RESULTS: %d PASS / %d FAIL - targeted tingfeng migration" % [passed, failed])
	quit(0 if failed == 0 else 1)

func test_schema_and_requests() -> void:
	var model = fresh()
	check(model.cards.definitions.size() == 5, "five canonical forms")
	var usage_count: int = 0
	for definition in model.cards.definitions.values(): usage_count += definition.get("usages", []).size()
	check(usage_count == 12 and model.cards.instances.size() == 24, "twelve usages and 24 mirror instances")
	check(model.snapshot().get("mode", "") == "tingfeng" or model.snapshot().get("profile", "") == "tingfeng", "default model exposes tingfeng mode")
	for actor in model.state.actors:
		check(actor.hand.size() == 5 and actor.draw_pile.size() == 7, "first ACTION does not double draw actor %d" % actor.id)
		check(actor.qi_u == 3 * UNIT, "initial three qi actor %d" % actor.id)
		check(actor.hand.size() + actor.draw_pile.size() + actor.discard_pile.size() + actor.resolving.size() == 12, "initial card conservation actor %d" % actor.id)
	check(model.state.terrain.size() == 150, "original 15 by 10 terrain retained")
	var old_request: Dictionary = model.request("END_ACTION", model.state.active_id)
	model.reset(2026, 0, "tingfeng")
	ack(model)
	var before: String = authority(model)
	check(not model.submit(old_request).success and before == authority(model), "restart rejects old battle request without mutation")
	var malformed: Dictionary = model.request("MOVE", model.state.active_id, {"target_cell": Vector2i(-1, -1)})
	check(not model.submit(malformed).success and before == authority(model), "illegal destination has zero side effects")
	malformed = model.request("END_ACTION", model.state.active_id)
	malformed.request_version = int(malformed.expected_revision) + 1
	check(not model.submit(malformed).success and before == authority(model), "revision alias mismatch has zero side effects")
	malformed = model.request("PLAY_CARD", model.state.active_id, {"card_uid": "forged", "card_id": "other", "usage_id": "probe"})
	check(not model.submit(malformed).success and before == authority(model), "UID alias mismatch has zero side effects")
	var valid: Dictionary = model.request("END_ACTION", model.state.active_id)
	check(model.submit(valid).success, "request submission succeeds")
	ack(model)
	before = authority(model)
	check(not model.submit(valid).success and before == authority(model), "duplicate request has zero side effects")

func test_ctb() -> void:
	var model = fresh(11, {"attributes": {0: {"AGI": 20}, 1: {"AGI": 10}}})
	model.state.get_actor(0).qi_u = UNIT
	model.state.get_actor(1).qi_u = UNIT
	check(model.state.global_tick == 0 and model.state.active_id == 0, "fast actor begins at tick zero")
	check(send(model, option(model, 0, "END_ACTION")).success and model.state.global_tick == 0, "second initial action shares tick zero")
	check(send(model, option(model, 1, "END_ACTION")).success and model.state.global_tick == 84 and model.state.active_id == 0, "120 speed ready at tick 84")
	check(model.state.get_actor(0).qi_u == model.state.get_actor(1).qi_u, "different speeds receive equal regeneration per global tick")
	check(model.state.get_actor(0).qi_u == 35200, "84 ticks grants exactly 2.52 qi")
	status(model, 0, "opening")
	var expiry: int = int(model.state.get_actor(0).statuses.opening.expiry)
	check(expiry == int(model.state.global_tick) + 150, "status expiry uses global tick")
	var count: int = 0
	while int(model.state.global_tick) < expiry and count < 10:
		send(model, option(model, model.state.active_id, "END_ACTION"))
		count += 1
	check(not model.state.get_actor(0).statuses.has("opening"), "status expires by time despite unequal action counts")
	model = fresh()
	adjacent(model)
	fixture(model, 0, ["tf_guard", "tf_probe"])
	fixture(model, 1, ["tf_guard"])
	check(send(model, option(model, 0, "PLAY_CARD", "tf_guard", "guard")).success, "free ACTION permits defensive card")
	check(model.state.global_tick == 0 and model.state.get_actor(0).shield_u == 3 * UNIT, "free action leaves time stopped")
	send(model, option(model, 0, "PLAY_CARD", "tf_probe", "probe"))
	send(model, option(model, 1, "PLAY_CARD", "tf_guard", "yield"))
	pass_clash(model)
	check(model.state.global_tick == 0, "LIFO responses and passes leave global time stopped")
	var tick_before: int = int(model.state.global_tick)
	var qi_before: int = int(model.state.get_actor(0).qi_u)
	model.acknowledge_animation(-1)
	check(model.state.global_tick == tick_before and model.state.get_actor(0).qi_u == qi_before, "animation acknowledgement never advances simulation")
	model = fresh()
	fixture(model, 0, ["tf_guard"])
	send(model, option(model, 0, "PLAY_CARD", "tf_guard", "guard"))
	send(model, option(model, 0, "END_ACTION"))
	check(model.state.global_tick == 0 and model.state.get_actor(0).shield_u == 3 * UNIT, "shield survives same-tick opponent action")
	send(model, option(model, 1, "END_ACTION"))
	check(model.state.global_tick == 100 and model.state.get_actor(0).shield_u == 0, "shield expires at 100 global ticks")

func test_usages_and_combos() -> void:
	var model = fresh(13)
	adjacent(model)
	fixture(model, 0, ["tf_probe", "tf_probe", "tf_guard"])
	fixture(model, 1, [])
	var hp: int = int(model.state.get_actor(1).hp_u)
	check(not option(model, 0, "PLAY_CARD", "tf_probe", "probe").is_empty() and not option(model, 0, "PLAY_CARD", "tf_probe", "follow").is_empty(), "one probe instance offers both active usages")
	var selected: Dictionary = option(model, 0, "PLAY_CARD", "tf_probe", "probe")
	var uid: String = str(selected.get("card_uid", selected.get("card_id", "")))
	check(send(model, selected).success, "probe attack declares")
	check(model.state.get_actor(0).resolving.has(uid) and not model.state.get_actor(0).hand.has(uid), "declared root enters resolving exclusively")
	pass_clash(model)
	check(model.state.get_actor(0).discard_pile.has(uid) and not model.state.get_actor(0).resolving.has(uid), "root instance discards once after resolution")
	send(model, option(model, 0, "PLAY_CARD", "tf_guard", "guard"))
	check(send(model, option(model, 0, "PLAY_CARD", "tf_probe", "follow")).success, "follow remains available after interleaved defense")
	pass_clash(model)
	check(model.state.get_actor(1).hp_u == hp - 5 * UNIT and event_has(model, "COMBO_TRIGGERED"), "probe follow combo deals 2 plus 3 and emits event")
	model = fresh(25)
	adjacent(model)
	fixture(model, 0, ["tf_sunder"])
	fixture(model, 1, ["tf_guard"])
	status(model, 1, "opening")
	hp = int(model.state.get_actor(1).hp_u)
	check(send(model, option(model, 0, "PLAY_CARD", "tf_sunder", "expose")).success, "sunder expose alternative usage declares")
	pass_clash(model)
	check(model.state.get_actor(1).hp_u == hp - 5 * UNIT, "expose on opening gains exactly two damage")
	check(model.state.get_actor(1).statuses.has("hand_exposed") and not model.state.get_actor(1).statuses.has("opening"), "actual expose hit reveals hand and consumes opening")
	model = fresh()
	fixture(model, 0, ["tf_step"])
	check(send(model, option(model, 0, "PLAY_CARD", "tf_step", "step", Vector2i(7, 4))).success, "step usage crosses bridge on original terrain")
	check(model.state.get_actor(0).cell == Vector2i(7, 4), "step updates authoritative board cell")

func test_chain() -> void:
	var model = fresh(16)
	adjacent(model)
	fixture(model, 0, ["tf_probe", "tf_change"])
	fixture(model, 1, ["tf_guard", "tf_change"])
	var hp: int = int(model.state.get_actor(1).hp_u)
	send(model, option(model, 0, "PLAY_CARD", "tf_probe", "probe"))
	check(model.snapshot().responder_id == 1, "defender has first clash priority")
	check(send(model, option(model, 1, "PLAY_CARD", "tf_guard", "yield")).success, "yield L1 declares")
	check(send(model, option(model, 0, "PLAY_CARD", "tf_change", "attack_counter", Vector2i(-99, -99), 1)).success, "attack counter L2 targets legal L1")
	check(send(model, option(model, 1, "PLAY_CARD", "tf_change", "defense_counter", Vector2i(-99, -99), 2)).success, "defense counter L3 targets legal L2")
	pass_clash(model)
	check(model.state.get_actor(1).hp_u == hp and event_has(model, "CHAIN_LINK_CANCELED"), "three-layer LIFO preserves yield after L3 cancels L2")
	check(model.state.get_actor(0).qi_u == 4 * UNIT and model.state.get_actor(1).qi_u == 4 * UNIT, "canceled response still pays cost")
	model = fresh(17)
	adjacent(model)
	fixture(model, 0, ["tf_probe", "tf_change", "tf_change"])
	fixture(model, 1, ["tf_guard", "tf_change", "tf_guard"])
	hp = int(model.state.get_actor(1).hp_u)
	send(model, option(model, 0, "PLAY_CARD", "tf_probe", "probe"))
	send(model, option(model, 1, "PLAY_CARD", "tf_guard", "yield"))
	send(model, option(model, 0, "PLAY_CARD", "tf_change", "attack_counter", Vector2i(-99, -99), 1))
	send(model, option(model, 1, "PLAY_CARD", "tf_change", "defense_counter", Vector2i(-99, -99), 2))
	check(send(model, option(model, 0, "PLAY_CARD", "tf_change", "attack_counter", Vector2i(-99, -99), 3)).success, "fourth response accepted")
	var no_more: bool = true
	for who in [0, 1]:
		for candidate in model.legal_actions(who):
			if str(candidate.get("kind", "")) == "PLAY_CARD": no_more = false
	check(no_more, "at most two responses per actor and four total")
	pass_clash(model)
	check(model.state.get_actor(1).hp_u == hp - 2 * UNIT, "four-layer reverse resolution cancels yield")
	model = fresh()
	adjacent(model)
	fixture(model, 0, ["tf_probe"])
	fixture(model, 1, ["tf_guard"])
	send(model, option(model, 0, "PLAY_CARD", "tf_probe", "probe"))
	check(send(model, option(model, 1, "PASS_REACTION")).success and model.state.phase == "CLASH", "first pass yields priority without resolving")
	check(send(model, option(model, 0, "PASS_REACTION")).success and model.state.phase == "ACTION", "two consecutive passes resolve root")

func test_spatial_and_intercept() -> void:
	for change in [false, true]:
		var model = fresh(18)
		adjacent(model)
		fixture(model, 0, ["tf_probe", "tf_change"])
		fixture(model, 1, ["tf_step"])
		var hp: int = int(model.state.get_actor(1).hp_u)
		send(model, option(model, 0, "PLAY_CARD", "tf_probe", "probe"))
		check(send(model, option(model, 1, "PLAY_CARD", "tf_step", "evasion", Vector2i(8, 4))).success, "evasion legal landing on original board")
		if change: check(send(model, option(model, 0, "PLAY_CARD", "tf_change", "change")).success, "change extends locked footprint")
		pass_clash(model)
		check(model.state.get_actor(1).cell == Vector2i(8, 4), "evasion moves defender")
		check(model.state.get_actor(1).hp_u == hp - (2 * UNIT if change else 0), "change tracks evasion" if change else "evasion produces MISS")
		if not change: check(event_has(model, "ATTACK_MISSED"), "MISS emits semantic event")
	var model = fresh(19)
	adjacent(model)
	fixture(model, 0, ["tf_sunder"])
	fixture(model, 1, ["tf_step"])
	send(model, option(model, 0, "PLAY_CARD", "tf_sunder", "heavy"))
	send(model, option(model, 1, "PLAY_CARD", "tf_step", "evasion", Vector2i(8, 4)))
	pass_clash(model)
	check(model.state.get_actor(0).statuses.has("opening"), "missed heavy leaves attacker opening")
	for usage_id in ["probe", "follow", "heavy"]:
		model = fresh(20)
		adjacent(model)
		fixture(model, 0, ["tf_sunder" if usage_id == "heavy" else "tf_probe"])
		fixture(model, 1, ["tf_guard"])
		var hp: int = int(model.state.get_actor(1).hp_u)
		send(model, option(model, 0, "PLAY_CARD", "tf_sunder" if usage_id == "heavy" else "tf_probe", usage_id))
		check(send(model, option(model, 1, "PLAY_CARD", "tf_guard", "intercept")).success, "intercept legal against " + usage_id)
		pass_clash(model)
		var expected_loss: int = {"probe": 0, "follow": 1, "heavy": 5}[usage_id]
		check(model.state.get_actor(1).hp_u == hp - expected_loss * UNIT, "intercept success contested failure against " + usage_id)
		if usage_id == "probe": check(event_has(model, "ATTACK_INTERRUPTED") and model.state.get_actor(0).statuses.has("opening"), "successful intercept interrupts and applies opening")

func test_intelligence() -> void:
	var model = fresh(21, {"passives": {0: {"insight": 1}, 1: {"conceal": 0}}})
	check(known_count(model, 0, 1) == 1, "insight rank one reveals exactly one card")
	model.snapshot(0)
	model.visibility.refresh_intel(1, false)
	check(known_count(model, 0, 1) == 1, "repeated projection does not reveal more cards")
	for actor in model.snapshot(1).actors:
		if int(actor.id) == 0:
			for card in actor.observed_hand:
				check(not card.has("uid") and not card.has("definition_id"), "unknown card omits identity")
	model = fresh(22, {"passives": {0: {"insight": 2}, 1: {"conceal": 1}}})
	check(known_count(model, 0, 1) == 5, "insight two exceeds conceal one")
	model = fresh(23, {"passives": {0: {"insight": 1}, 1: {"conceal": 1}}})
	check(known_count(model, 0, 1) == 0, "equal conceal beats insight")
	model = fresh(24, {"passives": {0: {"insight": 0}, 1: {"conceal": 2}}})
	fixture(model, 1, ["tf_sunder", "tf_guard"])
	var target: Dictionary = {}
	for actor in model.snapshot(0).actors:
		if int(actor.id) == 1: target = actor
	check(target.danger == "?", "conceal suppresses dangerous-card signal")
	status(model, 1, "hand_exposed")
	model.visibility.refresh_intel(1, false)
	check(known_count(model, 0, 1) == 2, "negative exposed overrides conceal two")
	model.cards.draw(model.state.get_actor(1), 1)
	model.visibility.refresh_intel(1, false)
	check(known_count(model, 0, 1) == 3, "newly drawn card is exposed during negative status")
	model.state.get_actor(1).statuses.erase("hand_exposed")
	model.visibility.refresh_intel(1, false)
	check(known_count(model, 0, 1) == 3, "still-held known UID remembered after exposure ends")
	var uid: String = str(model.state.get_actor(1).hand.pop_back())
	model.state.get_actor(1).discard_pile.append(uid)
	model.visibility.refresh_intel(1, false)
	check(known_count(model, 0, 1) == 2, "leaving hand forgets current-hand identity")
	model = fresh(241, {"passives": {1: {"insight": 2}, 0: {"conceal": 0}}})
	check(known_count(model, 1, 0) == 5 and known_count(model, 0, 1) == 0, "passive intelligence is symmetric and permission filtered")

func test_hooks() -> void:
	var model = fresh(26)
	model.hooks.register_rule("multiple", 0, "SHIELD_ADDED", [{"type": "gain_qi", "amount": 0.5}, {"type": "gain_qi", "amount": 0.25}])
	model.hooks.register_rule("second", 0, "SHIELD_ADDED", [{"type": "gain_qi", "amount": 0.25}])
	var before: int = int(model.state.get_actor(0).qi_u)
	check(send(model, option(model, 0, "BASIC_GUARD")).success, "guard enters same declarative effect pipeline")
	check(model.state.get_actor(0).qi_u == before, "every effect and multiple Hooks execute, fractional qi exact")
	model = fresh(27)
	model.hooks.register_rule("shield_loop", 0, "SHIELD_ADDED", [{"type": "add_shield", "amount": 1}])
	check(send(model, option(model, 0, "BASIC_GUARD")).success, "recursive hook action returns")
	check(event_has(model, "HOOK_LIMIT_REACHED") or event_has(model, "HOOK_REJECTED"), "recursive hook has explicit bounded rejection event")
	check(model.state.get_actor(0).shield_u < 1000 * UNIT, "recursive hook cannot grow shield without bound")

func test_policy() -> void:
	var model = fresh(28)
	var policy = Policy.new()
	var context: Dictionary = model.decision_context(model.state.active_id)
	var before: String = authority(model)
	var action: Dictionary = policy.choose_action(context)
	check(context.legal_actions.has(action) and not action.is_empty(), "AI chooses a current legal action")
	check(before == authority(model), "AI never mutates authority")
	check(policy.choose_action(context) == action, "identical context is idempotent")
	var fake: Dictionary = context.duplicate(true)
	fake.legal_actions = [{"kind": "BASIC_ATTACK", "actor_id": int(context.observer_id)}, {"kind": "END_ACTION", "actor_id": int(context.observer_id)}]
	for index in range(30):
		fake.revision = 100 + index
		action = policy.choose_action(fake)
	check(action.kind == "END_ACTION", "per ACTION budget prevents unbounded AI loops")
	var path: Array = model.find_path(Vector2i(6, 4), Vector2i(8, 5), 0)
	check(not path.is_empty() and path.has(Vector2i(7, 8)), "pathfinding uses southern ford when opponent blocks bridge exit")
	var cursor: Vector2i = Vector2i(6, 4)
	var path_valid: bool = true
	for cell in path:
		path_valid = path_valid and absi(cell.x - cursor.x) + absi(cell.y - cursor.y) == 1 and model.state.passable(cell) and not model.state.occupied(cell, 0)
		cursor = cell
	check(path_valid, "every path step respects terrain and actor occupancy")
