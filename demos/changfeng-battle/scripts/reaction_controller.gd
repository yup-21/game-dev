extends RefCounted
## Bounded priority protocol; the root attack is not a response link.
const Facing=preload("res://scripts/actor_facing.gd")
var state
var _resolver_ref: WeakRef
var resolver:
	get: return _resolver_ref.get_ref() if _resolver_ref!=null else null
	set(value): _resolver_ref=weakref(value)
func _init(s) -> void:
	state=s

func declare(attack: Dictionary) -> void:
	state.attack=attack
	state.clash={"attack":state.attack,"stack":[],"priority_actor_id":int(attack.defender_id),"consecutive_passes":0,"counts":{int(attack.attacker_id):0,int(attack.defender_id):0}}
	state.mode="CLASH"
	state.phase="CLASH"
	update_window()

func other(actor_id: int) -> int:
	return int(state.attack.defender_id) if actor_id==int(state.attack.attacker_id) else int(state.attack.attacker_id)

func add(actor_id: int,uid: String,definition_id: String,u: Dictionary,choice: Dictionary) -> void:
	# Counter/counter-guard faces the opposing duelist even if a response
	# applies to the attack stack rather than explicitly naming a target.
	var responder=state.get_actor(actor_id)
	var opponent=state.get_actor(other(actor_id))
	if responder!=null and opponent!=null:
		if state.spatial_mode=="FREE" and state.spatial!=null:
			var offset: Vector2=opponent.position-responder.position
			responder.facing=Facing.from_delta(Vector2i(roundi(offset.x),roundi(offset.y)),responder.facing)
		else:
			responder.facing=Facing.from_delta(opponent.cell-responder.cell,responder.facing)
	state.next_link+=1
	var link: Dictionary={"id":state.next_link,"link_id":state.next_link,"actor_id":actor_id,"uid":uid,"definition_id":definition_id,"usage_id":u.id,"name":u.get("name",definition_id),"effects":u.get("effects",[]).duplicate(true),"choice":choice.duplicate(true),"canceled":false,"resolved":false}
	state.clash.stack.append(link)
	state.clash.counts[actor_id]=int(state.clash.counts.get(actor_id,0))+1
	state.clash.priority_actor_id=other(actor_id)
	state.clash.consecutive_passes=0
	resolver.emit("CHAIN_LINK_ADDED",{"actor_id":actor_id,"link_id":link.id,"definition_id":definition_id,"usage_id":u.id,"facing":responder.facing,"text":"L%d · %s" % [link.id,link.name]})
	if state.clash.stack.size()>=4: resolver.resolve_clash()
	else: update_window()

## A cancel may only affect an opposing unresolved response link. The
## root attack is not a stack member. Querying this never writes state.
func can_cancel_link(actor_id: int, link_id: int) -> bool:
	if state.mode!="CLASH" or state.clash.is_empty(): return false
	if actor_id not in [int(state.attack.attacker_id),int(state.attack.defender_id)]: return false
	for link in state.clash.get("stack",[]):
		if int(link.id)==link_id:
			return int(link.actor_id)!=actor_id and not bool(link.canceled) and not bool(link.resolved)
	return false

## Called only while resolving the validated LIFO stack. External attempts
## to cancel a link before paying for an accepted response do nothing.
func cancel_link(actor_id: int, link_id: int) -> bool:
	if not state.resolving_clash or not can_cancel_link(actor_id,link_id): return false
	for link in state.clash.stack:
		if int(link.id)==link_id:
			link.canceled=true
			return true
	return false

func pass_response(actor_id: int) -> void:
	state.clash.consecutive_passes+=1
	resolver.emit("PRIORITY_PASSED",{"actor_id":actor_id,"text":"%s 不追加应变" % state.get_actor(actor_id).name})
	if state.clash.consecutive_passes>=2: resolver.resolve_clash()
	else:
		state.clash.priority_actor_id=other(actor_id)
		update_window()

func update_window() -> void:
	state.reaction_window="ATTACK" if int(state.clash.priority_actor_id)==int(state.attack.attacker_id) else "DEFENSE"

func clear() -> void:
	state.clash.clear()
	state.attack={}
	state.reaction_window="NONE"
	if state.outcome=="playing":
		state.mode="ACTION"
		state.phase="ACTION"
