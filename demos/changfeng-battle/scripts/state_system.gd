extends RefCounted
## Unified, authoritative state instances for buffs, injuries, stances and techniques.
## All event effects go through CombatResolver; no UI or arbitrary script evaluation.
const MAX_TRANSITIONS: int=32
var state
var cards
var attributes
var extra_definitions: Dictionary={}
var _pending: Array=[]
var _dispatching: bool=false

func _init(battle_state,card_system) -> void:
	state=battle_state
	cards=card_system

func definition(id: String) -> Dictionary:
	return extra_definitions.get(id,cards.statuses.get(id,{}))

func register_definition(id: String,definition_data: Dictionary) -> bool:
	if id.is_empty() or definition(id).size()>0 or not valid_definition(definition_data): return false
	extra_definitions[id]=definition_data.duplicate(true)
	return true

func valid_definition(d: Dictionary) -> bool:
	if not d.get("id") is String or str(d.id).is_empty(): return false
	if d.get("scope","battle") not in ["battle","character","equipment","technique"]: return false
	var expiry: Variant=d.get("expiry",{"kind":"permanent"})
	if not expiry is Dictionary or expiry.get("kind","") not in ["permanent","global_ticks_after_apply","global_ticks","owner_actions","charges","on_event"]: return false
	var mode: String=str(expiry.kind)
	if mode in ["global_ticks_after_apply","global_ticks","owner_actions","charges"] and (not _integer(expiry.get("duration",expiry.get("count",-1))) or int(expiry.get("duration",expiry.get("count",-1)))<1): return false
	if mode=="on_event" and not expiry.get("event") is String: return false
	if not _integer(d.get("stack_limit",1)) or int(d.get("stack_limit",1))<1 or int(d.get("stack_limit",1))>1000: return false
	if d.get("stacking","add") not in ["add","replace","refresh","ignore"]: return false
	if not d.get("modifiers",[]) is Array or not d.get("transitions",[]) is Array: return false
	for item in d.get("modifiers",[]):
		if not item is Dictionary or item.get("op","flat") not in ["flat","percent"]: return false
		if str(item.get("stat","")) not in ["STR","AGI","CON","MND","max_hp","attack","defense","break_power","parry_power","max_qi_u","qi_regen_u_per_100","hp_regen_u_per_100","qi_cost_percent","charge_speed","move_budget"]: return false
		if not _number(item.get("value",0)) or absf(float(item.value))>10000: return false
	for item in d.get("transitions",[]):
		if not item is Dictionary or not item.get("event") is String: return false
		if not item.get("effects",[]) is Array or not item.get("apply",[]) is Array or not item.get("remove",[]) is Array: return false
	var periodic: Variant=d.get("periodic",{})
	if not periodic is Dictionary: return false
	if not periodic.is_empty():
		if not _integer(periodic.get("every_ticks",-1)) or int(periodic.every_ticks)<1: return false
		if not _integer(periodic.get("damage_per_stack",0)) or int(periodic.get("damage_per_stack",0))<0: return false
	return true

func _number(n: Variant) -> bool:
	return (n is int or n is float) and is_finite(float(n))
func _integer(n: Variant) -> bool:
	return _number(n) and float(n)>=0 and float(n)==floor(float(n))

func has(actor_id: int,id: String) -> bool:
	var actor=state.get_actor(actor_id)
	if actor==null or not actor.statuses.has(id): return false
	var entry: Dictionary=actor.statuses[id]
	return not _expired(actor,entry)

func _expired(actor,entry: Dictionary) -> bool:
	if int(entry.get("expiry",-1))>=0 and state.global_tick>=int(entry.expiry): return true
	var limit: int=int(entry.get("expires_at_action",-1))
	if limit>=0 and actor.turns_started>limit: return true
	return int(entry.get("charges",1))==0

func stacks(actor_id: int,id: String) -> int:
	if not has(actor_id,id): return 0
	return int(state.get_actor(actor_id).statuses[id].get("stacks",1))

func add(actor_id: int,id: String,amount: int=1,payload: Dictionary={}) -> bool:
	var actor=state.get_actor(actor_id)
	var d: Dictionary=definition(id)
	if actor==null or not valid_definition(d) or amount<1: return false
	var existing: Dictionary=actor.statuses.get(id,{})
	var active: bool=has(actor_id,id)
	var mode: String=str(d.get("stacking","add"))
	if active and mode=="ignore": return true
	var count: int=amount
	if active and mode in ["add","refresh"]: count=int(existing.get("stacks",1))+(amount if mode=="add" else 0)
	count=mini(count,int(d.get("stack_limit",1)))
	var expire: Dictionary=d.get("expiry",{"kind":"permanent"})
	var kind: String=str(expire.get("kind","permanent"))
	var duration: int=int(expire.get("duration",expire.get("count",0)))
	var time: int=state.global_tick+duration if kind in ["global_ticks_after_apply","global_ticks"] else -1
	var own_limit: int=actor.turns_started+duration if kind=="owner_actions" else -1
	var charges: int=duration if kind=="charges" else -1
	var instance: Dictionary={"stacks":count,"expiry":time,"expires_at_action":own_limit,
		"charges":charges,"applied_at":state.global_tick,"source":payload.get("source",""),
		"scope":d.get("scope","battle")}
	if d.has("periodic"):
		var frequency: int=int(d.periodic.get("every_ticks",0))
		if frequency>0: instance["next_tick"]=state.global_tick+frequency
	if active:
		if existing.has("next_tick"): instance["next_tick"]=existing.next_tick
		if kind=="charges" and mode=="add": instance.charges=int(existing.get("charges",0))+duration
		if mode=="add" and d.get("refresh_on_reapply",true)==false:
			instance.expiry=int(existing.get("expiry",-1))
			instance.expires_at_action=int(existing.get("expires_at_action",-1))
	for key in payload:
		if key not in ["stacks","expiry","expires_at_action","charges"]: instance[key]=payload[key]
	actor.statuses[id]=instance
	_recalculate(actor)
	return true

func remove(actor_id: int,id: String) -> void:
	var actor=state.get_actor(actor_id)
	if actor==null or not actor.statuses.has(id): return
	actor.statuses.erase(id)
	_recalculate(actor)

func _recalculate(actor) -> void:
	if attributes!=null: attributes.recalculate(actor,self)

func conditional_bonus(actor_id: int,target_id: int,c: Dictionary) -> int:
	var actor=state.get_actor(actor_id)
	if actor==null: return 0
	if c.has("if_self_shield_gt") and actor.shield<=float(c.if_self_shield_gt): return 0
	if c.has("if_target_status") and not has(target_id,str(c.if_target_status)): return 0
	if c.has("if_self_hp_pct_lt_after_cost") and (actor.max_hp_u<=0 or actor.hp/actor.max_hp>=float(c.if_self_hp_pct_lt_after_cost)): return 0
	if c.has("bonus_per_target_status"): return stacks(target_id,str(c.bonus_per_target_status))*int(c.get("bonus_each",0))
	return int(c.get("bonus",0))

func next_event_delta(max_delta: int) -> int:
	var delta: int=max_delta
	for actor in state.actors:
		if actor.hp_u<=0: continue
		for id in actor.statuses:
			var entry: Dictionary=actor.statuses[id]
			var deadline: int=int(entry.get("expiry",-1))
			if deadline>state.global_tick: delta=mini(delta,deadline-state.global_tick)
			var due: int=int(entry.get("next_tick",-1))
			if due>state.global_tick and (deadline<0 or due<=deadline): delta=mini(delta,due-state.global_tick)
		if actor.shield_expiry>state.global_tick: delta=mini(delta,actor.shield_expiry-state.global_tick)
	return delta

func on_owner_action(actor_id: int,resolver=null) -> void:
	var actor=state.get_actor(actor_id)
	if actor==null: return
	var ids: Array=actor.statuses.keys()
	ids.sort()
	for id in ids:
		var entry: Dictionary=actor.statuses[id]
		if int(entry.get("expires_at_action",-1))>=0 and _expired(actor,entry):
			remove(actor.id,str(id))
			if resolver!=null: resolver.emit("STATUS_EXPIRED",{"actor_id":actor.id,"status_id":str(id)})

func resolve_time_boundary(resolver) -> void:
	# Order is (actor id, state id). Resolve every periodic hit before death checking.
	var actors: Array=state.actors.duplicate()
	actors.sort_custom(func(a,b): return a.id<b.id)
	for actor in actors:
		if actor.hp_u<=0: continue
		var ids: Array=actor.statuses.keys()
		ids.sort()
		for id in ids:
			if not actor.statuses.has(id): continue
			var instance: Dictionary=actor.statuses[id]
			var d: Dictionary=definition(str(id))
			var periodic: Dictionary=d.get("periodic",{})
			var due: int=int(instance.get("next_tick",-1))
			var expires: int=int(instance.get("expiry",-1))
			if periodic.size()>0 and due>=0 and due<=state.global_tick and (expires<0 or due<=expires):
				var count: int=int(instance.get("stacks",1))
				var damage: int=count*int(periodic.get("damage_per_stack",0))
				if damage>0: resolver.deal_status_damage(actor.id,damage,str(id))
				if bool(periodic.get("decay_stack",false)):
					if count<=1:
						remove(actor.id,str(id))
						resolver.emit("STATUS_REMOVED",{"actor_id":actor.id,"status_id":str(id)})
						continue
					instance.stacks=count-1
				instance.next_tick=due+int(periodic.get("every_ticks",100))
	for actor in actors:
		var ids: Array=actor.statuses.keys()
		ids.sort()
		for id in ids:
			if not has(actor.id,str(id)):
				remove(actor.id,str(id))
				resolver.emit("STATUS_EXPIRED",{"actor_id":actor.id,"status_id":str(id)})
		if actor.shield_expiry>=0 and state.global_tick>=actor.shield_expiry:
			actor.shield_u=0
			actor.shield_expiry=-1
			resolver.emit("SHIELD_EXPIRED",{"actor_id":actor.id})

func on_event(event: Dictionary,resolver) -> void:
	_pending.append(event.duplicate(true))
	if _dispatching: return
	_dispatching=true
	var budget: int=MAX_TRANSITIONS
	while not _pending.is_empty() and budget>0:
		var next_event: Dictionary=_pending.pop_front()
		var actors: Array=state.actors.duplicate()
		actors.sort_custom(func(a,b): return a.id<b.id)
		for actor in actors:
			var ids: Array=actor.statuses.keys()
			ids.sort()
			for id in ids:
				if not has(actor.id,str(id)): continue
				var d: Dictionary=definition(str(id))
				var expiry: Dictionary=d.get("expiry",{})
				if expiry.get("kind","")=="on_event" and expiry.get("event","")==next_event.get("type","") and int(next_event.get("actor_id",-1))==actor.id:
					remove(actor.id,str(id))
					continue
				for transition in d.get("transitions",[]):
					if transition.get("event","")!=next_event.get("type",""): continue
					if transition.get("subject","owner")=="owner" and int(next_event.get("actor_id",-1))!=actor.id: continue
					var require: Dictionary=transition.get("when",{})
					if resolver.rules.conditions!=null and not resolver.rules.conditions.allows(actor,require,{"event":next_event,"timing":str(next_event.get("type",""))}): continue
					budget-=1
					if budget<0: break
					for remove_id in transition.get("remove",[]): remove(actor.id,str(remove_id))
					for apply_id in transition.get("apply",[]): add(actor.id,str(apply_id))
					if not transition.get("effects",[]).is_empty():
						resolver.apply_effects(actor.id,transition.effects,{},true)
					if bool(transition.get("consume_charge",false)) and actor.statuses.has(id):
						actor.statuses[id].charges=int(actor.statuses[id].get("charges",-1))-1
						if _expired(actor,actor.statuses[id]): remove(actor.id,str(id))
					if budget<=0: break
			if budget<=0: break
	_pending.clear()
	_dispatching=false
	if budget<=0: resolver.diagnostic("STATE_TRANSITION_LIMIT","State transition limit reached")
