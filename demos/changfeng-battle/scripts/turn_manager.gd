extends RefCounted
## Event-driven CTB. Real frame time and animation acknowledgements never enter here.
const CHARGE: int = 10000
var state
var cards
var statuses
var visibility
var techniques
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
			state.round_no=1+floori(float(state.action_no-1)/float(maxi(1,state.actors.size())))
			a.normal_moves_used=0
			a.basic_attack_used=false
			a.basic_guard_used=false
			a.pitch_used=false
			a.item_used=false
			a.combo_used.clear()
			a.attack_history.clear()
			a.card_uses.clear()
			if a.turns_started>0:
				for uid in a.hand.duplicate():
					if not cards.retain_on_refresh(a,str(uid)): cards.leave_hand(a,str(uid),false)
				var drawn: Array=cards.draw(a,5)
				resolver.emit("CARDS_DRAWN",{"actor_id":a.id,"count":drawn.size()})
			a.turns_started+=1
			if techniques!=null: techniques.on_action_start(a)
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
		delta=statuses.next_event_delta(delta)
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
	var remaining: int=maxi(0,delta)
	while remaining>0 and state.outcome=="playing":
		var step: int=maxi(1,statuses.next_event_delta(remaining))
		# Check seal at the interval start; expiry at its endpoint still affects this interval.
		for a in state.actors:
			if a.hp_u<=0: continue
			a.gauge+=int(a.stats.charge_speed)*step
			# /200 preserves half-unit rates even for future odd qi_regen values.
			var multiplier: int=1 if statuses.has(a.id,"qi_seal") else 2
			var qi_total: int=int(a.stats.qi_regen_u_per_100)*step*multiplier+a.regen_qi_remainder
			a.qi_u=mini(a.max_qi_u,a.qi_u+qi_total/200)
			a.regen_qi_remainder=0 if a.qi_u==a.max_qi_u else qi_total%200
			var hp_total: int=int(a.stats.hp_regen_u_per_100)*step+a.regen_hp_remainder
			a.hp_u=mini(a.max_hp_u,a.hp_u+hp_total/100)
			a.regen_hp_remainder=0 if a.hp_u==a.max_hp_u else hp_total%100
		state.global_tick+=step
		remaining-=step
		statuses.resolve_time_boundary(resolver)
		resolver.emit("TIME_ADVANCED",{"delta":step,"tick":state.global_tick})
		resolver.check_death()
		resolver.drain_hooks()
		if state.outcome!="playing": resolver.cleanup_terminal()
