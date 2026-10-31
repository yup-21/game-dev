extends RefCounted
## Cross-ACTION technique progression; separate from cards and card UIDs.
var definitions: Dictionary = {}
var load_error: String = ""

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
		var trigger: Dictionary=d.get("trigger",{})
		if not trigger.is_empty():
			if not trigger.get("card_id") is String or not trigger.get("usage_id") is String or not trigger.get("ready_stage") is String: load_error = "Invalid stage trigger"; return
			var valid_stage := false
			for n in d.nodes:
				if str(n.get("stage",n.id)) == str(trigger.ready_stage): valid_stage=true
			if not valid_stage: load_error = "Unknown ready stage"; return
		definitions[d.id] = d.duplicate(true)

func configure(actor, learned: Dictionary) -> bool:
	for id in learned:
		if not definitions.has(id) or not learned[id] is int or learned[id] < 1:
			load_error = "Invalid learned technique: " + str(id)
			return false
		actor.technique_states[id] = {"node": definitions[id].entry, "rank": learned[id], "last_used_action": -1}
	return true

func node(actor, id: String, node_id: String) -> Dictionary:
	if not actor.technique_states.has(id) or not definitions.has(id): return {}
	for n in definitions[id].nodes:
		if str(n.id) != node_id or not bool(n.get("available",true)): continue
		if str(n.get("stage",n.id)) != str(actor.technique_states[id].node): continue
		if int(n.get("unlock_rank",1)) <= int(actor.technique_states[id].rank):
			return n.duplicate(true)
	return {}

func available_nodes(actor, id: String, timing: String) -> Array:
	var result: Array=[]
	if not actor.technique_states.has(id) or not definitions.has(id): return result
	for entry in definitions[id].nodes:
		if str(entry.timing) != timing: continue
		var n: Dictionary=node(actor,id,str(entry.id))
		if not n.is_empty(): result.append(n)
	return result

func auto_equipped() -> Dictionary:
	var result: Dictionary={}
	for d in definitions.values():
		if bool(d.get("auto_equip",false)): result[str(d.id)]=1
	return result

func arm_from_card(actor, card_id: String, usage_id: String) -> Array:
	var armed: Array=[]
	for id in actor.technique_states:
		var d: Dictionary=definitions.get(id,{})
		var activation: Dictionary=d.get("trigger",{})
		if str(activation.get("card_id",""))!=card_id or str(activation.get("usage_id",""))!=usage_id: continue
		if str(actor.technique_states[id].node) != str(d.entry): continue
		actor.technique_states[id].node=str(activation.get("ready_stage",""))
		actor.technique_states[id].last_used_action=actor.turns_started
		armed.append(str(id))
	return armed

func cost(actor, id: String, stage: String) -> Dictionary:
	var n = node(actor, id, stage)
	if n.is_empty(): return {}
	var c: Dictionary = n.get("cost", {}).duplicate(true)
	if int(actor.technique_states[id].last_used_action) == actor.turns_started and actor.turns_started > 0:
		c["qi"] = float(c.get("qi", 0)) + float(n.get("same_action_extra_qi", 0))
	return c

func advance(actor, id: String, stage: String, interrupted: bool = false) -> void:
	var n: Dictionary = node(actor, id, stage)
	if n.is_empty(): return
	var d: Dictionary = definitions[id]
	var next_id: String = str(n.get("next", d.entry))
	if interrupted and bool(n.get("reset_on_interrupt", true)): next_id = str(d.entry)
	var unlocked: bool = false
	for candidate in d.nodes:
		if candidate.id == next_id and int(candidate.get("unlock_rank", 1)) <= int(actor.technique_states[id].rank):
			unlocked = true
			break
	actor.technique_states[id].node = next_id if unlocked else d.entry
	actor.technique_states[id].last_used_action = actor.turns_started

func on_action_start(actor) -> void:
	for id in actor.technique_states:
		var last: int = int(actor.technique_states[id].last_used_action)
		var hold = definitions[id].get("hold_own_actions", 2)
		if last >= 0 and actor.turns_started - last > hold:
			reset(actor, id)

func reset(actor, id: String) -> bool:
	if not actor.technique_states.has(id): return false
	actor.technique_states[id].node = definitions[id].entry
	actor.technique_states[id].last_used_action = -1
	return true

## Reject invalid graph inputs before any action is enumerated.
func validate_with(cards, conditions) -> bool:
	for d in definitions.values():
		var hold = d.get("hold_own_actions", 2)
		if not (hold is int or hold is float) or not is_finite(float(hold)) or hold < 0 or (hold is float and hold != floor(hold)):
			load_error="Invalid hold duration"
			return false
		var trigger: Dictionary=d.get("trigger",{})
		if not trigger.is_empty():
			var source_def: Dictionary=cards.definitions.get(str(trigger.card_id),{})
			var valid_usage := false
			for u in source_def.get("usages",[]):
				if str(u.id)==str(trigger.usage_id): valid_usage=true
			if not valid_usage:
				load_error="Unknown stage trigger card or usage"
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
				if str(effect.get("type",""))=="cancel_chain_link" and (
					str(node_def.timing) not in ["ATTACK_REACTION","DEFENSE_REACTION"] or
					str(node_def.target.kind)!="opponent_unresolved_response_link"):
					load_error="Invalid cancel response window: "+str(node_def.id)
					return false
	return true
