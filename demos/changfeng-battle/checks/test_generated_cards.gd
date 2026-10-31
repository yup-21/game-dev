extends SceneTree
const Model = preload("res://scripts/battle_model.gd")
const CARD_FIXTURE: Dictionary = {
  "cards": [
    {
      "id": "test_parent",
      "name": "Entry",
      "relations": {
        "children": [
          "test_token"
        ],
        "related": []
      },
      "usages": [
        {
          "id": "make",
          "timing": "ACTION",
          "cost": {
            "qi": 0
          },
          "target": {
            "kind": "self"
          },
          "effects": [
            {
              "type": "grant_card",
              "card_id": "test_token",
              "destination": "hand",
              "count": 1
            }
          ]
        }
      ]
    },
    {
      "id": "test_token",
      "name": "Token",
      "lifecycle": "exile_on_finish",
      "relations": {
        "parent": "test_parent",
        "children": [],
        "related": []
      },
      "usages": [
        {
          "id": "use",
          "timing": "ACTION",
          "cost": {
            "qi": 0
          },
          "target": {
            "kind": "self"
          },
          "effects": [
            {
              "type": "gain_qi",
              "amount": 1
            }
          ]
        }
      ]
    }
  ]
}
var failed: int=0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> bool:
	if not ok:
		failed+=1
		push_error("FAIL "+label)
	else: print("PASS "+label)
	return ok

func finish() -> void:
	print("RESULTS ",failed," failures")
	quit(1 if failed>0 else 0)

func check_retention_durations(model, base: Dictionary) -> void:
	var json_values: Array = [0.0, 2.0, 20.0, 21.0, -1.0, 2.5]
	var cases: Array = [
		[0,true,"integer zero"],
		[2,true,"integer two"],
		[20,true,"integer upper boundary"],
		[json_values[0],true,"float zero"],
		[json_values[1],true,"float two"],
		[json_values[2],true,"float upper boundary"],
		[json_values[3],false,"float above upper boundary"],
		[json_values[4],false,"float negative integer"],
		[json_values[5],false,"float fraction"],
		[21,false,"integer above upper boundary"],
		[-1,false,"negative integer"],
		[-0.5,false,"negative fraction"],
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
	for i in range(cases.size()):
		var test_case: Array = cases[i]
		var definition: Dictionary = base.duplicate(true)
		definition.id = "test_retention_validation_"+str(i)
		definition.retain_own_actions = test_case[0]
		var accepted: bool = model.cards.register_definition(definition)
		check(accepted==test_case[1] and model.cards.definitions.has(definition.id)==test_case[1],"retention validates "+test_case[2])
	var default_definition: Dictionary = base.duplicate(true)
	default_definition.id = "test_retention_default"
	default_definition.erase("retain_own_actions")
	check(model.cards.register_definition(default_definition),"missing retention uses default")

func submit(model, uid: String, usage: String) -> bool:
	if model.state.animation_pending: model.acknowledge_animation(model.state.animation_ticket)
	for option in model.legal_actions(0):
		if option.kind=="PLAY_CARD" and str(option.card_uid)==uid and str(option.usage_id)==usage:
			return bool(model.submit(model.request("PLAY_CARD",0,option)).get("success",false))
	return false

func run() -> void:
	var data: Dictionary = CARD_FIXTURE.duplicate(true)
	if not check(data is Dictionary and data.get("cards") is Array,"generated fixture parsed"):
		finish()
		return
	var model=Model.new()
	model.reset(2026,0,"tingfeng",{"card_definitions":data.cards})
	if not check(model.state.outcome=="playing","extra definitions registered without initial-deck slots"):
		finish()
		return
	var actor=model.state.get_actor(0)
	var before: int=actor.draw_pile.size()+actor.hand.size()+actor.discard_pile.size()+actor.resolving.size()
	var source: String=model.cards.create_instance(actor,"test_parent","hand")
	if not check(not source.is_empty(),"source can be instantiated from registered definition"):
		finish()
		return
	check(submit(model,source,"make"),"card grants child using general effect")
	check(actor.hand.size()==6,"generated card added to hand")
	var generated: String=""
	for uid in actor.hand:
		if str(model.cards.instance(uid).get("definition_id",""))=="test_token": generated=uid
	if not check(not generated.is_empty(),"child generated although absent from original deck"):
		finish()
		return
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
	var retained: Dictionary = CARD_FIXTURE.cards[1].duplicate(true)
	retained.id="test_retained"
	retained.name="Retained token"
	retained.relations={"parent":"","children":[],"related":[]}
	retained.retain_own_actions=2.0
	check(retained.retain_own_actions is float,"retention duration supports integral floats")
	if not check(model.cards.register_definition(retained),"retention definition registered"):
		finish()
		return
	var hold_uid: String=model.cards.create_instance(actor,"test_retained","hand")
	if not check(not hold_uid.is_empty(),"retained card instantiated"):
		finish()
		return
	check(model.cards.retain_on_refresh(actor,hold_uid),"generated card survives next hand refresh")
	actor.turns_started+=1
	check(model.cards.retain_on_refresh(actor,hold_uid),"retained card survives first subsequent own ACTION")
	actor.turns_started+=1
	check(not model.cards.retain_on_refresh(actor,hold_uid),"retained card expires at configured boundary")
	check_retention_durations(model,retained)
	finish()
