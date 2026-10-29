extends RefCounted
## Cross-ACTION technique progression; separate from cards and card UIDs.
var definitions: Dictionary = {}
var load_error: String = ""
var states # Unified StateSystem owns technique stage lifetimes.

func _init(path: String = "res://data/techniques.json") -> void:
	if not FileAccess.file_exists(path):
		load_error = "Technique catalog missing: " + path
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != 1 or not data.get("techniques") is Array:
		load_error = "Invalid technique catalog"
		return
	for d in data.techniques:
		if not d is Dictionary or not d.get("id") is String or str(d.id).is_empty() or definitions.has(d.id):
			load_error = "Duplicate or invalid technique id"
			return
		if not d.get("nodes") is Array or d.nodes.is_empty() or d.nodes.size() > 32: load_error = "Invalid graph nodes"; return
		var ids: Dictionary = {}
		for n in d.nodes:
			if not n is Dictionary or not n.get("id") is String or ids.has(n.id): load_error = "Invalid node"; return
			if n.get("timing", "") not in ["ACTION", "ATTACK_REACTION", "DEFENSE_REACTION"]: load_error = "Invalid timing"; return
			if not n.get("effects", []) is Array or n.effects.is_empty(): load_error = "Invalid effects"; return
			if not n.get("cost", {}) is Dictionary or not n.get("target", {}) is Dictionary: load_error = "Invalid costs or target"; return
			ids[n.id] = true
		if not ids.has(d.get("entry", "")): load_error = "Invalid entry"; return
		for n in d.nodes:
			if not ids.has(n.get("next", d.entry)): load_error = "Invalid transition"; return
		definitions[d.id] = d.duplicate(true)

func _key(id: String) -> String:
	return "technique:"+id

func _register(id: String) -> bool:
	if states==null: return false
	var key: String=_key(id)
	if states.definition(key).is_empty():
		return states.register_definition(key,{"id":key,"name":id,"scope":"technique",
			"stack_limit":1,"expiry":{"kind":"permanent"},"private":true})
	return true

func _expiry(actor,id: String,last: int) -> int:
	if last<0: return -1
	var hold: float=float(definitions[id].get("hold_own_actions",2))
	# Preserve existing contract for huge but valid JSON retention numbers.
	if hold>=float(9223372036854770000): return -1
	return last+int(hold)

func _sync_stage(actor,id: String) -> void:
	if states==null or not actor.technique_states.has(id): return
	var key: String=_key(id)
	var legacy: Dictionary=actor.technique_states[id]
	if not states.has(actor.id,key):
		states.add(actor.id,key,1,{"node":str(definitions[id].entry),"rank":int(legacy.rank),"last_used_action":-1})
	var instance: Dictionary=actor.statuses[key]
	# Legacy external callers/tests may still change their public stage projection.
	if str(instance.get("node",""))!=str(legacy.node) or int(instance.get("last_used_action",-1))!=int(legacy.last_used_action):
		instance.node=str(legacy.node)
		instance.last_used_action=int(legacy.last_used_action)
		instance.expires_at_action=_expiry(actor,id,int(legacy.last_used_action))
	instance.rank=int(legacy.rank)

func configure(actor, learned: Dictionary) -> bool:
	for id in learned:
		if not definitions.has(id) or not learned[id] is int or learned[id]<1 or not _register(str(id)):
			load_error="Invalid learned technique: "+str(id)
			return false
		actor.technique_states[id]={"node":definitions[id].entry,"rank":learned[id],"last_used_action":-1}
		states.add(actor.id,_key(str(id)),1,actor.technique_states[id])
	return true

func node(actor,id: String,stage: String) -> Dictionary:
	if not actor.technique_states.has(id) or not definitions.has(id): return {}
	_sync_stage(actor,id)
	if not states.has(actor.id,_key(id)): return {}
	var active: String=str(actor.statuses[_key(id)].get("node",""))
	if active!=stage: return {}
	for n in definitions[id].nodes:
		if str(n.id)==stage and int(n.get("unlock_rank",1))<=int(actor.technique_states[id].rank):
			return n.duplicate(true)
	return {}

func cost(actor,id: String,stage: String) -> Dictionary:
	var n: Dictionary=node(actor,id,stage)
	if n.is_empty(): return {}
	var c: Dictionary=n.get("cost",{}).duplicate(true)
	if int(actor.technique_states[id].last_used_action)==actor.turns_started and actor.turns_started>0:
		c["qi"]=float(c.get("qi",0))+float(n.get("same_action_extra_qi",0))
	return c

func advance(actor,id: String,stage: String,interrupted: bool=false) -> void:
	var n: Dictionary=node(actor,id,stage)
	if n.is_empty(): return
	var d: Dictionary=definitions[id]
	var next_id: String=str(n.get("next",d.entry))
	if interrupted and bool(n.get("reset_on_interrupt",true)): next_id=str(d.entry)
	var unlocked: bool=false
	for candidate in d.nodes:
		if str(candidate.id)==next_id and int(candidate.get("unlock_rank",1))<=int(actor.technique_states[id].rank):
			unlocked=true
			break
	var current: String=next_id if unlocked else str(d.entry)
	var last: int=actor.turns_started
	actor.technique_states[id].node=current
	actor.technique_states[id].last_used_action=last
	_sync_stage(actor,id)
	# Only the StateSystem stores the retention deadline.
	actor.statuses[_key(id)].expires_at_action=_expiry(actor,id,last) if current!=str(d.entry) else -1

func on_action_start(actor) -> void:
	if states==null: return
	for id in actor.technique_states:
		_sync_stage(actor,str(id))
	states.on_owner_action(actor.id)
	for id in actor.technique_states:
		if not states.has(actor.id,_key(str(id))):
			actor.technique_states[id].node=definitions[id].entry
			actor.technique_states[id].last_used_action=-1
			states.add(actor.id,_key(str(id)),1,actor.technique_states[id])

func reset(actor,id: String) -> bool:
	if not actor.technique_states.has(id): return false
	actor.technique_states[id].node=definitions[id].entry
	actor.technique_states[id].last_used_action=-1
	if states!=null:
		states.remove(actor.id,_key(id))
		states.add(actor.id,_key(id),1,actor.technique_states[id])
	return true

## Reject invalid graph inputs before any action is enumerated.
func validate_with(cards, conditions) -> bool:
	for d in definitions.values():
		var hold = d.get("hold_own_actions", 2)
		if not (hold is int or hold is float) or not is_finite(float(hold)) or hold < 0 or (hold is float and hold != floor(hold)):
			load_error="Invalid hold duration"
			return false
		for node_def in d.nodes:
			if node_def.get("target",{}).get("kind","") not in ["self","enemy_actor","reachable_cell","pending_root_attack","opponent_unresolved_response_link"]:
				load_error="Invalid target kind: "+str(node_def.id)
				return false
			for cost_value in node_def.cost.values():
				if not (cost_value is int or cost_value is float) or not is_finite(float(cost_value)) or float(cost_value)<0 or float(cost_value)>10000:
					load_error="Invalid node cost: "+str(node_def.id)
					return false
			if not conditions.valid_spec(node_def.get("when",{})):
				load_error="Invalid node condition: "+str(node_def.id)
				return false
			for effect in node_def.effects:
				if not cards.valid_effect(effect):
					load_error="Invalid node effect: "+str(node_def.id)
					return false
	return true
