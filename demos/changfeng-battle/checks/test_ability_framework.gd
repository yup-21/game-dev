extends SceneTree
const Model = preload("res://scripts/battle_model.gd")
const Conditions = preload("res://scripts/condition_evaluator.gd")
var failed: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> bool:
	if not ok:
		failed += 1
		push_error("FAIL " + message)
	else:
		print("PASS " + message)
	return ok

func finish() -> void:
	print("FAILURES ",failed)
	quit(1 if failed>0 else 0)

func check_hold_durations(model) -> void:
	var runtime = model.techniques
	var definition: Dictionary = runtime.definitions.test_chain
	var original: Variant = definition.hold_own_actions
	check(original is int,"typed hold duration is an integer")
	var json_values: Array = [0.0, 2.0, 21.0, 10001.0, 1e20]
	var cases: Array = [
		[0,true,"integer zero"],
		[2,true,"integer two"],
		[json_values[0],true,"float zero"],
		[json_values[1],true,"float two"],
		[json_values[2],true,"float value above retention limit"],
		[json_values[3],true,"float large duration without an upper limit"],
		[json_values[4],true,"floating-point duration above int64 range"],
		[1000000000000,true,"large integer duration"],
		[2.5,false,"fraction"],
		[-0.5,false,"negative fraction"],
		[-1,false,"negative integer"],
		[-1.0,false,"negative float"],
		[NAN,false,"NaN"],
		[INF,false,"infinity"],
		[-INF,false,"negative infinity"],
		["2",false,"numeric string"],
		[true,false,"true"],
		[false,false,"false"],
		[null,false,"null"],
		[[],false,"array"],
		[{},false,"dictionary"],
	]
	for test_case in cases:
		definition.hold_own_actions = test_case[0]
		check(runtime.validate_with(model.cards,model.conditions)==test_case[1],"hold duration validates "+test_case[2])
	definition.erase("hold_own_actions")
	check(runtime.validate_with(model.cards,model.conditions),"missing hold duration uses default")
	definition.hold_own_actions = json_values[4]
	var actor = model.state.get_actor(0)
	var original_state: Dictionary = actor.technique_states.test_chain.duplicate(true)
	var original_turns: int = actor.turns_started
	actor.technique_states.test_chain.node = "two"
	actor.technique_states.test_chain.last_used_action = actor.turns_started
	actor.turns_started += 1
	runtime.on_action_start(actor)
	check(actor.technique_states.test_chain.node=="two" and actor.technique_states.test_chain.last_used_action==original_turns,"floating-point duration above int64 range does not expire early")
	actor.technique_states.test_chain = original_state
	actor.turns_started = original_turns
	definition.hold_own_actions = original

func send(model, kind: String, actor_id: int, node_id: String = "") -> bool:
	if model.state.animation_pending: model.acknowledge_animation(model.state.animation_ticket)
	for option in model.legal_actions(actor_id):
		if str(option.kind) != kind: continue
		if kind == "USE_ABILITY" and str(option.get("node_id", "")) != node_id: continue
		return bool(model.submit(model.request(kind, actor_id, option)).get("success", false))
	return false

func finish_clash(model) -> void:
	for i in range(5):
		if model.state.mode != "CLASH": break
		var actor_id: int = int(model.state.clash.priority_actor_id)
		check(send(model,"PASS_REACTION",actor_id),"response pass")
	check(model.state.mode == "ACTION","clash closed")

func run() -> void:
	var model = Model.new()
	model.reset(2026,0,"tingfeng",{"technique_catalog_path":"res://checks/fixtures/technique_graph.tres","techniques":{0:{"test_chain":3}}})
	if not check(model.state.outcome=="playing","load equipped graph"):
		finish()
		return
	var a = model.state.get_actor(0)
	a.cell = Vector2i(7,4)
	a.qi_u = 60000
	check(model.conditions.allows(a,{"all":[{"type":"qi_at_least","value":6},{"not":{"type":"qi_at_least","value":7}}]}),"bounded conditions")
	check(not model.conditions.allows(a,{"type":"unknown"}),"unknown condition fails closed")
	check(not model.snapshot(1).actors[0].has("technique_states"),"opponent cannot read private technique progress")
	check(model.snapshot(0).actors[0].has("technique_states"),"owner can read technique progress")
	check(send(model,"USE_ABILITY",0,"one"),"first node")
	finish_clash(model)
	check(a.technique_states.test_chain.node=="two","first resolves to second")
	check(send(model,"USE_ABILITY",0,"two"),"second node")
	finish_clash(model)
	check(a.qi_u==20000,"same ACTION surcharge applied")
	check(send(model,"USE_ABILITY",0,"three"),"third node")
	finish_clash(model)
	check(a.qi_u==0 and a.technique_states.test_chain.node=="one","third completes and returns to entry")
	var m2 = Model.new()
	m2.reset(2026,0,"tingfeng",{"technique_catalog_path":"res://checks/fixtures/technique_graph.tres","techniques":{0:{"test_chain":1}}})
	if not check(m2.state.outcome=="playing","load rank one graph"):
		finish()
		return
	var b = m2.state.get_actor(0)
	b.cell=Vector2i(7,4)
	check(send(m2,"USE_ABILITY",0,"one"),"rank one entry")
	finish_clash(m2)
	check(b.technique_states.test_chain.node=="one","locked successor safely resets")
	var runtime=m2.techniques
	b.technique_states.test_chain.node="two"
	b.technique_states.test_chain.last_used_action=b.turns_started
	b.turns_started+=1
	runtime.on_action_start(b)
	check(b.technique_states.test_chain.node=="two","next own ACTION retains node")
	b.turns_started+=2
	runtime.on_action_start(b)
	check(b.technique_states.test_chain.node=="one","expired stage resets")
	check_hold_durations(model)
	finish()
