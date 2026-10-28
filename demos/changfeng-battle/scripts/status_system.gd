extends RefCounted
var state
var cards
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
	var expiry: int=state.global_tick+int(d.get("expiry",{}).get("duration",150))
	actor.statuses[id]={"expiry":expiry,"stacks":mini(int(d.get("stack_limit",1)),stacks(actor_id,id)+amount)}
	return true

func remove(actor_id: int,id: String) -> void:
	state.get_actor(actor_id).statuses.erase(id)

func conditional_bonus(actor_id: int,target_id: int,c: Dictionary) -> int:
	var a=state.get_actor(actor_id)
	if c.has("if_self_shield_gt") and a.shield<=float(c.if_self_shield_gt): return 0
	if c.has("if_target_status") and not has(target_id,str(c.if_target_status)): return 0
	if c.has("if_self_hp_pct_lt_after_cost") and a.hp/a.max_hp>=float(c.if_self_hp_pct_lt_after_cost): return 0
	if c.has("bonus_per_target_status"): return stacks(target_id,str(c.bonus_per_target_status))*int(c.get("bonus_each",0))
	return int(c.get("bonus",0))
