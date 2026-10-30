extends RefCounted
## The only effect executor. No scene tree, awaits, animations, or policy decisions.
const UNIT: int=10000
const MAX_EFFECTS: int=32
const Facing = preload("res://scripts/actor_facing.gd")
var state
var cards
var costs
var rules
var hooks
var combos
var statuses
var visibility
var audit
var turns
var reactions
var techniques

func _init(s,c,cost_system,validator,registry,combo_system,status_system,visibility_system,event_log) -> void:
	state=s
	cards=c
	costs=cost_system
	rules=validator
	hooks=registry
	combos=combo_system
	statuses=status_system
	visibility=visibility_system
	audit=event_log

func emit(kind: String,data: Dictionary = {}) -> void:
	var event: Dictionary=audit.emit(kind,data)
	if state.outcome!="playing": return
	var actor_id: int=int(event.get("actor_id",-1))
	if state.get_actor(actor_id)!=null:
		state.hook_queue.append_array(hooks.collect(event,rules.context(actor_id)))
	else:
		# Global semantic events (such as elapsed time) notify each registered owner.
		# Keep one authoritative log record; owner-scoped copies are only hook contexts.
		for actor in state.actors:
			var notification: Dictionary=event.duplicate(true)
			notification.actor_id=actor.id
			state.hook_queue.append_array(hooks.collect(notification,rules.context(actor.id)))

func diagnostic(kind: String,text: String) -> void:
	audit.emit(kind,{"text":text})

func drain_hooks() -> void:
	if state.processing_hooks: return
	state.processing_hooks=true
	while not state.hook_queue.is_empty() and state.outcome=="playing":
		var command: Dictionary=state.hook_queue.pop_front()
		var key: String="%s:%s:%s" % [state.root_action_id,command.source,command.hook_id]
		if command.options.get("once_per_turn",false): key="turn:%d:%d:%s" % [int(command.source),state.get_actor(int(command.source)).turns_started,command.hook_id]
		elif not command.options.get("once_per_root_action",true): key+="/"+str(command.event_id)
		if state.hook_usage.has(key):
			diagnostic("HOOK_REJECTED","重复触发已抑制："+str(command.hook_id))
			continue
		state.hook_usage[key]=true
		var valid: bool=true
		for effect in command.effects:
			if not cards.valid_effect(effect): valid=false
		if not valid:
			diagnostic("HOOK_REJECTED","无效效果已拒绝："+str(command.hook_id))
			continue
		for effect in command.effects:
			if state.root_effect_count>=MAX_EFFECTS:
				diagnostic("HOOK_LIMIT_REACHED","本次行动衍生效果达到32条，剩余效果已中止")
				state.hook_queue.clear()
				break
			apply_effects(int(command.source),[effect],{},true)
			if state.outcome!="playing": break
	state.processing_hooks=false
	if state.outcome!="playing": state.hook_queue.clear()

func apply(action: Dictionary,plan: Dictionary) -> void:
	var actor=state.get_actor(int(action.actor_id))
	costs.pay(actor,plan)
	if int(plan.qi_u)>0: emit("QI_SPENT",{"actor_id":actor.id,"amount":float(plan.qi_u)/UNIT})
	if int(plan.hp_u)>0: emit("HP_COST",{"actor_id":actor.id,"amount":float(plan.hp_u)/UNIT,"damage_kind":"cost"})
	match str(action.kind):
		"END_ACTION": turns.end_action()
		"SWITCH_SCHOOL":
			var previous: String=str(actor.school_id)
			if cards.equip_school(actor,str(action.school_id)):
				for id in actor.technique_states:
					if techniques!=null: techniques.reset(actor,str(id))
				visibility.refresh_intel(actor.id,true)
				emit("SCHOOL_SWITCHED",{"actor_id":actor.id,"from_school":previous,"school_id":actor.school_id,"text":"%s 换用 %s" % [actor.name,actor.school_name]})
				turns.end_action()
		"MOVE":
			var path: Array=state.find_path(actor.cell,action.target_cell,actor.id)
			actor.normal_moves_used+=path.size()
			move_actor(actor.id,action.target_cell,path)
		"BASIC_ATTACK":
			actor.basic_attack_used=true
			declare_attack(actor.id,"","basic","basic",int(action.target_id),1,"thrust",0,[])
		"BASIC_GUARD":
			actor.basic_guard_used=true
			add_shield(actor.id,1,100)
		"PITCH_CARD":
			cards.leave_hand(actor,str(action.card_uid),false)
			actor.pitch_used=true
			gain_qi(actor.id,1)
			emit("CARD_DISCARDED",{"actor_id":actor.id,"definition_id":cards.instance(str(action.card_uid)).definition_id,"text":"%s 弃牌调息" % actor.name})
		"PLAY_CARD": play_card(actor,action)
		"USE_ABILITY": play_ability(actor,action)
		"RESET_TECHNIQUE":
			if techniques.reset(actor,str(action.technique_id)):
				emit("TECHNIQUE_RESET",{"actor_id":actor.id,"technique_id":action.technique_id})
		"PASS_REACTION": reactions.pass_response(actor.id)
	drain_hooks()
	check_death()
	if state.outcome!="playing": cleanup_terminal()

func cleanup_terminal() -> void:
	# Run after active resolver frames return, so local attack/link references stay valid.
	for actor in state.actors:
		for uid in actor.resolving.duplicate(): finish_card(actor.id,str(uid))
	state.hook_queue.clear()
	state.effect_queue.clear()
	reactions.clear()
	state.mode="FINISHED"
	state.phase="FINISHED"

func play_card(actor,choice: Dictionary) -> void:
	var uid: String=str(choice.card_uid)
	var d: Dictionary=cards.canonical_definition(uid)
	var u: Dictionary=cards.usage(uid,str(choice.usage_id))
	if u.get("once_per_action",false): actor.card_uses[str(d.id)+":"+str(u.id)]=int(actor.card_uses.get(str(d.id)+":"+str(u.id),0))+1
	cards.leave_hand(actor,uid)
	emit("CARD_PLAYED",{"actor_id":actor.id,"definition_id":d.id,"usage_id":u.id,"text":"%s · %s" % [actor.name,u.get("name",d.name)]})
	if state.mode=="CLASH":
		reactions.add(actor.id,uid,str(d.id),u,choice)
		return
	var damage: int=-1
	for e in u.get("effects",[]):
		if e.type=="deal_damage": damage=int(e.amount)
	if damage>=0:
		var profile: Dictionary=u.get("attack_profile",{})
		declare_attack(actor.id,uid,str(d.id),str(u.id),int(choice.target_id),damage,str(profile.get("route","thrust")),int(profile.get("break_bonus",0)),u.get("effects",[]))
	else:
		apply_effects(actor.id,u.get("effects",[]),choice)
		finish_card(actor.id,uid)

func play_ability(actor,choice: Dictionary) -> void:
	var id: String=str(choice.technique_id)
	var stage: String=str(choice.node_id)
	var u: Dictionary=techniques.node(actor,id,stage)
	if u.is_empty(): return
	emit("ABILITY_USED",{"actor_id":actor.id,"technique_id":id,"node_id":stage})
	if state.mode=="CLASH":
		techniques.advance(actor,id,stage)
		reactions.add(actor.id,"",id,u,choice)
		return
	var damage: int=-1
	for effect in u.effects:
		if effect.type=="deal_damage": damage=int(effect.amount)
	if damage>=0:
		var profile: Dictionary=u.get("attack_profile",{})
		declare_attack(actor.id,"",id,stage,int(choice.target_id),damage,str(profile.get("route","thrust")),int(profile.get("break_bonus",0)),u.effects,id,stage)
	else:
		apply_effects(actor.id,u.effects,choice)
		techniques.advance(actor,id,stage)

func declare_attack(actor_id: int,uid: String,definition_id: String,usage_id: String,target_id: int,damage: int,route: String,break_bonus: int,effects: Array,technique_id: String="",node_id: String="") -> void:
	var actor=state.get_actor(actor_id)
	var target=state.get_actor(target_id)
	# Attacks (basic, martial cards and staged abilities) all turn toward
	# their selected target before opening the LIFO response window.
	actor.facing=Facing.from_delta(target.cell-actor.cell,actor.facing)
	var attack: Dictionary={"attack_id":state.root_action_id,"attacker_id":actor_id,"defender_id":target_id,
		"card_uid":uid,"definition_id":definition_id,"usage_id":usage_id,"route":route,"break_bonus":break_bonus,
		"origin_cell":actor.cell,"target_cell":target.cell,"affected_cells":[target.cell],
		"base_damage":damage,"attack_bonus":0,"defense_reduction":0,"effects":effects.duplicate(true),"interrupted":false,"combo":{},"paid":true,"technique_id":technique_id,"node_id":node_id}
	var focus: int=statuses.stacks(actor_id,"focus")
	if focus>0:
		attack.attack_bonus+=focus
		statuses.remove(actor_id,"focus")
		emit("FOCUS_CONSUMED",{"actor_id":actor_id,"amount":focus,"text":"%s 凝势 +%d" % [actor.name,focus]})
	var combo: Dictionary=combos.declaration(actor,definition_id,usage_id)
	if not combo.is_empty():
		attack.combo=combo
		for e in combo.get("effects",[]):
			if e.type=="modify_pending_damage": attack.attack_bonus+=int(e.get("flat_delta",0))
	# Stage progression is independent of generated cards: a prerequisite
	# attack arms the optional 变锋 branch without adding any token to hand.
	if techniques!=null and not uid.is_empty():
		for armed_id in techniques.arm_from_card(actor,definition_id,usage_id):
			emit("TECHNIQUE_ARMED",{"actor_id":actor_id,"technique_id":armed_id,"text":"变锋 · 势已成"})
	reactions.declare(attack)
	emit("ATTACK_DECLARED",{"actor_id":actor_id,"target_id":target_id,"facing":actor.facing,"definition_id":definition_id,"usage_id":usage_id,"text":"%s 向 %s 出招" % [actor.name,target.name]})
	# Root attack effects are usually deferred until hit/miss resolution.
	# A grant_card at the root is different: create the derivative NOW, before
	# the defender/attacker alternate response priority, so 变锋 can actually
	# respond to the same clash. No other attack effects execute prematurely.
	for effect in effects:
		if str(effect.get("type", "")) == "grant_card":
			apply_effects(actor_id, [effect], {"card_uid":uid})

func resolve_clash() -> void:
	if state.resolving_clash: return
	state.resolving_clash=true
	var stack: Array=state.clash.stack
	for index in range(stack.size()-1,-1,-1):
		var link: Dictionary=stack[index]
		if state.outcome!="playing": break
		if link.canceled:
			emit("CHAIN_LINK_SKIPPED",{"actor_id":link.actor_id,"link_id":link.id})
			continue
		apply_effects(int(link.actor_id),link.effects,link.choice)
		link.resolved=true
		emit("CHAIN_LINK_RESOLVED",{"actor_id":link.actor_id,"link_id":link.id,"text":"L%d 结算 · %s" % [link.id,link.name]})
		drain_hooks()
	if state.outcome=="playing": resolve_attack()
	if techniques!=null and not str(state.attack.get("technique_id","")).is_empty():
		techniques.advance(state.get_actor(int(state.attack.attacker_id)),str(state.attack.technique_id),str(state.attack.node_id),bool(state.attack.interrupted))
	for link in stack: finish_card(int(link.actor_id),str(link.uid))
	if not str(state.attack.get("card_uid","")).is_empty(): finish_card(int(state.attack.attacker_id),str(state.attack.card_uid))
	var source: int=int(state.attack.get("attacker_id",-1))
	var target: int=int(state.attack.get("defender_id",-1))
	emit("ATTACK_FINISHED",{"actor_id":source,"target_id":target})
	reactions.clear()
	state.resolving_clash=false
	drain_hooks()

func record_attack(hit: bool,interrupted: bool = false) -> void:
	var attack: Dictionary=state.attack
	var actor=state.get_actor(int(attack.attacker_id))
	# Basic attacks and response cards never enter the active-card combo sequence.
	if str(attack.card_uid).is_empty(): return
	actor.attack_history.append({"card_uid":attack.card_uid,"definition_id":attack.definition_id,"usage_id":attack.usage_id,
		"tags":cards.canonical_definition(str(attack.card_uid)).get("tags",[]),"turn_id":state.action_no,
		"action_id":attack.attack_id,"resolved":true,"hit":hit,"interrupted":interrupted})
	if not attack.combo.is_empty() and not interrupted:
		actor.combo_used.append(attack.combo.id)
		emit("COMBO_TRIGGERED",{"actor_id":actor.id,"combo_id":attack.combo.id,"name":attack.combo.name,"text":"连携 · "+str(attack.combo.name)})

func resolve_attack() -> void:
	var a: Dictionary=state.attack
	var source=state.get_actor(int(a.attacker_id))
	var target=state.get_actor(int(a.defender_id))
	if a.interrupted:
		emit("ATTACK_INTERRUPTED",{"actor_id":source.id,"text":"招式被迎锋中断"})
		record_attack(false,true)
		return
	if not a.affected_cells.has(target.cell):
		emit("ATTACK_MISSED",{"actor_id":source.id,"target_id":target.id,"text":"落空 · 对手离开攻击范围"})
		apply_attack_effects("on_attack_miss",source.id)
		record_attack(false)
		return
	var combo: Dictionary=combos.qualified_hit(source,a)
	if not combo.is_empty():
		apply_effects(source.id,combo.get("effects",[]),{})
		source.combo_used.append(combo.id)
		emit("COMBO_TRIGGERED",{"actor_id":source.id,"combo_id":combo.id,"name":combo.name,"text":"连携 · "+str(combo.name)})
	var diff: int=int(source.stats.attack)-int(target.stats.defense)
	var raw: int=int(a.base_damage)+int(a.attack_bonus)+clampi(int(float(diff)/8),-2,2)
	for effect in a.effects:
		if effect.type=="deal_damage" and effect.has("conditional_bonus"):
			var condition: Dictionary=effect.conditional_bonus
			var bonus: int=statuses.conditional_bonus(source.id,target.id,condition)
			raw+=bonus
			if bonus!=0 and not str(condition.get("consume_on_hit","")).is_empty():
				var consumed: String=str(condition.consume_on_hit)
				statuses.remove(target.id,"scorch" if consumed=="scorch_all" else consumed)
	var modified: Dictionary=hooks.modify(rules.context(source.id),{"damage":raw},"BEFORE_DAMAGE")
	if modified.valid: raw=int(modified.damage)
	var reduced: int=mini(maxi(0,raw),int(a.defense_reduction))
	if reduced>0: emit("DAMAGE_REDUCED",{"actor_id":target.id,"amount":reduced,"target_id":source.id})
	var damage: int=maxi(0,raw-int(a.defense_reduction))
	emit("ATTACK_HIT",{"actor_id":source.id,"target_id":target.id,"definition_id":a.definition_id})
	deal_damage(source.id,target.id,damage)
	if state.outcome=="playing":
		apply_attack_effects("on_attack_hit",source.id)
		for e in a.effects:
			if e.type=="deal_damage": apply_effects(source.id,e.get("on_hit",[]),{})
	record_attack(true)
	drain_hooks()

func deal_damage(source_id: int,target_id: int,amount: float) -> void:
	var target=state.get_actor(target_id)
	var raw_u: int=maxi(0,roundi(amount*UNIT))
	var absorbed: int=mini(raw_u,target.shield_u)
	target.shield_u-=absorbed
	var lost: int=mini(target.hp_u,raw_u-absorbed)
	target.hp_u-=lost
	emit("DAMAGE",{"actor_id":source_id,"defender_id":target_id,"hp_damage":float(lost)/UNIT,"absorbed":float(absorbed)/UNIT,"damage":amount,"text":"%s 受伤 %s · 护体吸收 %s" % [target.name,str(float(lost)/UNIT),str(float(absorbed)/UNIT)]})
	if lost>0: emit("HP_DAMAGED",{"actor_id":target_id,"source_actor_id":source_id,"amount":float(lost)/UNIT,"damage_kind":"attack"})
	check_death()

func apply_attack_effects(trigger: String,source_id: int) -> void:
	for e in state.attack.get("effects",[]):
		if e.type==trigger: apply_effects(source_id,e.get("effects",[]),{})

func effect_target(source: int,target: String) -> int:
	if target=="enemy":
		if not state.attack.is_empty():
			var attacker: int=int(state.attack.attacker_id)
			var defender: int=int(state.attack.defender_id)
			if state.is_hostile(source,defender): return defender
			if state.is_hostile(source,attacker): return attacker
		var source_actor=state.get_actor(source)
		if source_actor==null: return source
		var closest: int=source
		var distance: int=2147483647
		for a in state.actors:
			if not state.is_hostile(source,a.id) or a.hp_u<=0: continue
			var steps: int=absi(a.cell.x-source_actor.cell.x)+absi(a.cell.y-source_actor.cell.y)
			if steps<distance or (steps==distance and a.id<closest):
				distance=steps
				closest=a.id
		return closest
	if target=="attack_target" and not state.attack.is_empty(): return int(state.attack.defender_id)
	if target=="attack_source" and not state.attack.is_empty(): return int(state.attack.attacker_id)
	return source

func apply_effects(source: int,effects: Array,choice: Dictionary = {},derived: bool = false) -> void:
	for effect in effects:
		if state.outcome!="playing": return
		if derived:
			if state.root_effect_count>=MAX_EFFECTS:
				state.hook_queue.clear()
				diagnostic("HOOK_LIMIT_REACHED","本次行动衍生效果达到32条，剩余效果已中止")
				return
			state.root_effect_count+=1
		var target_id: int=effect_target(source,str(effect.get("target","self")))
		match str(effect.type):
			"deal_damage": deal_damage(source,target_id,float(effect.amount))
			"on_attack_hit", "on_attack_miss": pass
			"move":
				if not choice.get("target_cell") is Vector2i: continue
				var path: Array=state.find_path(state.get_actor(source).cell,choice.target_cell,source)
				if not path.is_empty() and path.size()<=int(effect.max_distance): move_actor(source,choice.target_cell,path)
			"add_shield": add_shield(target_id,float(effect.amount),int(effect.get("expires_after_global_ticks",100)))
			"gain_qi": gain_qi(target_id,float(effect.amount))
			"modify_pending_damage":
				if state.attack.is_empty(): continue
				var delta: int=int(effect.get("flat_delta",0))
				if delta<0: state.attack.defense_reduction+=-delta
				else: state.attack.attack_bonus+=delta
				state.attack.defense_reduction+=maxi(0,int(effect.get("reduction",0)))
			"modify_attack_area":
				if state.attack.is_empty(): continue
				var lock: Vector2i=state.attack.target_cell
				for cell in [lock]+state.neighbors(lock):
					if state.passable(cell) and not state.attack.affected_cells.has(cell): state.attack.affected_cells.append(cell)
			"cancel_chain_link":
				for link in state.clash.get("stack",[]):
					if int(link.id)==int(choice.get("link_id",-1)) and int(link.actor_id)!=source and not link.canceled and not link.resolved:
						link.canceled=true
						emit("CHAIN_LINK_CANCELED",{"actor_id":source,"link_id":link.id,"text":"截势取消 L%d" % link.id})
						break
			"contest_intercept":
				if state.attack.is_empty(): continue
				var defender=state.get_actor(source)
				var attacker=state.get_actor(int(state.attack.attacker_id))
				var parry: int=int(defender.stats.parry_power)+int(effect.get("parry_bonus",0))+int(effect.get("route_bonus",{}).get(state.attack.route,0))
				var margin: int=parry-int(attacker.stats.break_power)-int(state.attack.break_bonus)
				var branch: String="on_contested"
				if margin>=int(effect.get("success_margin",2)): branch="on_success"
				elif margin<=int(effect.get("failure_margin",-2)): branch="on_failure"
				emit("INTERCEPT_JUDGED",{"actor_id":source,"margin":margin,"result":branch,"text":"迎锋判定 %s · 差值%d" % [{"on_success":"成功","on_contested":"相持","on_failure":"失败"}[branch],margin]})
				apply_effects(source,effect.get(branch,[]),choice,derived)
			"interrupt_root_attack":
				if not state.attack.is_empty(): state.attack.interrupted=true
			"apply_status": add_status(target_id,str(effect.status_id),[],int(effect.get("stacks",1)))
			"consume_status":
				statuses.remove(target_id,str(effect.status_id))
				emit("STATUS_REMOVED",{"actor_id":target_id,"status_id":effect.status_id})
			"force_move": force_move(source,target_id,effect)
			"draw_cards":
				var a=state.get_actor(target_id)
				var drawn: Array=cards.draw(a,int(effect.count))
				visibility.refresh_intel(target_id,true)
				emit("CARDS_DRAWN",{"actor_id":target_id,"count":drawn.size()})
			"grant_card":
				var receiver=state.get_actor(target_id)
				var created: Array=[]
				for _i in range(int(effect.get("count",1))):
					var from_uid: String=str(choice.get("card_uid",state.attack.get("card_uid","")))
					var uid: String=cards.create_instance(receiver,str(effect.card_id),str(effect.get("destination","hand")),from_uid)
					if uid.is_empty(): break
					created.append(uid)
				if not created.is_empty():
					if str(effect.get("destination","hand"))=="hand": visibility.refresh_intel(target_id,true)
					emit("CARDS_GRANTED",{"actor_id":target_id,"count":created.size(),"definition_id":effect.card_id,"destination":effect.get("destination","hand")})
			"discard_cards":
				var a=state.get_actor(target_id)
				for uid in effect.get("uids",[]):
					if a.hand.has(uid): cards.leave_hand(a,str(uid),false)

func move_actor(actor_id: int,dest: Vector2i,path: Array) -> void:
	var actor=state.get_actor(actor_id)
	var previous: Vector2i=actor.cell
	actor.cell=dest
	# Follow the FINAL step of the actual resolved BFS/forced-move path.
	# A bent route must not face toward the endpoint through an obstacle.
	var from_cell: Vector2i=previous if path.size()<2 else Vector2i(path[path.size()-2])
	actor.facing=Facing.from_delta(dest-from_cell,actor.facing)
	emit("MOVE",{"actor_id":actor_id,"from":previous,"to":dest,"path":path.duplicate(),"facing":actor.facing,"text":"%s 移步 (%d,%d)" % [actor.name,dest.x,dest.y]})
	emit("MOVE_FINISHED",{"actor_id":actor_id,"from":previous,"to":dest})

func force_move(source: int,target_id: int,effect: Dictionary) -> void:
	var actor=state.get_actor(target_id)
	var delta: Vector2i=actor.cell-state.get_actor(source).cell
	if abs(delta.x)>=abs(delta.y): delta=Vector2i(signi(delta.x),0)
	else: delta=Vector2i(0,signi(delta.y))
	if effect.direction=="towards_attacker": delta=-delta
	var path: Array=[]
	var dest: Vector2i=actor.cell
	for _i in range(int(effect.max_distance)):
		var next: Vector2i=dest+delta
		if delta==Vector2i.ZERO or not state.passable(next) or state.occupied(next,target_id): break
		path.append(next)
		dest=next
	if not path.is_empty(): move_actor(target_id,dest,path)

func add_shield(actor_id: int,amount: float,duration: int) -> void:
	var a=state.get_actor(actor_id)
	a.shield_u+=roundi(amount*UNIT)
	a.shield_expiry=maxi(a.shield_expiry,state.global_tick+duration)
	emit("SHIELD",{"actor_id":actor_id,"amount":amount,"text":"%s 护体 +%s" % [a.name,str(amount)]})
	emit("SHIELD_ADDED",{"actor_id":actor_id,"amount":amount})

func gain_qi(actor_id: int,amount: float) -> void:
	var a=state.get_actor(actor_id)
	var before: int=a.qi_u
	a.qi_u=mini(a.max_qi_u,a.qi_u+roundi(amount*UNIT))
	emit("QI_GAINED",{"actor_id":actor_id,"amount":float(a.qi_u-before)/UNIT})

func add_status(actor_id: int,id: String,_events: Array = [],stacks: int = 1) -> void:
	if not statuses.add(actor_id,id,stacks): return
	visibility.refresh_intel(actor_id,false)
	emit("STATUS_APPLIED",{"actor_id":actor_id,"status_id":id,"text":"%s · %s" % [state.get_actor(actor_id).name,str(cards.statuses[id].get("name",id))]})

func finish_card(actor_id: int,uid: String) -> void:
	var actor=state.get_actor(actor_id)
	if actor==null or not actor.resolving.has(uid): return
	cards.finish(actor,uid)
	emit("CARD_RESOLVED",{"actor_id":actor_id,"card_uid":uid,"definition_id":cards.instance(uid).definition_id})

func check_death() -> void:
	if state.outcome!="playing": return
	var teams: Array=state.living_teams()
	if teams.size()>1: return
	state.winning_team=int(teams[0]) if teams.size()==1 else -1
	state.winner_id=-1
	if state.winning_team>=0:
		for a in state.actors:
			if a.team_id==state.winning_team and a.hp_u>0:
				state.winner_id=a.id
				break
	state.outcome="draw" if teams.is_empty() else ("victory" if state.winning_team==0 else "defeat")
	state.mode="FINISHED"
	state.phase="FINISHED"
	state.hook_queue.clear()
	audit.emit("BATTLE_FINISHED",{"winner_id":state.winner_id,"winning_team":state.winning_team,"text":"同归于尽" if state.outcome=="draw" else "对局结束"})

func deal_status_damage(actor_id: int,amount: int,status_id: String) -> void:
	# Timeline batches all simultaneous periodic effects before checking terminal state.
	var actor=state.get_actor(actor_id)
	var lost: int=mini(actor.hp_u,maxi(0,amount)*UNIT)
	actor.hp_u-=lost
	emit("SCORCH_TICK",{"actor_id":actor_id,"stacks":amount,"damage":float(lost)/UNIT,"text":"%s 灼痕 −%s" % [actor.name,str(float(lost)/UNIT)]})
	if lost>0: emit("HP_DAMAGED",{"actor_id":actor_id,"amount":float(lost)/UNIT,"damage_kind":"status","status_id":status_id})
