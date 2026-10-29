extends RefCounted
var state
var cards

func _refresh_hp_limit(actor) -> void:
	# Status-driven cap modifiers apply equally to player-controlled and AI units.
	var base_u: int=int(actor.stats.get("max_hp",20))*10000
	var penalty_u: int=0
	for status_id in actor.statuses:
		if not cards.statuses.has(status_id): continue
		var entry: Dictionary=actor.statuses[status_id]
		var stacks_count: int=int(entry.get("stacks",1))
		penalty_u+=maxi(0,int(cards.statuses[status_id].get("max_hp_penalty_per_stack",0)))*maxi(0,stacks_count)*10000
	actor.max_hp_u=maxi(10000,base_u-penalty_u)
	actor.hp_u=mini(actor.hp_u,actor.max_hp_u)

func _init(s,c) -> void:
	state=s
	cards=c

func has(actor_id: int, id: String) -> bool:
	var a=state.get_actor(actor_id)
	if a==null or not a.statuses.has(id): return false
	var entry=a.statuses[id]
	var expiry: int=int(entry.get("expiry",-1)) if entry is Dictionary else int(entry)
	return expiry<0 or state.global_tick<expiry

func stacks(actor_id: int, id: String) -> int:
	if not has(actor_id,id): return 0
	var entry=state.get_actor(actor_id).statuses[id]
	return int(entry.get("stacks",1)) if entry is Dictionary else 1

func add(actor_id: int, id: String, amount: int = 1) -> bool:
	if not cards.statuses.has(id): return false
	var actor=state.get_actor(actor_id)
	var d: Dictionary=cards.statuses[id]
	var duration: int=int(d.get("expiry",{}).get("duration",150))
	var expiry: int=-1 if duration<0 else state.global_tick+duration
	var next_tick: int=state.global_tick+100
	if id=="scorch" and has(actor_id,id): next_tick=int(actor.statuses[id].get("next_tick",next_tick))
	actor.statuses[id]={"expiry":expiry,"stacks":mini(int(d.get("stack_limit",1)),stacks(actor_id,id)+amount)}
	if id=="scorch": actor.statuses[id]["next_tick"]=next_tick
	_refresh_hp_limit(actor)
	return true

func remove(actor_id: int,id: String) -> void:
	var actor=state.get_actor(actor_id)
	if actor==null: return
	actor.statuses.erase(id)
	_refresh_hp_limit(actor)

func conditional_bonus(actor_id: int,target_id: int,c: Dictionary) -> int:
	var a=state.get_actor(actor_id)
	if c.has("if_self_shield_gt") and a.shield<=float(c.if_self_shield_gt): return 0
	if c.has("if_target_status") and not has(target_id,str(c.if_target_status)): return 0
	if c.has("if_self_hp_pct_lt_after_cost") and a.hp/a.max_hp>=float(c.if_self_hp_pct_lt_after_cost): return 0
	if c.has("bonus_per_target_status"): return stacks(target_id,str(c.bonus_per_target_status))*int(c.get("bonus_each",0))
	return int(c.get("bonus",0))

func next_event_delta(max_delta: int) -> int:
	var delta: int=max_delta
	for actor in state.actors:
		if actor.hp_u<=0: continue
		for id in actor.statuses:
			var entry=actor.statuses[id]
			var expiry: int=int(entry.get("expiry",-1)) if entry is Dictionary else int(entry)
			if expiry>state.global_tick: delta=mini(delta,expiry-state.global_tick)
			if id=="scorch" and entry is Dictionary:
				var due: int=int(entry.get("next_tick",-1))
				if due>state.global_tick and (expiry<0 or due<=expiry): delta=mini(delta,due-state.global_tick)
		if actor.shield_expiry>state.global_tick: delta=mini(delta,actor.shield_expiry-state.global_tick)
	return delta

func resolve_time_boundary(resolver) -> void:
	# All actors receive periodic damage before death or event-trigger effects are checked.
	for actor in state.actors:
		if actor.hp_u<=0 or not actor.statuses.has("scorch"): continue
		var entry: Dictionary=actor.statuses.scorch
		var due: int=int(entry.get("next_tick",-1))
		var expiry: int=int(entry.get("expiry",-1))
		if due<0 or due>state.global_tick or (expiry>=0 and due>expiry): continue
		var count: int=int(entry.get("stacks",0))
		if count>0:
			resolver.deal_status_damage(actor.id,count,"scorch")
			if count>1:
				entry.stacks=count-1
				entry.next_tick=due+100
			else:
				remove(actor.id,"scorch")
				resolver.emit("STATUS_REMOVED",{"actor_id":actor.id,"status_id":"scorch"})
	for actor in state.actors:
		for id in actor.statuses.keys():
			if has(actor.id,str(id)): continue
			remove(actor.id,str(id))
			resolver.emit("STATUS_EXPIRED",{"actor_id":actor.id,"status_id":id})
		if actor.shield_expiry>=0 and state.global_tick>=actor.shield_expiry:
			actor.shield_u=0
			actor.shield_expiry=-1
			resolver.emit("SHIELD_EXPIRED",{"actor_id":actor.id})
