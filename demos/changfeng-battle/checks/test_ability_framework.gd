extends SceneTree
const Model = preload("res://scripts/battle_model.gd")
const Conditions = preload("res://scripts/condition_evaluator.gd")
var failed: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error("FAIL " + message)
	else:
		print("PASS " + message)

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
	model.reset(2026,0,"tingfeng",{"technique_catalog_path":"res://checks/fixtures/technique_graph.json","techniques":{0:{"test_chain":3}}})
	check(model.state.outcome=="playing","load equipped graph")
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
	m2.reset(2026,0,"tingfeng",{"technique_catalog_path":"res://checks/fixtures/technique_graph.json","techniques":{0:{"test_chain":1}}})
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
	print("FAILURES ",failed)
	quit(1 if failed>0 else 0)
