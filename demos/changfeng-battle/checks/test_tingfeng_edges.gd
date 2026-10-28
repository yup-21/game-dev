extends SceneTree
## Small edge audit: expectations describe the supported declarative API, not current bugs.
const Model = preload("res://scripts/battle_model.gd")
var failures: int = 0
var passed: int = 0
func _initialize() -> void: call_deferred("run_tests")
func check(condition: bool, title: String, detail: String = "") -> void:
	print(("PASS: " if condition else "FAIL: ") + title + (" " + detail if not detail.is_empty() else ""))
	if not condition: failures += 1
	else: passed += 1
func fresh(options: Dictionary = {}):
	var m = Model.new()
	m.reset(2026, 0, "tingfeng", options)
	m.state.get_actor(0).cell = Vector2i(6, 4)
	m.state.get_actor(1).cell = Vector2i(7, 4)
	for a in m.state.actors:
		a.hand.clear()
		a.draw_pile.clear()
		a.discard_pile.clear()
		a.resolving.clear()
	for uid in m.cards.instances:
		var a = m.state.get_actor(int(m.cards.instances[uid].owner_actor_id))
		if a.id == 0 and a.hand.is_empty() and m.cards.instances[uid].definition_id == "tf_probe": a.hand.append(uid)
		else: a.draw_pile.append(uid)
	return m
func send(m, kind: String, who: int, extra: Dictionary = {}) -> Dictionary:
	var r: Dictionary = m.submit(m.request(kind, who, extra))
	if m.state.animation_pending: m.acknowledge_animation(m.state.animation_ticket)
	return r
func attack(m) -> Dictionary: return send(m, "PLAY_CARD", 0, {"card_uid": m.state.get_actor(0).hand[0], "usage_id": "probe", "target_id": 1})
func finish(m) -> void:
	while m.state.mode == "CLASH": send(m, "PASS_REACTION", int(m.state.clash.priority_actor_id))
func run_tests() -> void:
	var m = fresh()
	m.hooks.register_rule("retaliate", 1, "HP_DAMAGED", [{"type": "deal_damage", "target": "enemy", "amount": 2}])
	attack(m)
	finish(m)
	check(m.state.get_actor(0).hp_u == 180000 and m.state.get_actor(1).hp_u == 180000, "defender retaliation enemy is relative to Hook source", "hp=%d,%d expected180000,180000" % [m.state.get_actor(0).hp_u,m.state.get_actor(1).hp_u])
	m = fresh()
	var children: Array = []
	for i in range(40): children.append({"type": "gain_qi", "amount": 0.01})
	m.hooks.register_rule("nested", 0, "ATTACK_DECLARED", [{"type": "contest_intercept", "parry_bonus": 3, "on_success": children}])
	var result: Dictionary = attack(m)
	var executed: int = 0
	var limited: bool = false
	for e in result.events:
		if e.type == "QI_GAINED": executed += 1
		if e.type == "HOOK_LIMIT_REACHED": limited = true
	check(executed <= 32 and limited, "nested derived effects obey root effect bound", "executed=%d root_count=%d limited=%s" % [executed,m.state.root_effect_count,limited])
	m = fresh()
	m.cards.definitions.tf_probe.usages[0].effects[0].conditional_bonus = {"if_target_status": "opening", "bonus": 7}
	var valid: bool = m.cards.valid_definition(m.cards.definitions.tf_probe)
	m.resolver.add_status(1, "opening")
	attack(m)
	finish(m)
	check(not valid or m.state.get_actor(1).hp_u == 110000, "accepted conditional_bonus is executed or configuration rejected", "accepted=%s targethp=%d expected110000" % [valid,m.state.get_actor(1).hp_u])
	m = fresh()
	var before: String = var_to_str([m.snapshot(0),m.snapshot(1),m.state.rng.state,m.state.knowledge])
	for i in range(3):
		m.legal_actions(0)
		m.decision_context(0)
		m.snapshot(1)
	check(before == var_to_str([m.snapshot(0),m.snapshot(1),m.state.rng.state,m.state.knowledge]), "ordinary legality and projection queries do not change authority")
	m = fresh()
	m.hooks.register_rule("lethal", 0, "SHIELD_ADDED", [{"type":"deal_damage","target":"enemy","amount":100},{"type":"gain_qi","amount":1}])
	send(m,"BASIC_GUARD",0)
	check(m.state.winner_id == 0 and m.state.get_actor(0).qi_u == 20000 and m.state.hook_queue.is_empty(), "death halts later Hook effects and clears queue")
	m = fresh()
	m.hooks.register_rule("lethal_declaration", 0, "ATTACK_DECLARED", [{"type":"deal_damage","target":"enemy","amount":100}])
	var root_uid: String = str(m.state.get_actor(0).hand[0])
	attack(m)
	check(m.state.outcome != "playing" and m.state.attack.is_empty() and m.state.clash.is_empty() and m.state.reaction_window == "NONE", "lethal declaration clears pending attack and priority")
	check(m.state.get_actor(0).resolving.is_empty() and m.state.get_actor(0).discard_pile.has(root_uid), "lethal declaration settles pending root card zone")
	m = fresh()
	var response_uid: String = ""
	for uid in m.state.get_actor(1).draw_pile:
		if m.cards.instances[uid].definition_id == "tf_guard": response_uid = uid; break
	m.state.get_actor(1).draw_pile.erase(response_uid)
	m.state.get_actor(1).hand.append(response_uid)
	m.hooks.register_rule("lethal_response",1,"CARD_PLAYED",[{"type":"deal_damage","target":"enemy","amount":100}])
	root_uid = str(m.state.get_actor(0).hand[0])
	attack(m)
	send(m,"PLAY_CARD",1,{"card_uid":response_uid,"usage_id":"yield"})
	check(m.state.winner_id == 1 and m.state.attack.is_empty() and m.state.clash.is_empty() and m.state.reaction_window == "NONE", "lethal response Hook clears pending root and stack")
	check(m.state.get_actor(0).resolving.is_empty() and m.state.get_actor(1).resolving.is_empty() and m.state.get_actor(0).discard_pile.has(root_uid) and m.state.get_actor(1).discard_pile.has(response_uid), "lethal response settles both pending card zones")
	m = fresh()
	m.state.get_actor(1).hp_u = 10000
	attack(m)
	finish(m)
	check(m.state.winner_id == 0 and m.state.attack.is_empty() and m.state.clash.is_empty() and m.state.get_actor(0).resolving.is_empty(), "ordinary lethal root finishes without dangling references")
	m = fresh()
	check(is_equal_approx(float(m.snapshot(0).hand[0].usages[0].quoted_cost.qi),1.0), "default MND quote matches one qi")
	m = fresh({"attributes":{0:{"MND":20}}})
	m.cards.definitions.tf_probe.usages[0].cost.hp = 2
	m.cards.definitions.tf_probe.usages[0].effects[0].conditional_bonus = {"if_self_hp_pct_lt_after_cost":0.95,"bonus":3}
	var quote: Dictionary = m.snapshot(0).hand[0].usages[0].quoted_cost
	check(is_equal_approx(float(quote.qi),0.9) and is_equal_approx(float(quote.hp),2.0), "MND twenty exposes final fractional qi and HP quote")
	var qi_before: int = int(m.state.get_actor(0).qi_u)
	attack(m)
	check(m.state.get_actor(0).qi_u == qi_before - 9000 and m.state.get_actor(0).hp_u == 180000, "accepted action pays quoted qi and HP exactly once")
	finish(m)
	check(m.state.get_actor(1).hp_u == 150000, "conditional bonus reads HP after committed HP cost")
	m = fresh()
	m.cards.definitions.tf_probe.usages[0].cost.hp = 2
	m.state.get_actor(0).hp_u = 20000
	var hp_before: String = var_to_str([m.snapshot(0),m.snapshot(1)])
	var insufficient: Dictionary = attack(m)
	check(not insufficient.success and hp_before == var_to_str([m.snapshot(0),m.snapshot(1)]), "HP cost may not kill actor and rejection has no side effects")
	m = fresh()
	m.state.terrain[Vector2i(9,4)] = "rock"
	m.cards.definitions.tf_probe.usages[0].effects[0].on_hit = [{"type":"force_move","target":"enemy","direction":"away_from_attacker","max_distance":3},{"type":"gain_qi","target":"self","amount":0.5}]
	attack(m)
	finish(m)
	check(m.state.get_actor(1).cell == Vector2i(8,4), "forced movement stops before solid obstacle")
	check(m.state.get_actor(0).qi_u == 25000, "blocked forced movement preserves later effects")
	m = fresh()
	var guard_uid: String = ""
	for uid in m.state.get_actor(0).draw_pile:
		if m.cards.instances[uid].definition_id == "tf_guard": guard_uid = uid; break
	m.state.get_actor(0).draw_pile.erase(guard_uid)
	m.state.get_actor(0).hand.append(guard_uid)
	m.hooks.register_rule("once_guard",0,"SHIELD_ADDED",[{"type":"gain_qi","amount":0.5}],100,0.0,{"once_per_turn":true})
	send(m,"BASIC_GUARD",0)
	check(m.state.get_actor(0).qi_u == 25000, "once per owner turn gives first shield Hook reward")
	send(m,"PLAY_CARD",0,{"card_uid":guard_uid,"usage_id":"guard"})
	check(m.state.get_actor(0).qi_u == 15000 and m.state.hook_usage.has("turn:0:1:once_guard"), "second root in same owner ACTION keeps turn key and suppresses extra reward")
	send(m,"END_ACTION",0)
	m.hooks.register_rule("opponent_shield",1,"ATTACK_DECLARED",[{"type":"add_shield","target":"enemy","amount":1}])
	send(m,"BASIC_ATTACK",1,{"target_id":0})
	finish(m)
	check(m.state.get_actor(0).turns_started == 1 and m.state.get_actor(0).qi_u == 15000 and m.state.hook_usage.has("turn:0:1:once_guard"), "opponent ACTION and response roots do not refresh owner's trigger quota")
	send(m,"END_ACTION",1)
	qi_before = int(m.state.get_actor(0).qi_u)
	check(m.state.active_id == 0 and m.state.get_actor(0).turns_started == 2, "next owner ACTION advances owner turn counter")
	send(m,"BASIC_GUARD",0)
	check(m.state.get_actor(0).qi_u == qi_before - 5000 and m.state.hook_usage.has("turn:0:2:once_guard") and not m.state.hook_usage.has("turn:0:1:once_guard"), "new owner turn permits one new reward and prunes old turn key")
	m = fresh()
	m.state.get_actor(0).qi_u = 0
	m.state.get_actor(1).qi_u = 0
	m.hooks.register_rule("time_regen",0,"TIME_ADVANCED",[{"type":"gain_qi","amount":0.5}])
	m.hooks.register_rule("time_regen",1,"TIME_ADVANCED",[{"type":"gain_qi","amount":0.5}])
	send(m,"END_ACTION",0)
	send(m,"END_ACTION",1)
	var global_event: Dictionary = {}
	for event in m.state.events:
		if event.type == "TIME_ADVANCED": global_event = event
	check(not global_event.is_empty() and m.state.global_tick == 100, "global time event is emitted after both initial actions")
	check(m.state.get_actor(0).qi_u == 35000 and m.state.get_actor(1).qi_u == 35000, "global event dispatch gives both owners natural three qi plus Hook half qi")
	var count: int = 0
	for field in ["kind","actor_id","target_cell","expected_revision","request_version","battle_id","request_id","action_id"]:
		for value in [null, [], {}, 1.5, Vector2i.ZERO]:
			m = fresh()
			var req: Dictionary = m.request("MOVE",0,{"target_cell":Vector2i(6,5)})
			req[field] = value
			before = var_to_str([m.snapshot(0),m.snapshot(1),m.state.rng.state,m.state.knowledge])
			var rejected: Dictionary = m.submit(req)
			check(rejected.has("success") and not rejected.get("success",false), "reject malformed request %s/%d" % [field,count])
			check(before == var_to_str([m.snapshot(0),m.snapshot(1),m.state.rng.state,m.state.knowledge]), "malformed request has zero mutation %d" % count)
			var recovery: Dictionary = send(m,"END_ACTION",0)
			check(recovery.get("success",false), "malformed request leaves model usable %d" % count)
			count += 1
	m = Model.new()
	var hidden: bool = true
	for actor in m.decision_context(0).actors:
		if int(actor.id) == 1:
			for item in actor.observed_hand:
				hidden = hidden and not item.has("uid") and not item.has("definition_id")
			hidden = hidden and not actor.has("hand") and not actor.has("draw_pile") and not actor.has("attack_history")
	check(hidden, "opponent hand identity and hidden zones absent from decision context")
	print("EDGE AUDIT: %d PASS / %d failures" % [passed,failures])
	quit(0 if failures == 0 else 1)
