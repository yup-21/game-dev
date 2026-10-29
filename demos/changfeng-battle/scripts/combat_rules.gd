extends RefCounted
## Pure action enumeration and complete precommit validation.
var state
var cards
var costs
var hooks
var statuses
var abilities
var conditions
func _init(s,c,cost_system,registry,status_system) -> void:
	state=s
	cards=c
	costs=cost_system
	hooks=registry
	statuses=status_system

func distance(a: Vector2i,b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

func responder_id() -> int:
	return int(state.clash.get("priority_actor_id",-1)) if state.mode=="CLASH" else -1

func timing(actor_id: int) -> String:
	if state.mode=="ACTION" and actor_id==state.active_id: return "ACTION"
	if state.mode=="CLASH" and actor_id==responder_id():
		return "ATTACK_REACTION" if actor_id==int(state.attack.attacker_id) else "DEFENSE_REACTION"
	return ""

func context(actor_id: int,req: Dictionary = {}) -> Dictionary:
	var actors: Array=[]
	for a in state.actors: actors.append(a.public_data())
	return {"actor_id":actor_id,"actors":actors,"request":req.duplicate(true),"mode":state.mode,"tick":state.global_tick,"attack":state.attack.duplicate(true)}

func condition_allows(actor,u: Dictionary) -> bool:
	if conditions != null and not conditions.allows(u.get("when",{}),actor,{"timing":str(u.get("timing","")),"tick":state.global_tick}): return false
	for key in u.get("conditions",{}):
		var value=u.conditions[key]
		match key:
			"before_first_attack":
				if bool(value) and not actor.attack_history.is_empty(): return false
			"after_active_attack":
				if bool(value) and actor.attack_history.is_empty(): return false
			"has_status":
				if not statuses.has(actor.id,str(value)): return false
			_: return false
	return true

func line_clear(from: Vector2i,to: Vector2i) -> bool:
	if from.x!=to.x and from.y!=to.y: return false
	var p: Vector2i=from
	var dx: int=absi(to.x-from.x)
	var dy: int=absi(to.y-from.y)
	var sx: int=1 if from.x<to.x else -1
	var sy: int=1 if from.y<to.y else -1
	var err: int=dx-dy
	while p!=to:
		var e2: int=err*2
		if e2>-dy:
			err-=dy
			p.x+=sx
		if e2<dx:
			err+=dx
			p.y+=sy
		if p!=to and (not state.passable(p) or state.occupied(p)): return false
	return true

func card_options(actor,t: String, reachable: Dictionary = {}) -> Array:
	return abilities.options(actor,t,reachable)

func raw_actions(actor_id: int) -> Array:
	var options: Array=[]
	if state.outcome!="playing" or state.animation_pending: return options
	var actor=state.get_actor(actor_id)
	if actor==null or actor.hp_u<=0: return options
	var t: String=timing(actor_id)
	if t.is_empty(): return options
	var reachable: Dictionary=state.reachable_paths(actor.cell,actor_id)
	if t=="ACTION":
		options.append({"kind":"END_ACTION","actor_id":actor_id})
		var max_move: int=int(actor.stats.move_budget)-actor.normal_moves_used
		for cell in state.terrain:
			var path: Array=reachable.get(cell,[])
			if not path.is_empty() and path.size()<=max_move and actor.qi_u>=path.size()*10000:
				options.append({"kind":"MOVE","actor_id":actor_id,"target_cell":cell})
		if not actor.basic_attack_used and actor.qi_u>=10000:
			for target in state.actors:
				if target.id!=actor_id and target.hp_u>0 and distance(actor.cell,target.cell)==1:
					options.append({"kind":"BASIC_ATTACK","actor_id":actor_id,"target_id":target.id})
		if not actor.basic_guard_used and actor.qi_u>=10000: options.append({"kind":"BASIC_GUARD","actor_id":actor_id})
		if not actor.pitch_used:
			for uid in actor.hand: options.append({"kind":"PITCH_CARD","actor_id":actor_id,"card_uid":uid,"card_id":uid})
	else:
		options.append({"kind":"PASS_REACTION","actor_id":actor_id})
	options.append_array(card_options(actor,t,reachable))
	if t=="ACTION" and abilities != null:
		for id in actor.technique_states:
			if str(actor.technique_states[id].node) != str(abilities.techniques.definitions[id].entry):
				options.append({"kind":"RESET_TECHNIQUE","actor_id":actor_id,"technique_id":str(id)})
	return options

func legal_actions(actor_id: int) -> Array:
	var result: Array=[]
	for o in raw_actions(actor_id):
		if not hooks.validate(context(actor_id,o)).get("success",false): continue
		o.battle_id=state.battle_id
		o.expected_revision=state.revision
		o.request_version=state.revision
		result.append(o)
	return result

func failure(code: String,message: String) -> Dictionary:
	return {"success":false,"error_code":code,"message":message}

func validate(req: Dictionary) -> Dictionary:
	# Check types before comparisons: Variant Array == String is a runtime error in Godot.
	var fields: Dictionary={"kind":TYPE_STRING,"actor_id":TYPE_INT,"battle_id":TYPE_STRING,
		"expected_revision":TYPE_INT,"request_version":TYPE_INT,"request_id":TYPE_STRING,"action_id":TYPE_STRING,
		"card_id":TYPE_STRING,"card_uid":TYPE_STRING,"usage_id":TYPE_STRING,"target_cell":TYPE_VECTOR2I,"target_id":TYPE_INT,"link_id":TYPE_INT,"technique_id":TYPE_STRING,"node_id":TYPE_STRING}
	for key in fields:
		if req.has(key) and typeof(req[key])!=int(fields[key]): return failure("MALFORMED_REQUEST","请求字段类型错误："+str(key))
	if not req.has("kind") or not req.has("actor_id"): return failure("MALFORMED_REQUEST","缺少行动或操作者")
	if req.get("battle_id","")!=state.battle_id: return failure("STALE_BATTLE","这是上一场战斗的操作")
	for key in ["expected_revision","request_version"]:
		if req.has(key) and (not req[key] is int or int(req[key])!=state.revision): return failure("STALE_REVISION","操作版本已过期")
	if not req.has("expected_revision") and not req.has("request_version"): return failure("MISSING_VERSION","缺少请求版本")
	for key in ["request_id","action_id"]:
		if req.has(key) and (not req[key] is String or str(req[key]).is_empty() or state.processed_requests.has(str(req[key]))): return failure("DUPLICATE_ACTION","请求已消费或编号无效")
	if req.has("card_id") and req.has("card_uid") and req.card_id!=req.card_uid: return failure("ALIAS_MISMATCH","卡牌 UID 别名不一致")
	if not req.get("actor_id") is int or state.get_actor(int(req.actor_id))==null: return failure("INVALID_ACTOR","角色不存在")
	if state.outcome!="playing": return failure("BATTLE_FINISHED","战斗已经结束")
	if state.animation_pending: return failure("PRESENTATION_PENDING","等待当前动作表现完成")
	var normalized: Dictionary=req.duplicate(true)
	if normalized.get("kind","")=="END_PHASE": normalized.kind="END_ACTION"
	if normalized.has("card_id") and not normalized.has("card_uid"): normalized.card_uid=normalized.card_id
	var canonical: Dictionary={}
	for o in raw_actions(int(req.actor_id)):
		var matches: bool=true
		for key in ["kind","card_uid","usage_id","technique_id","node_id","target_id","target_cell","link_id"]:
			if normalized.get(key)!=o.get(key): matches=false
		if matches:
			canonical=o
			break
	if canonical.is_empty(): return failure("ILLEGAL_ACTION","当前无此合法操作：检查时机、内息、落点与目标")
	var ctx: Dictionary=context(int(req.actor_id),normalized)
	var checked: Dictionary=hooks.validate(ctx)
	if not checked.get("success",false): return failure("HOOK_REJECTED",str(checked.get("message","行动被规则禁止")))
	var actor=state.get_actor(int(req.actor_id))
	var cost: Dictionary={"qi":0}
	if canonical.kind in ["BASIC_ATTACK","BASIC_GUARD"]: cost={"qi":1}
	if canonical.kind=="MOVE": cost={"qi":state.find_path(actor.cell,canonical.target_cell,actor.id).size()}
	if canonical.kind=="PLAY_CARD": cost=cards.usage(str(canonical.card_uid),str(canonical.usage_id)).get("cost",{})
	if canonical.kind=="USE_ABILITY": cost=abilities.techniques.cost(actor,str(canonical.technique_id),str(canonical.node_id))
	var quote: Dictionary=costs.quote(actor,cost,ctx)
	# Ordinary movement and basic actions have fixed costs; card techniques receive attribute modifiers.
	if canonical.kind not in ["PLAY_CARD","USE_ABILITY"]:
		quote={"qi_u":roundi(float(cost.qi)*10000),"hp_u":0,"valid":true}
	if not costs.can_pay(actor,quote): return failure("INSUFFICIENT_RESOURCE","内息不足或气血费用无法支付")
	return {"success":true,"plan":quote,"action":canonical}
