extends RefCounted
## Single controller and authority. UI and AI submit the same versioned requests.
const State = preload("res://scripts/battle_state.gd")
const Cards = preload("res://scripts/card_system.gd")
const Attributes = preload("res://scripts/attribute_system.gd")
const Statuses = preload("res://scripts/status_system.gd")
const Visibility = preload("res://scripts/visibility_system.gd")
const Hooks = preload("res://scripts/hook_registry.gd")
const Costs = preload("res://scripts/cost_resolver.gd")
const Rules = preload("res://scripts/combat_rules.gd")
const Combos = preload("res://scripts/combo_resolver.gd")
const Events = preload("res://scripts/event_log.gd")
const Turns = preload("res://scripts/turn_manager.gd")
const Reactions = preload("res://scripts/reaction_controller.gd")
const Resolver = preload("res://scripts/combat_resolver.gd")
const Techniques = preload("res://scripts/technique_runtime.gd")
const Conditions = preload("res://scripts/condition_evaluator.gd")
const Abilities = preload("res://scripts/ability_system.gd")
const COLS: int=15
const ROWS: int=10
var state
var cards
var attributes
var statuses
var visibility
var hooks
var costs
var rules
var combos
var audit
var turns
var reactions
var resolver
var techniques
var conditions
var abilities
var _request_serial: int=0
static var _battle_serial: int=0
var _busy: bool=false

func _init() -> void:
	reset()

func reset(seed: int = 2026,first_actor: int = -1,_profile: String = "tingfeng",options: Dictionary = {}) -> void:
	var revision: int=0 if state==null else state.revision+1
	var ticket: int=0 if state==null else state.animation_ticket+1
	state=State.new(seed)
	_battle_serial+=1
	state.battle_id="battle:%d:%d" % [seed,_battle_serial]
	state.root_action_id=state.battle_id+":initial"
	var party_valid: bool=not options.has("combatants") or state.configure_combatants(options.combatants)
	state.preferred_first=state.actors[0].id
	for candidate in state.actors:
		if candidate.team_id==0 and candidate.controller=="PLAYER":
			state.preferred_first=candidate.id
			break
	if state.get_actor(first_actor)!=null: state.preferred_first=first_actor
	state.revision=revision
	state.animation_ticket=ticket
	state.profile="tingfeng"
	attributes=Attributes.new()
	var schools=options.get("schools",{})
	cards=Cards.new(state,"res://data/tingfeng_cards.json",schools if schools is Dictionary else {})
	if not schools is Dictionary: cards.load_error="schools必须是角色到流派ID的对象"
	statuses=Statuses.new(state,cards)
	visibility=Visibility.new(state,cards,statuses)
	hooks=Hooks.new()
	costs=Costs.new(state,hooks)
	rules=Rules.new(state,cards,costs,hooks,statuses)
	techniques=Techniques.new(str(options.get("technique_catalog_path","res://data/techniques.json")))
	conditions=Conditions.new(statuses)
	abilities=Abilities.new(state,cards,costs,rules,techniques,conditions)
	rules.abilities=abilities
	rules.conditions=conditions
	combos=Combos.new(cards,statuses)
	audit=Events.new(state)
	turns=Turns.new(state,cards,statuses,visibility)
	reactions=Reactions.new(state)
	resolver=Resolver.new(state,cards,costs,rules,hooks,combos,statuses,visibility,audit)
	resolver.turns=turns
	resolver.reactions=reactions
	resolver.techniques=techniques
	turns.techniques=techniques
	turns.resolver=resolver
	reactions.resolver=resolver
	# Failed encounters still replace the whole graph and advance reset boundaries.
	if not party_valid:
		state.outcome="defeat"
		state.mode="FINISHED"
		state.phase="FINISHED"
		audit.emit("RULE_ERROR",{"text":state.party_error})
		_busy=false
		return
	if cards.load_error.is_empty():
		var extras=options.get("card_definitions",[])
		if not extras is Array: cards.load_error="card_definitions must be an Array"
		else:
			for definition in extras:
				if not definition is Dictionary or not cards.register_definition(definition):
					cards.load_error="Invalid extra card definition"
					break
		if cards.load_error.is_empty() and not cards.registry.verify(cards.definitions): cards.load_error=cards.registry.error
	if cards.load_error.is_empty() and not techniques.load_error.is_empty(): cards.load_error=techniques.load_error
	if cards.load_error.is_empty() and not techniques.validate_with(cards,conditions): cards.load_error=techniques.load_error
	if not cards.load_error.is_empty():
		state.outcome="defeat"
		state.mode="FINISHED"
		state.phase="FINISHED"
		audit.emit("RULE_ERROR",{"text":cards.load_error})
		return
	for actor in state.actors:
		attributes.configure(actor,options.get("attributes",{}).get(actor.id,{}),options.get("passives",{}).get(actor.id,{}))
		var learned=options.get("techniques",{}).get(actor.id,{})
		if learned is Dictionary and not options.has("technique_catalog_path"):
			learned=learned.duplicate(true)
			for technique_id in techniques.auto_equipped():
				if not learned.has(technique_id): learned[technique_id]=int(techniques.auto_equipped()[technique_id])
		if not learned is Dictionary or not techniques.configure(actor,learned):
			state.outcome="defeat"
			state.mode="FINISHED"
			state.phase="FINISHED"
			audit.emit("RULE_ERROR",{"text":techniques.load_error})
			return
		cards.build_deck(actor,seed)
		cards.draw(actor,5)
	for actor in state.actors: visibility.refresh_intel(actor.id,true)
	turns.begin_next_action()
	resolver.emit("BATTLE_STARTED",{"seed":seed,"text":"断桥听风 · %d名角色入阵" % state.actors.size()})
	state.pending_events.clear()
	_busy=false

func request(kind: String,actor_id: int,params: Dictionary = {}) -> Dictionary:
	var req: Dictionary=params.duplicate(true)
	req.kind=kind
	req.actor_id=actor_id
	if not req.has("battle_id"): req.battle_id=state.battle_id
	if not req.has("expected_revision"): req.expected_revision=req.get("request_version",state.revision)
	if not req.has("request_version"): req.request_version=req.expected_revision
	if not req.has("request_id"):
		_request_serial+=1
		req.request_id="request:%d" % _request_serial
	if not req.has("action_id"): req.action_id=req.request_id
	if req.has("card_uid") and not req.has("card_id"): req.card_id=req.card_uid
	if req.has("card_id") and not req.has("card_uid"): req.card_uid=req.card_id
	return req

func validate(req: Dictionary) -> Dictionary:
	return rules.validate(req)

func submit(req: Dictionary) -> Dictionary:
	if _busy: return failure("REENTRANT_REQUEST","结算中不能再次提交行动")
	_busy=true
	var verdict: Dictionary=rules.validate(req)
	if not verdict.success:
		_busy=false
		return failure(str(verdict.error_code),str(verdict.message))
	var accepted: Dictionary=req.duplicate(true)
	if not accepted.has("request_id") or not accepted.has("action_id"):
		accepted=request(str(req.kind),int(req.actor_id),req)
	if state.mode!="CLASH":
		state.root_action_id=str(accepted.action_id)
		state.root_effect_count=0
		state.hook_queue.clear()
		for key in state.hook_usage.keys():
			var keep: bool=false
			for actor in state.actors:
				if str(key).begins_with("turn:%d:%d:" % [actor.id,actor.turns_started]): keep=true
			if not keep: state.hook_usage.erase(key)
	state.pending_events.clear()
	state.processed_requests[str(accepted.request_id)]=true
	state.processed_requests[str(accepted.action_id)]=true
	state.revision+=1
	resolver.apply(verdict.action,verdict.plan)
	state.animation_pending=true
	state.animation_ticket+=1
	var events: Array=state.pending_events.duplicate(true)
	_busy=false
	return success(events)

func acknowledge_animation(ticket: int = -1) -> Dictionary:
	if not state.animation_pending: return failure("NO_ANIMATION","没有等待中的动作表现")
	if ticket!=-1 and ticket!=state.animation_ticket: return failure("STALE_TICKET","动画确认已过期")
	state.animation_pending=false
	return success([])

func legal_actions(actor_id: int) -> Array:
	return rules.legal_actions(actor_id)

func query_legal_actions(actor_id: int,_scope: String = "own") -> Array:
	return legal_actions(actor_id)

func query_legal_responses(actor_id: int) -> Array:
	return legal_actions(actor_id) if state.mode=="CLASH" else []

func snapshot(observer_id: int = 0) -> Dictionary:
	var actors: Array=[]
	for actor in state.actors: actors.append(visibility.actor_view(actor,observer_id))
	var hand: Array=[]
	var observer=state.get_actor(observer_id)
	if observer!=null:
		for uid in observer.hand:
			var card: Dictionary=cards.card_view(str(uid))
			for usage in card.get("usages",[]):
				var quote: Dictionary=costs.quote(observer,usage.get("cost",{}),rules.context(observer_id,{"card_uid":uid,"usage_id":usage.id}))
				usage["quoted_cost"]={"qi":float(quote.get("qi_u",0))/10000,"hp":float(quote.get("hp_u",0))/10000}
			hand.append(card)
	var clash: Dictionary={}
	if not state.clash.is_empty():
		clash={"priority_actor_id":state.clash.priority_actor_id,"consecutive_passes":state.clash.consecutive_passes,"counts":state.clash.counts.duplicate(true),"stack":[]}
		for link in state.clash.stack:
			clash.stack.append({"id":link.id,"link_id":link.id,"actor_id":link.actor_id,"definition_id":link.definition_id,"usage_id":link.usage_id,"name":link.name,"canceled":link.canceled,"resolved":link.resolved})
	return {"profile":"tingfeng","mode":state.mode,"phase":state.phase,"global_tick":state.global_tick,"action_no":state.action_no,
		"school_catalog":school_options(),
		"active_id":state.active_id,"reaction":state.reaction_window,"responder_id":rules.responder_id(),
		"battle_id":state.battle_id,"revision":state.revision,"request_version":state.revision,"event_seq":state.event_seq,
		"animation_pending":state.animation_pending,"ticket":state.animation_ticket,"seed":state.seed,"round_no":state.round_no,
		"outcome":state.outcome,"winner_id":state.winner_id,"winning_team":state.winning_team,"terrain":state.terrain.duplicate(true),"actors":actors,"hand":hand,
		"attack":state.attack.duplicate(true),"clash":clash,"logs":state.logs.duplicate(true),"phase_history":state.phase_history.duplicate(true)}

func school_options() -> Array:
	return cards.catalog.options() if cards!=null and cards.catalog!=null else []

func decision_context(actor_id: int) -> Dictionary:
	var ctx: Dictionary=snapshot(actor_id)
	ctx.observer_id=actor_id
	ctx.legal_actions=legal_actions(actor_id)
	return ctx

func distance(a: Vector2i,b: Vector2i) -> int:
	return rules.distance(a,b)

func find_path(start: Vector2i,goal: Vector2i,actor_id: int = -1) -> Array:
	return state.find_path(start,goal,actor_id)

func get_unit(actor_id: int) -> Dictionary:
	var actor=state.get_actor(actor_id)
	return visibility.actor_view(actor,0) if actor!=null else {}

func success(events: Array) -> Dictionary:
	return {"success":true,"error_code":"OK","message":"","events":events,"revision":state.revision,"ticket":state.animation_ticket}

func failure(code: String,message: String) -> Dictionary:
	return {"success":false,"error_code":code,"message":message,"events":[],"revision":state.revision,"ticket":state.animation_ticket}
