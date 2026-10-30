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
	if conditions != null and not conditions.allows(actor,u.get("when",{}),{"timing":str(u.get("timing","")),"tick":state.global_tick}): return false
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
	var reachable: Dictionary=state.reachable_paths(actor.cell,actor_id) if state.spatial_mode=="GRID" else {}
	if t=="ACTION":
		options.append({"kind":"END_ACTION","actor_id":actor_id})
		for school_id in actor.learned_schools:
			if str(school_id)!=actor.school_id:
				options.append({"kind":"SWITCH_SCHOOL","actor_id":actor_id,"school_id":str(school_id)})
		if state.spatial_mode=="GRID":
			var max_move: int=int(actor.stats.move_budget)-actor.normal_moves_used
			for cell in state.terrain:
				var path: Array=reachable.get(cell,[])
				if not path.is_empty() and path.size()<=max_move and actor.qi_u>=path.size()*10000:
					options.append({"kind":"MOVE","actor_id":actor_id,"target_cell":cell})
		if not actor.basic_attack_used and actor.qi_u>=10000:
			for target in state.actors:
				if state.is_hostile(actor_id,target.id) and target.hp_u>0 and _basic_attack_in_range(actor,target):
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
		"card_id":TYPE_STRING,"card_uid":TYPE_STRING,"usage_id":TYPE_STRING,"target_cell":TYPE_VECTOR2I,"target_position":TYPE_VECTOR2,"attack_kind":TYPE_STRING,"spatial_mode":TYPE_STRING,"target_id":TYPE_INT,"link_id":TYPE_INT,"technique_id":TYPE_STRING,"node_id":TYPE_STRING,"school_id":TYPE_STRING}
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
	# Arbitrary continuous targets cannot be enumerated in legal_actions().
	# They must instead pass the same authoritative, precommit checks.
	if str(normalized.get("kind",""))=="SET_SPATIAL_MODE":
		return _validate_mode_change(normalized)
	if str(normalized.get("kind",""))=="MOVE_FREE":
		return _validate_free_move(normalized)
	if str(normalized.get("kind",""))=="MOVE_AND_ATTACK":
		return _validate_move_and_attack(normalized)
	if str(normalized.get("kind",""))=="PLAY_CARD_FREE_MOVE":
		return _validate_free_card_move(normalized)
	var canonical: Dictionary={}
	for o in raw_actions(int(req.actor_id)):
		var matches: bool=true
		for key in ["kind","card_uid","usage_id","technique_id","node_id","target_id","target_cell","link_id","school_id","spatial_mode"]:
			if normalized.get(key)!=o.get(key): matches=false
		if matches:
			canonical=o
			break
	if canonical.is_empty(): return failure("ILLEGAL_ACTION","当前无此合法操作：检查时机、内息、落点与目标")
	var ctx: Dictionary=context(int(req.actor_id),normalized)
	var checked: Dictionary=hooks.validate(ctx)
	if not checked.get("success",false): return failure("HOOK_REJECTED",str(checked.get("message","行动被规则禁止")))
	var actor=state.get_actor(int(req.actor_id))
	if canonical.kind=="SET_SPATIAL_MODE" and str(canonical.spatial_mode)=="GRID" and not _can_reanchor_to_grid():
		return failure("GRID_REANCHOR_BLOCKED","有角色位于相同旧格子，无法安全切回网格")
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

## MOVE_FREE is deliberately separate from MOVE during legacy-rule migration.
## No state is mutated and no Qi is spent unless BattleModel.submit accepts this plan.
func _validate_free_move(req: Dictionary) -> Dictionary:
	if state.spatial == null:
		return failure("SPATIAL_UNAVAILABLE","当前战场不支持自由移动")
	if state.spatial_mode!="FREE":
		return failure("WRONG_SPATIAL_MODE","网格模式禁止自由移动，请先切换战斗模式")
	if not req.has("target_position") or req.has("target_cell"):
		return failure("MALFORMED_REQUEST","自由移动仅接受 target_position")
	if timing(int(req.actor_id))!="ACTION":
		return failure("ILLEGAL_ACTION","当前并非该角色的行动阶段")
	var actor=state.get_actor(int(req.actor_id))
	if actor==null or actor.hp_u<=0:
		return failure("INVALID_ACTOR","角色不存在或已失去行动能力")
	var goal: Vector2=req.target_position
	if not is_finite(goal.x) or not is_finite(goal.y) or absf(goal.x)>100000.0 or absf(goal.y)>100000.0:
		return failure("INVALID_POSITION","移动目标坐标无效")
	# A fixed quarter-unit grid is subpixel precision, not a gameplay tile.
	# Quantization keeps logical positions stable across save/replay boundaries.
	goal=Vector2(roundf(goal.x*4.0)*0.25,roundf(goal.y*4.0)*0.25)
	var destination_cell: Vector2i=state.spatial.bake.cell_at_screen(goal,true)
	if destination_cell==Vector2i(-1,-1):
		return failure("INVALID_POSITION","落脚点不可通行或与旧战棋单位冲突")
	var positions: Dictionary={}
	for other in state.actors:
		positions[other.id]={"position":other.position,"radius":8.0,"alive":other.hp_u>0}
	state.spatial.set_actors(positions)
	var path: PackedVector2Array=state.spatial.find_path(actor.position,goal,8.0,actor.id)
	if path.size()<2:
		return failure("UNREACHABLE_POSITION","落脚点无法通过当前地形到达")
	var distance: float=state.spatial.path_length(path)
	if distance<0.25:
		return failure("NO_MOVEMENT","角色已经位于此落点")
	var unit_distance: float=maxf(state.spatial.bake.step.x,state.spatial.bake.step.y)
	var units: int=ceili((distance-0.0001)/unit_distance)
	var remaining: int=int(actor.stats.get("move_budget",2))-actor.normal_moves_used
	if units>remaining or remaining<=0:
		return failure("MOVE_BUDGET_EXCEEDED","移动路线超过本回合剩余距离")
	var quote: Dictionary={"qi_u":units*10000,"hp_u":0,"valid":true,
		"move_units":units,"move_distance":distance,"continuous_path":path}
	if not costs.can_pay(actor,quote):
		return failure("INSUFFICIENT_RESOURCE","内息不足，无法完成自由移动")
	var action: Dictionary={"kind":"MOVE_FREE","actor_id":actor.id,
		"target_position":goal,"target_cell":destination_cell}
	var checked: Dictionary=hooks.validate(context(actor.id,req))
	if not checked.get("success",false):
		return failure("HOOK_REJECTED",str(checked.get("message","行动被规则禁止")))
	return {"success":true,"action":action,"plan":quote}

## A single precommit plan owns both approach movement and attack execution.
## Neither stage is applied until all geometry, hook, card and resource checks pass.
func _validate_move_and_attack(req: Dictionary) -> Dictionary:
	if state.spatial==null:
		return failure("SPATIAL_UNAVAILABLE","当前战场不支持自动接近")
	if state.spatial_mode!="FREE":
		return failure("WRONG_SPATIAL_MODE","网格模式不能执行自由接近攻击")
	if timing(int(req.actor_id))!="ACTION":
		return failure("ILLEGAL_ACTION","只能在自己的行动阶段主动接近攻击")
	if req.has("target_cell") or req.has("target_position") or not req.has("target_id"):
		return failure("MALFORMED_REQUEST","接近攻击只能指定敌方角色")
	var actor=state.get_actor(int(req.actor_id))
	var target=state.get_actor(int(req.target_id))
	if actor==null or actor.hp_u<=0 or target==null or target.hp_u<=0 or not state.is_hostile(actor.id,target.id):
		return failure("INVALID_TARGET","必须选择存活的敌方目标")
	var kind: String=str(req.get("attack_kind",""))
	if kind not in ["BASIC_ATTACK","PLAY_CARD","USE_ABILITY"]:
		return failure("MALFORMED_REQUEST","没有指定受支持的攻击类型")
	var attack: Dictionary={"kind":kind,"actor_id":actor.id,"target_id":target.id}
	var usage: Dictionary={}
	var attack_cost: Dictionary={"qi":1}
	if kind=="BASIC_ATTACK":
		if actor.basic_attack_used:
			return failure("ILLEGAL_ACTION","本次行动已经使用普通攻击")
	else:
		if kind=="PLAY_CARD":
			var uid: String=str(req.get("card_uid",req.get("card_id","")))
			var usage_id: String=str(req.get("usage_id",""))
			if uid.is_empty() or usage_id.is_empty() or not actor.hand.has(uid):
				return failure("INVALID_CARD","攻击卡牌不在当前手牌中")
			var definition: Dictionary=cards.canonical_definition(uid)
			if not cards.valid_definition(definition):
				return failure("INVALID_CARD","当前卡牌定义无效")
			usage=cards.usage(uid,usage_id)
			if usage.is_empty() or str(usage.get("timing",""))!="ACTION":
				return failure("ILLEGAL_ACTION","当前招式不允许主动使用")
			if not condition_allows(actor,usage):
				return failure("ILLEGAL_ACTION","招式前置条件不满足")
			if bool(usage.get("once_per_action",false)) and int(actor.card_uses.get(str(definition.id)+":"+usage_id,0))>0:
				return failure("ILLEGAL_ACTION","该招式本回合已经使用")
			attack.merge({"card_uid":uid,"card_id":uid,"usage_id":usage_id})
			attack_cost=usage.get("cost",{})
		else:
			var technique_id: String=str(req.get("technique_id",""))
			var node_id: String=str(req.get("node_id",""))
			var known: bool=false
			for node in abilities.techniques.available_nodes(actor,technique_id,"ACTION"):
				if str(node.get("id",""))==node_id:
					usage=node
					known=true
					break
			if not known:
				return failure("ILLEGAL_ACTION","武学阶段不可用或尚未解锁")
			if not conditions.allows(actor,usage.get("when",{}),{"timing":"ACTION","tick":state.global_tick,
				"same_action":int(actor.technique_states[technique_id].last_used_action)==actor.turns_started}):
				return failure("ILLEGAL_ACTION","当前武学阶段条件不满足")
			attack.merge({"technique_id":technique_id,"node_id":node_id})
			attack_cost=abilities.techniques.cost(actor,technique_id,node_id)
		if str(usage.get("target",{}).get("kind",""))!="enemy_actor":
			return failure("INVALID_TARGET","只有指定敌方目标的攻击招式能自动接近")
		var deals_damage: bool=false
		for effect in usage.get("effects",[]):
			if str(effect.get("type",""))=="deal_damage":
				deals_damage=true
		if not deals_damage:
			return failure("ILLEGAL_ACTION","这张卡牌不是攻击招式")
	# Never allow a composite request to bypass card/ability-specific hook policy.
	for candidate in [req, attack]:
		var checked: Dictionary=hooks.validate(context(actor.id,candidate))
		if not bool(checked.get("success",false)):
			return failure("HOOK_REJECTED",str(checked.get("message","行动被规则禁止")))
	var attack_quote: Dictionary=costs.quote(actor,attack_cost,context(actor.id,attack))
	if kind=="BASIC_ATTACK":
		attack_quote={"qi_u":10000,"hp_u":0,"valid":true}
	if not costs.can_pay(actor,attack_quote):
		return failure("INSUFFICIENT_RESOURCE","无法支付攻击本身的气血或内息费用")
	var remaining: int=int(actor.stats.get("move_budget",2))-actor.normal_moves_used
	var world_unit: float=maxf(state.spatial.bake.step.x,state.spatial.bake.step.y)
	var available_distance: float=maxf(0.0,float(remaining)*world_unit)
	var min_distance: int=1
	var max_distance: int=1
	# Basic melee attacks may never strike through blocked bridge/rock terrain.
	var line_required: bool=kind=="BASIC_ATTACK"
	if kind!="BASIC_ATTACK":
		min_distance=maxi(1,int(usage.target.get("min_distance",1)))
		max_distance=int(usage.get("attack_profile",{}).get("range",usage.target.get("max_distance",1)))
		line_required=true # world-space attacks require an unobstructed sightline
	if max_distance < min_distance:
		return failure("INVALID_TARGET","武学攻击距离定义无效")
	var min_range: float=float(min_distance-1)*world_unit
	var max_range: float=float(max_distance)*world_unit
	var positions: Dictionary={}
	for other in state.actors:
		positions[other.id]={"position":other.position,"radius":8.0,"alive":other.hp_u>0}
	state.spatial.set_actors(positions)
	var approach: Dictionary=state.spatial.find_attack_approach(actor.position,target.position,
		min_range,max_range,available_distance,8.0,8.0,actor.id,target.id,line_required)
	if approach.is_empty():
		return failure("NO_ATTACK_POSITION","本回合移动距离内没有可用的攻击站位")
	var final_position: Vector2=Vector2(approach.position)
	var path: PackedVector2Array=PackedVector2Array(approach.path)
	var travelled: float=float(approach.cost)
	# Same quantized coordinates as MOVE_FREE; replan after rounding to keep
	# committed world state and path endpoint identical.
	if travelled > 0.0001:
		final_position=Vector2(roundf(final_position.x*4.0)*0.25,roundf(final_position.y*4.0)*0.25)
		if not state.spatial.is_valid_position(final_position,8.0,actor.id):
			return failure("INVALID_POSITION","接近攻击落点发生冲突")
		path=state.spatial.find_path(actor.position,final_position,8.0,actor.id)
		if path.size()<2:
			return failure("UNREACHABLE_POSITION","接近路线已经失效")
		travelled=state.spatial.path_length(path)
	var dest_cell: Vector2i=state.spatial.bake.cell_at_screen(final_position,true)
	if dest_cell==Vector2i(-1,-1):
		return failure("INVALID_POSITION","目标附近没有可站立的位置")
	if not state.spatial.attack_in_range(final_position,target.position,min_range,max_range,8.0,8.0):
		return failure("INVALID_RANGE","接近后仍不满足武学有效距离")
	if line_required and not state.spatial.attack_line_clear(final_position,target.position,[actor.id,target.id]):
		return failure("LINE_BLOCKED","攻击路径被地形或其他角色阻挡")
	var move_units: int=0 if travelled<=0.0001 else ceili((travelled-0.0001)/world_unit)
	if move_units>remaining:
		return failure("MOVE_BUDGET_EXCEEDED","本回合移动距离不足以接近目标")
	var total_quote: Dictionary=attack_quote.duplicate(true)
	total_quote["qi_u"]=int(attack_quote.get("qi_u",0))+move_units*10000
	if not costs.can_pay(actor,total_quote):
		return failure("INSUFFICIENT_RESOURCE","移动与攻击总内息不足")
	attack["approach_position"]=final_position
	attack["approach_cell"]=dest_cell
	total_quote["move_units"]=move_units
	total_quote["continuous_path"]=path
	total_quote["move_distance"]=travelled
	total_quote["attack_kind"]=kind
	return {"success":true,"action":{"kind":"MOVE_AND_ATTACK","actor_id":actor.id,
		"target_id":target.id,"attack":attack,"target_position":final_position,
		"target_cell":dest_cell},"plan":total_quote}

## Grid representation is still used for map authoring and legacy techniques;
## tactical FREE collision never treats two feet in the same tile as overlapping.
func _can_reanchor_to_grid() -> bool:
	if state.spatial==null: return false
	var occupied_cells: Dictionary={}
	for actor in state.actors:
		if actor.hp_u<=0: continue
		if not state.spatial.bake.is_walkable(actor.cell) or occupied_cells.has(actor.cell):
			return false
		occupied_cells[actor.cell]=true
	return true

func _basic_attack_in_range(actor,target) -> bool:
	if state.spatial_mode!="FREE" or state.spatial==null:
		return distance(actor.cell,target.cell)==1
	var unit: float=maxf(state.spatial.bake.step.x,state.spatial.bake.step.y)
	var spatial=state.spatial
	var positions: Dictionary={}
	for combatant in state.actors:
		positions[combatant.id]={"position":combatant.position,"radius":8.0,"alive":combatant.hp_u>0}
	spatial.set_actors(positions)
	return spatial.attack_in_range(actor.position,target.position,0.0,unit,8.0,8.0) and spatial.attack_line_clear(actor.position,target.position,[actor.id,target.id])

## Geometry used by directly played cards and abilities in FREE mode.
## `MOVE_AND_ATTACK` uses the same range convention for approach plans.
func free_target_legal(actor,target,usage: Dictionary) -> bool:
	if state.spatial_mode!="FREE" or state.spatial==null: return false
	if not state.is_hostile(actor.id,target.id) or target.hp_u<=0: return false
	var maximum: int=int(usage.get("attack_profile",{}).get("range",usage.get("target",{}).get("max_distance",1)))
	var minimum: int=int(usage.get("target",{}).get("min_distance",1))
	if minimum<1 or maximum<minimum: return false
	var unit: float=maxf(state.spatial.bake.step.x,state.spatial.bake.step.y)
	var spatial=state.spatial
	var positions: Dictionary={}
	for combatant in state.actors:
		positions[combatant.id]={"position":combatant.position,"radius":8.0,"alive":combatant.hp_u>0}
	spatial.set_actors(positions)
	return spatial.attack_in_range(actor.position,target.position,float(minimum-1)*unit,float(maximum)*unit,8.0,8.0) and spatial.attack_line_clear(actor.position,target.position,[actor.id,target.id])

## Changing rules never consumes movement, card uses, CTB or Qi. It is still
## an authoritative revisioned command, blocked during attacks and animations.
func _validate_mode_change(req: Dictionary) -> Dictionary:
	if state.spatial==null: return failure("SPATIAL_UNAVAILABLE","当前地图没有连续空间校准")
	if timing(int(req.actor_id))!="ACTION":
		return failure("ILLEGAL_ACTION","只能在自己的行动阶段切换战斗规则")
	if not req.has("spatial_mode") or str(req.spatial_mode) not in ["GRID","FREE"]:
		return failure("MALFORMED_REQUEST","只能选择 GRID 或 FREE")
	if req.has("target_cell") or req.has("target_position") or req.has("target_id"):
		return failure("MALFORMED_REQUEST","模式切换不能包含行动目标")
	var next_mode: String=str(req.spatial_mode)
	if next_mode==state.spatial_mode:
		return failure("MODE_UNCHANGED","当前已经是该战斗模式")
	if next_mode=="GRID" and not _can_reanchor_to_grid():
		return failure("GRID_REANCHOR_BLOCKED","角色占用相同格子或站位不可通行，不能安全切换到网格模式")
	var checked: Dictionary=hooks.validate(context(int(req.actor_id),req))
	if not bool(checked.get("success",false)):
		return failure("HOOK_REJECTED",str(checked.get("message","规则拒绝切换模式")))
	return {"success":true,"action":{"kind":"SET_SPATIAL_MODE","actor_id":int(req.actor_id),
		"spatial_mode":next_mode},"plan":{"qi_u":0,"hp_u":0,"valid":true}}

## Martial step/evasion cards accept continuous landing coordinates in FREE.
## Card movement uses the card's own max_distance and cost (not normal MOVE
## budget). Reactions enter the existing deferred LIFO response stack.
func _validate_free_card_move(req: Dictionary) -> Dictionary:
	if state.spatial==null or state.spatial_mode!="FREE":
		return failure("WRONG_SPATIAL_MODE","当前战斗模式不支持自由武学步法")
	if not req.has("target_position") or req.has("target_cell") or req.has("target_id"):
		return failure("MALFORMED_REQUEST","武学步法必须指定唯一的落脚坐标")
	var actor=state.get_actor(int(req.actor_id))
	if actor==null or actor.hp_u<=0: return failure("INVALID_ACTOR","角色无法行动")
	var uid: String=str(req.get("card_uid",req.get("card_id","")))
	var usage_id: String=str(req.get("usage_id",""))
	if uid.is_empty() or not actor.hand.has(uid):
		return failure("INVALID_CARD","移动卡牌不在当前手牌")
	var definition: Dictionary=cards.canonical_definition(uid)
	if not cards.valid_definition(definition): return failure("INVALID_CARD","武学卡牌定义无效")
	var usage: Dictionary=cards.usage(uid,usage_id)
	var t: String=timing(actor.id)
	if t.is_empty() or str(usage.get("timing",""))!=t or str(usage.get("target",{}).get("kind",""))!="reachable_cell":
		return failure("ILLEGAL_ACTION","当前时机不能使用这张步法牌")
	if not condition_allows(actor,usage): return failure("ILLEGAL_ACTION","武学步法条件不满足")
	if bool(usage.get("once_per_action",false)) and int(actor.card_uses.get(str(definition.id)+":"+usage_id,0))>0:
		return failure("ILLEGAL_ACTION","当前行动已使用这张步法")
	if state.mode=="CLASH" and (int(state.clash.counts.get(actor.id,0))>=2 or state.clash.stack.size()>=4):
		return failure("RESPONSE_LIMIT","交锋响应层数已满")
	var allowed_steps: int=int(usage.get("target",{}).get("max_distance",0))
	var has_move: bool=false
	for effect in usage.get("effects",[]):
		if str(effect.get("type",""))=="move":
			has_move=true
			allowed_steps=mini(allowed_steps,int(effect.get("max_distance",0)))
	if not has_move or allowed_steps<1:
		return failure("ILLEGAL_ACTION","该卡牌不是可自由移动的武学步法")
	var point: Vector2=req.target_position
	if not is_finite(point.x) or not is_finite(point.y) or absf(point.x)>100000.0 or absf(point.y)>100000.0:
		return failure("INVALID_POSITION","武学步法目标坐标无效")
	point=Vector2(roundf(point.x*4.0)*0.25,roundf(point.y*4.0)*0.25)
	var dest_cell: Vector2i=state.spatial.bake.cell_at_screen(point,true)
	if dest_cell==Vector2i(-1,-1): return failure("INVALID_POSITION","步法落点不可通行")
	var positions: Dictionary={}
	for other in state.actors:
		positions[other.id]={"position":other.position,"radius":8.0,"alive":other.hp_u>0}
	state.spatial.set_actors(positions)
	var path: PackedVector2Array=state.spatial.find_path(actor.position,point,8.0,actor.id)
	if path.size()<2: return failure("UNREACHABLE_POSITION","步法目标不可达")
	var distance: float=state.spatial.path_length(path)
	var maximum: float=float(allowed_steps)*maxf(state.spatial.bake.step.x,state.spatial.bake.step.y)
	if distance<0.25 or distance>maximum+0.001:
		return failure("MOVE_BUDGET_EXCEEDED","超出该武学步法的实际移动距离")
	var action: Dictionary={"kind":"PLAY_CARD_FREE_MOVE","actor_id":actor.id,
		"card_uid":uid,"card_id":uid,"usage_id":usage_id,
		"target_position":point,"target_cell":dest_cell,"continuous_path":path}
	var checked: Dictionary=hooks.validate(context(actor.id,action))
	if not bool(checked.get("success",false)):
		return failure("HOOK_REJECTED",str(checked.get("message","移动被规则禁止")))
	var quote: Dictionary=costs.quote(actor,usage.get("cost",{}),context(actor.id,action))
	if not costs.can_pay(actor,quote):
		return failure("INSUFFICIENT_RESOURCE","无法支付武学步法内息")
	return {"success":true,"action":action,"plan":quote}
