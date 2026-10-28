extends RefCounted
## Event-driven CTB. Real frame time and animation acknowledgements never enter here.
const CHARGE: int = 10000
var state
var cards
var statuses
var visibility
var _resolver_ref: WeakRef
var resolver:
	get: return _resolver_ref.get_ref() if _resolver_ref!=null else null
	set(value): _resolver_ref=weakref(value)

func _init(s,c,status_system,visibility_system) -> void:
	state=s
	cards=c
	statuses=status_system
	visibility=visibility_system

func end_action() -> void:
	resolver.emit("ACTION_ENDED",{"actor_id":state.active_id,"text":"%s 收势" % state.get_actor(state.active_id).name})
	resolver.drain_hooks()
	if state.outcome!="playing": return
	state.get_actor(state.active_id).gauge-=CHARGE
	state.active_id=-1
	state.mode="TIMELINE"
	state.phase="TIMELINE"
	begin_next_action()

func begin_next_action() -> void:
	if state.outcome!="playing": return
	for _safety in range(1024):
		var ready: Array=[]
		for a in state.actors:
			if a.hp_u>0 and a.gauge>=CHARGE: ready.append(a)
		if not ready.is_empty():
			ready.sort_custom(func(a,b):
				if a.gauge!=b.gauge: return a.gauge>b.gauge
				if int(a.stats.charge_speed)!=int(b.stats.charge_speed): return int(a.stats.charge_speed)>int(b.stats.charge_speed)
				if state.action_no==0: return a.id==state.preferred_first
				if a.id==state.last_ready: return false
				if b.id==state.last_ready: return true
				return a.id<b.id)
			var a=ready[0]
			state.active_id=a.id
			state.last_ready=a.id
			state.mode="ACTION"
			state.phase="ACTION"
			state.action_no+=1
			state.round_no=1+floori(float(state.action_no-1)/2)
			a.normal_moves_used=0
			a.basic_attack_used=false
			a.basic_guard_used=false
			a.pitch_used=false
			a.combo_used.clear()
			a.attack_history.clear()
			a.card_uses.clear()
			if a.turns_started>0:
				for uid in a.hand.duplicate(): cards.leave_hand(a,str(uid),false)
				var drawn: Array=cards.draw(a,5)
				resolver.emit("CARDS_DRAWN",{"actor_id":a.id,"count":drawn.size()})
			a.turns_started+=1
			visibility.refresh_intel(a.id,true)
			state.phase_history.append({"phase":"ACTION","actor_id":a.id,"tick":state.global_tick,"revision":state.revision})
			resolver.emit("ACTION_STARTED",{"actor_id":a.id,"action_no":state.action_no,"text":"%s 行动 · t=%d" % [a.name,state.global_tick]})
			resolver.drain_hooks()
			return
		var delta: int=2147483647
		for a in state.actors:
			if a.hp_u<=0: continue
			var speed: int=int(a.stats.charge_speed)
			delta=mini(delta,ceili(float(CHARGE-a.gauge)/speed))
			for entry in a.statuses.values():
				var expiry: int=int(entry.get("expiry",-1)) if entry is Dictionary else int(entry)
				if expiry>state.global_tick: delta=mini(delta,expiry-state.global_tick)
			if a.shield_expiry>state.global_tick: delta=mini(delta,a.shield_expiry-state.global_tick)
		if delta==2147483647: return
		advance_time(maxi(1,delta))
		if state.outcome!="playing": return
	resolver.emit("RULE_ERROR",{"text":"集气调度异常，停止推进"})
	state.mode="FINISHED"
	state.phase="FINISHED"
	state.outcome="defeat"

@warning_ignore("integer_division")
func advance_time(delta: int) -> void:
	assert(state.mode=="TIMELINE")
	state.global_tick+=delta
	for a in state.actors:
		if a.hp_u<=0: continue
		a.gauge+=int(a.stats.charge_speed)*delta
		var qi_total: int=int(a.stats.qi_regen_u_per_100)*delta+a.regen_qi_remainder
		a.qi_u=mini(a.max_qi_u,a.qi_u+qi_total/100)
		a.regen_qi_remainder=qi_total%100
		var hp_total: int=int(a.stats.hp_regen_u_per_100)*delta+a.regen_hp_remainder
		a.hp_u=mini(a.max_hp_u,a.hp_u+hp_total/100)
		a.regen_hp_remainder=hp_total%100
		for id in a.statuses.keys():
			if not statuses.has(a.id,str(id)):
				a.statuses.erase(id)
				resolver.emit("STATUS_EXPIRED",{"actor_id":a.id,"status_id":id})
		if a.shield_expiry>=0 and state.global_tick>=a.shield_expiry:
			a.shield_u=0
			a.shield_expiry=-1
			resolver.emit("SHIELD_EXPIRED",{"actor_id":a.id})
	resolver.emit("TIME_ADVANCED",{"delta":delta,"tick":state.global_tick})
	resolver.drain_hooks()
