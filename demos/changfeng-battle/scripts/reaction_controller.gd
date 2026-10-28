extends RefCounted
## Bounded priority protocol; the root attack is not a response link.
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
	state.next_link+=1
	var link: Dictionary={"id":state.next_link,"link_id":state.next_link,"actor_id":actor_id,"uid":uid,"definition_id":definition_id,"usage_id":u.id,"name":u.get("name",definition_id),"effects":u.get("effects",[]).duplicate(true),"choice":choice.duplicate(true),"canceled":false,"resolved":false}
	state.clash.stack.append(link)
	state.clash.counts[actor_id]=int(state.clash.counts.get(actor_id,0))+1
	state.clash.priority_actor_id=other(actor_id)
	state.clash.consecutive_passes=0
	resolver.emit("CHAIN_LINK_ADDED",{"actor_id":actor_id,"link_id":link.id,"definition_id":definition_id,"usage_id":u.id,"text":"L%d · %s" % [link.id,link.name]})
	if state.clash.stack.size()>=4: resolver.resolve_clash()
	else: update_window()

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
