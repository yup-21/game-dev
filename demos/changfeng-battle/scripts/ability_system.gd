extends RefCounted
## Common ability enumeration. PLAY_CARD remains backward compatible.
var state
var cards
var costs
var _rules_ref: WeakRef
var rules:
	get: return _rules_ref.get_ref() if _rules_ref!=null else null
	set(value): _rules_ref=weakref(value)
var techniques
var conditions

func _init(s,c,cost_system,validator,graph,condition_system) -> void:
	state=s
	cards=c
	costs=cost_system
	rules=validator
	techniques=graph
	conditions=condition_system

func options(actor, timing: String, reachable: Dictionary = {}) -> Array:
	var results: Array = []
	if state.mode=="CLASH" and (int(state.clash.counts.get(actor.id,0))>=2 or state.clash.stack.size()>=4): return results
	if reachable.is_empty(): reachable=state.reachable_paths(actor.cell,actor.id)
	for uid in actor.hand:
		var definition: Dictionary=cards.canonical_definition(str(uid))
		if not cards.valid_definition(definition): continue
		for usage in definition.usages:
			if str(usage.timing)!=timing or not rules.condition_allows(actor,usage): continue
			if usage.get("once_per_action",false) and int(actor.card_uses.get(str(definition.id)+":"+str(usage.id),0))>0: continue
			var base: Dictionary={"kind":"PLAY_CARD","actor_id":actor.id,"card_uid":uid,"card_id":uid,"usage_id":usage.id}
			var plan: Dictionary=costs.quote(actor,usage.get("cost",{}),rules.context(actor.id,base))
			if costs.can_pay(actor,plan): results.append_array(_targets(actor,base,usage,reachable))
	var ids: Array=actor.technique_states.keys()
	ids.sort()
	for id in ids:
		for definition in techniques.available_nodes(actor,str(id),timing):
			var stage: String=str(definition.id)
			if not conditions.allows(actor,definition.get("when",{}),{"timing":timing,"tick":state.global_tick,"same_action":int(actor.technique_states[id].last_used_action)==actor.turns_started}): continue
			var base: Dictionary={"kind":"USE_ABILITY","actor_id":actor.id,"technique_id":str(id),"node_id":stage}
			var plan: Dictionary=costs.quote(actor,techniques.cost(actor,str(id),stage),rules.context(actor.id,base))
			if costs.can_pay(actor,plan): results.append_array(_targets(actor,base,definition,reachable))
	return results

func _targets(actor,base: Dictionary,usage: Dictionary,reachable: Dictionary) -> Array:
	var result: Array=[]
	match str(usage.target.kind):
		"self","pending_root_attack": result.append(base)
		"enemy_actor":
			for target in state.actors:
				if not state.is_hostile(actor.id,target.id) or target.hp_u<=0: continue
				var max_dist: int=int(usage.get("attack_profile",{}).get("range",usage.target.get("max_distance",1)))
				var dist: int=rules.distance(actor.cell,target.cell)
				if dist<int(usage.target.get("min_distance",1)) or dist>max_dist: continue
				if usage.target.get("line_of_sight",false) and not rules.line_clear(actor.cell,target.cell): continue
				var option: Dictionary=base.duplicate(true)
				option.target_id=target.id
				result.append(option)
		"reachable_cell":
			for cell in state.terrain:
				var path: Array=reachable.get(cell,[])
				if path.is_empty() or path.size()>int(usage.target.get("max_distance",1)): continue
				var valid: bool=true
				for e in usage.get("effects",[]):
					if e.type=="move" and path.size()>int(e.max_distance): valid=false
				if valid:
					var option: Dictionary=base.duplicate(true)
					option.target_cell=cell
					result.append(option)
		"opponent_unresolved_response_link":
			for link in state.clash.get("stack",[]):
				if int(link.actor_id)==actor.id or link.canceled or link.get("resolved",false): continue
				var option: Dictionary=base.duplicate(true)
				option.link_id=int(link.id)
				result.append(option)
	return result
