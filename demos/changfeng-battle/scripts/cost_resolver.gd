extends RefCounted
const UNIT: int = 10000
var state
var hooks

func _init(s, registry) -> void:
	state=s
	hooks=registry

func quote(actor, cost: Dictionary, context: Dictionary = {}) -> Dictionary:
	var base: int=roundi(float(cost.get("qi",0))*UNIT)
	var qi_cost: int=0
	if base>0:
		var raw: int=ceili(float(base*int(actor.stats.qi_cost_percent))/100)
		qi_cost=maxi(5000,ceili(float(raw)/1000)*1000)
	var hp_cost: int=roundi(float(cost.get("hp",0))*UNIT)
	var modified: Dictionary=hooks.modify(context, {"qi_u":qi_cost,"hp_u":hp_cost},"BEFORE_COST")
	return modified

func can_pay(actor, plan: Dictionary) -> bool:
	return bool(plan.get("valid",true)) and int(plan.get("qi_u",-1))>=0 and int(plan.get("hp_u",-1))>=0 and actor.qi_u>=int(plan.qi_u) and actor.hp_u>int(plan.hp_u)

func pay(actor, plan: Dictionary) -> void:
	assert(can_pay(actor,plan),"Payment requires an accepted precommit plan")
	actor.qi_u-=int(plan.qi_u)
	actor.hp_u-=int(plan.hp_u)
