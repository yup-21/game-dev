extends SceneTree
const Model = preload("res://scripts/battle_model.gd")
var failed: int=0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failed+=1
		push_error("FAIL "+label)
	else: print("PASS "+label)

func submit(model, uid: String, usage: String) -> bool:
	if model.state.animation_pending: model.acknowledge_animation(model.state.animation_ticket)
	for option in model.legal_actions(0):
		if option.kind=="PLAY_CARD" and str(option.card_uid)==uid and str(option.usage_id)==usage:
			return bool(model.submit(model.request("PLAY_CARD",0,option)).get("success",false))
	return false

func run() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://checks/fixtures/generated_cards.json"))
	var model=Model.new()
	model.reset(2026,0,"tingfeng",{"card_definitions":data.cards})
	check(model.state.outcome=="playing","extra definitions registered without initial-deck slots")
	var actor=model.state.get_actor(0)
	var before: int=actor.draw_pile.size()+actor.hand.size()+actor.discard_pile.size()+actor.resolving.size()
	var source: String=model.cards.create_instance(actor,"test_parent","hand")
	check(not source.is_empty(),"source can be instantiated from registered definition")
	check(submit(model,source,"make"),"card grants child using general effect")
	check(actor.hand.size()==6,"generated card added to hand")
	var generated: String=""
	for uid in actor.hand:
		if str(model.cards.instance(uid).get("definition_id",""))=="test_token": generated=uid
	check(not generated.is_empty(),"child generated although absent from original deck")
	check(model.cards.instance(generated).get("generated",false),"generated marker recorded")
	check(model.cards.relations(generated).get("parent_uid","")==source,"generated card knows its parent")
	check(model.cards.relations(source).get("child_uids",[]).has(generated),"parent knows child UID")
	check(model.cards.link_instances(source,generated),"runtime links supported")
	check(model.cards.relations(source).get("related_uids",[]).has(generated),"runtime link recorded")
	check(submit(model,generated,"use"),"generated card uses normal play request")
	check(actor.exile_pile.has(generated),"temporary card exiled after play")
	check(not actor.discard_pile.has(generated) and not actor.draw_pile.has(generated),"exiled card cannot reshuffle")
	var zones: Array=actor.hand+actor.draw_pile+actor.discard_pile+actor.resolving+actor.exile_pile
	var seen: Dictionary={}
	for uid in zones: seen[uid]=true
	check(zones.size()==seen.size() and zones.size()==before+2,"dynamic card count conserved over all zones")
	check(model.cards.registry.related(model.cards.definitions,"test_parent","children").has("test_token"),"definition-level child references retained")
	print("RESULTS ",failed," failures")
	quit(1 if failed>0 else 0)
