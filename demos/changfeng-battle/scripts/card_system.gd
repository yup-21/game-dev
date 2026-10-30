extends RefCounted
## Definitions are copied on access. Only UID instances reside in BattleState.
const EFFECT_TYPES = ["deal_damage","on_attack_hit","on_attack_miss","move","add_shield","gain_qi","modify_pending_damage","modify_attack_area","cancel_chain_link","contest_intercept","interrupt_root_attack","apply_status","consume_status","force_move","draw_cards","discard_cards","grant_card"]
const SchoolCatalog = preload("res://scripts/school_catalog.gd")
const DefinitionRegistry = preload("res://scripts/card_definition_registry.gd")
var state
var catalog
var definitions: Dictionary = {}
var statuses: Dictionary = {}
var combos: Array = []
var deck: Array = []
var load_error: String = ""
var registry = DefinitionRegistry.new()
var instances: Dictionary:
	get: return state.card_instances

func _init(battle_state, path: String = "res://data/tingfeng_cards.json", school_selection: Dictionary = {}, learned_selection: Dictionary = {}) -> void:
	state=battle_state
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		load_error="无法读取听风卡牌配置"
		return
	for item in data.get("statuses",[]):
		statuses[str(item.id)]=item.duplicate(true)
	for item in data.get("cards",[]):
		if not item is Dictionary or definitions.has(str(item.get("id",""))) or not valid_definition(item):
			load_error="卡牌配置不合法"
			return
		if not registry.register(definitions,item):
			load_error=registry.error
			return
	deck=data.get("deck",{}).get("cards",[]).duplicate(true)
	combos=data.get("combos",[]).duplicate(true)
	for entry in deck:
		if not definitions.has(entry.get("card_id","")) or not whole(entry.get("count"),1) or bool(definitions[str(entry.card_id)].get("generated_only",false)):
			load_error="牌组引用不合法（衍生卡不得进入起始牌组）"
	catalog=SchoolCatalog.new()
	if not catalog.load_error.is_empty():
		load_error=catalog.load_error
		return
	var selected: Array=[]
	for actor in state.actors:
		var selection=school_selection.get(actor.id,"tingfeng")
		if not selection is String:
			load_error="流派ID必须为字符串"
			return
		var school: Dictionary=catalog.get_school(selection)
		if school.is_empty():
			load_error="未知流派："+selection
			return
		var learned: Variant=learned_selection.get(actor.id,[selection])
		if not learned is Array or learned.is_empty() or not learned.has(selection):
			load_error="角色所学武学列表无效"
			return
		var unique: Dictionary={}
		for id in learned:
			if not id is String or catalog.get_school(str(id)).is_empty() or unique.has(str(id)):
				load_error="角色所学武学包含无效或重复流派"
				return
			unique[str(id)]=true
			if id!="tingfeng" and not selected.has(id): selected.append(id)
		actor.learned_schools=learned.duplicate()
		actor.school_id=selection
		actor.school_name=str(school.name)
	if not selected.is_empty():
		for id in catalog.statuses: statuses[id]=catalog.statuses[id].duplicate(true)
		for definition in catalog.forms.values():
			if str(definition.school_id) not in selected: continue
			if definitions.has(definition.id) or not valid_definition(definition):
				load_error="规范化武学定义不合法："+str(definition.id)
				return
			if not registry.register(definitions,definition):
				load_error=registry.error
				return
		for combo in catalog.combos:
			var complete: bool=true
			for step in combo.get("sequence",[]):
				if not definitions.has(str(step.card_id)): complete=false
			if complete: combos.append(combo.duplicate(true))
	if not registry.verify(definitions): load_error=registry.error

func whole(value: Variant, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==float(int(value)) and int(value)>=minimum

func valid_effect(e: Variant, depth: int = 0) -> bool:
	if depth>6 or not e is Dictionary or e.get("type","") not in EFFECT_TYPES: return false
	var kind: String=e.type
	if kind in ["deal_damage","add_shield","gain_qi"]:
		var n=e.get("amount",-1)
		if not (n is int or n is float) or not is_finite(float(n)) or float(n)<0 or float(n)>10000: return false
	if kind in ["move","force_move"] and not whole(e.get("max_distance"),1): return false
	if kind in ["apply_status","consume_status"] and not statuses.has(str(e.get("status_id",""))): return false
	if kind=="modify_pending_damage":
		for key in ["flat_delta","reduction"]:
			if e.has(key):
				if not (e[key] is int or e[key] is float) or not is_finite(float(e[key])): return false
				if not whole(absf(float(e[key]))) or absf(float(e[key]))>10000: return false
	if e.has("stacks") and not whole(e.stacks,1): return false
	if e.has("expires_after_global_ticks") and not whole(e.expires_after_global_ticks,1): return false
	if kind=="contest_intercept":
		for key in ["parry_bonus","success_margin","failure_margin"]:
			var value=e.get(key,0)
			if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value))>10000: return false
		if not e.get("route_bonus",{}) is Dictionary: return false
		for value in e.get("route_bonus",{}).values():
			if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value))>10000: return false
	if kind=="force_move" and e.get("direction","") not in ["away_from_attacker","towards_attacker"]: return false
	if kind=="draw_cards" and not whole(e.get("count"),1): return false
	if kind=="grant_card":
		if not e.get("card_id") is String or str(e.card_id).is_empty(): return false
		if e.get("destination","hand") not in ["hand","draw_pile","discard_pile"]: return false
		if not whole(e.get("count",1),1) or int(e.get("count",1))>16: return false
	if kind=="discard_cards" and not e.get("uids",[]) is Array: return false
	for key in ["effects","on_success","on_contested","on_failure","on_hit"]:
		if not e.get(key,[]) is Array: return false
		for child in e.get(key,[]):
			if not valid_effect(child,depth+1): return false
	if e.has("conditional_bonus") and not valid_condition(e.conditional_bonus): return false
	return true

func valid_condition(condition: Variant) -> bool:
	if not condition is Dictionary: return false
	for key in condition:
		if key not in ["if_self_shield_gt","if_target_status","bonus_per_target_status","bonus_each","if_self_hp_pct_lt_after_cost","bonus","consume_on_hit"]: return false
		if key in ["if_target_status","bonus_per_target_status"]:
			if not condition[key] is String or not statuses.has(condition[key]): return false
		elif key=="consume_on_hit":
			if not condition[key] is String: return false
			if not str(condition[key]).is_empty() and not statuses.has(str(condition[key])) and str(condition[key])!="scorch_all": return false
		else:
			if not (condition[key] is int or condition[key] is float) or not is_finite(float(condition[key])) or float(condition[key])<0 or float(condition[key])>10000: return false
	return true

func valid_definition(d: Dictionary) -> bool:
	if str(d.get("id","")).is_empty() or str(d.get("name","")).is_empty() or not d.get("usages") is Array: return false
	var ids: Array=[]
	for u in d.usages:
		if not u is Dictionary or str(u.get("id","")).is_empty() or ids.has(u.id): return false
		ids.append(u.id)
		if u.get("timing","") not in ["ACTION","ATTACK_REACTION","DEFENSE_REACTION"]: return false
		if not u.get("cost",{}) is Dictionary: return false
		for value in u.get("cost",{}).values():
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)<0 or float(value)>10000: return false
		if u.get("target",{}).get("kind","") not in ["self","enemy_actor","reachable_cell","pending_root_attack","opponent_unresolved_response_link"]: return false
		for effect in u.get("effects",[]):
			if not valid_effect(effect): return false
	return not ids.is_empty()

func build_deck(actor, _seed: int = 0, _deck_ids: Array = []) -> bool:
	var entries: Array=catalog.deck_for(actor.school_id,deck)
	for entry in entries:
		if not definitions.has(str(entry.card_id)) or bool(definitions[str(entry.card_id)].get("generated_only",false)): return false
		for _i in range(int(entry.count)):
			var uid: String=create_instance(actor,str(entry.card_id),"draw_pile")
			if uid.is_empty(): return false
	shuffle(actor.draw_pile)
	return true

## Changing styles is a battle action. It swaps the complete physical
## deck (including temporary generated cards) without touching HP, Qi,
## equipment, status stacks or the unit's CTB meter.
func equip_school(actor, school_id: String) -> bool:
	if not actor.learned_schools.has(school_id) or actor.school_id==school_id:
		return false
	var target: Dictionary=catalog.get_school(school_id)
	if target.is_empty(): return false
	var entries: Array=catalog.deck_for(school_id,deck)
	for entry in entries:
		if not definitions.has(str(entry.card_id)) or bool(definitions[str(entry.card_id)].get("generated_only",false)):
			return false
	for zone in [actor.hand,actor.draw_pile,actor.discard_pile,actor.resolving,actor.exile_pile]:
		for uid in zone:
			forget(str(uid))
			instances.erase(str(uid))
		zone.clear()
	actor.school_id=school_id
	actor.school_name=str(target.name)
	actor.attack_history.clear()
	actor.combo_used.clear()
	actor.card_uses.clear()
	state.combo_history[actor.id]=[]
	actor.hand_generation+=1
	# This action is ending. New cards are drawn at the next natural
	# ACTION start, so the next hand refresh cannot waste freshly drawn cards.
	if not build_deck(actor): return false
	return true

func create_instance(actor, definition_id: String, destination: String = "hand", source_uid: String = "") -> String:
	if not definitions.has(definition_id) or destination not in ["hand","draw_pile","discard_pile"]: return ""
	state.next_uid+=1
	var uid: String="card:%d:%04d" % [actor.id,state.next_uid]
	var origin: Dictionary=instances.get(source_uid,{})
	instances[uid]={"uid":uid,"definition_id":definition_id,"card_id":definition_id,"owner_actor_id":actor.id,"owner":actor.id,"modifications":{},"generated":not source_uid.is_empty(),"source_uid":source_uid,"parent_uid":source_uid,"child_uids":[],"related_uids":[],"root_uid":str(origin.get("root_uid",source_uid)) if not source_uid.is_empty() else uid,"lifecycle":str(definitions[definition_id].get("lifecycle","normal")),"retain_own_actions":int(definitions[definition_id].get("retain_own_actions",0)),"created_own_action":actor.turns_started}
	match destination:
		"hand": actor.hand.append(uid)
		"draw_pile": actor.draw_pile.append(uid)
		"discard_pile": actor.discard_pile.append(uid)
	if not source_uid.is_empty() and instances.has(source_uid): instances[source_uid].child_uids.append(uid)
	if destination=="hand": actor.hand_generation+=1
	return uid

func relations(uid: String) -> Dictionary:
	var card: Dictionary=instances.get(uid,{})
	if card.is_empty(): return {}
	return {"parent_uid":str(card.get("parent_uid","")),"root_uid":str(card.get("root_uid","")),"child_uids":card.get("child_uids",[]).duplicate(),"related_uids":card.get("related_uids",[]).duplicate(),"definition":definitions[str(card.definition_id)].get("relations",{}).duplicate(true)}

func link_instances(a_uid: String,b_uid: String) -> bool:
	if a_uid==b_uid or not instances.has(a_uid) or not instances.has(b_uid): return false
	if int(instances[a_uid].owner_actor_id)!=int(instances[b_uid].owner_actor_id): return false
	if not instances[a_uid].related_uids.has(b_uid): instances[a_uid].related_uids.append(b_uid)
	if not instances[b_uid].related_uids.has(a_uid): instances[b_uid].related_uids.append(a_uid)
	return true

func register_definition(definition: Dictionary) -> bool:
	if not valid_definition(definition): return false
	return registry.register(definitions,definition)

func shuffle(items: Array) -> void:
	for i in range(items.size()-1,0,-1):
		var j: int=state.rng.randi_range(0,i)
		var item=items[i]
		items[i]=items[j]
		items[j]=item

func instance(uid: String) -> Dictionary:
	return instances.get(uid,{}).duplicate(true)

func canonical_definition(uid: String) -> Dictionary:
	return definitions.get(str(instances.get(uid,{}).get("definition_id",uid)),{}).duplicate(true)

func usage(uid: String, usage_id: String) -> Dictionary:
	for u in canonical_definition(uid).get("usages",[]):
		if u.id==usage_id: return u.duplicate(true)
	return {}

func default_usage(uid: String) -> String:
	var all: Array=canonical_definition(uid).get("usages",[])
	return str(all[0].id) if not all.is_empty() else ""

func card_view(uid: String) -> Dictionary:
	var d: Dictionary=canonical_definition(uid)
	if d.is_empty(): return {}
	var kind: String="reaction"
	for u in d.usages:
		if u.timing!="ACTION": continue
		for e in u.get("effects",[]):
			if e.type=="deal_damage": kind="attack"
			elif e.type=="move": kind="move"
			elif e.type=="add_shield": kind="shield"
	d["definition_id"]=d.id
	d["uid"]=uid
	d["card_id"]=uid
	d["kind"]=kind
	d["cost"]=d.usages[0].get("cost",{}).get("qi",0)
	d["generated"]=bool(instances[uid].get("generated",false))
	d["source_uid"]=str(instances[uid].get("source_uid",""))
	d["lifecycle"]=str(instances[uid].get("lifecycle","normal"))
	return d

func forget(uid: String) -> void:
	for viewer in state.knowledge:
		state.knowledge[viewer].erase(uid)

func draw(actor, count: int) -> Array:
	var drawn: Array=[]
	for _i in range(count):
		if actor.draw_pile.is_empty():
			if actor.discard_pile.is_empty(): break
			actor.draw_pile.append_array(actor.discard_pile)
			actor.discard_pile.clear()
			shuffle(actor.draw_pile)
		var uid: String=str(actor.draw_pile.pop_back())
		actor.hand.append(uid)
		drawn.append(uid)
	if not drawn.is_empty(): actor.hand_generation+=1
	return drawn

func retain_on_refresh(actor, uid: String) -> bool:
	var card: Dictionary=instances.get(uid,{})
	if card.is_empty(): return false
	var allowance: int=int(card.get("retain_own_actions",0))
	return allowance>0 and actor.turns_started-int(card.get("created_own_action",0))<allowance

func leave_hand(actor, uid: String, to_resolving: bool = true) -> void:
	actor.hand.erase(uid)
	forget(uid)
	if to_resolving: actor.resolving.append(uid)
	elif str(instances.get(uid,{}).get("lifecycle","normal"))=="exile_on_finish": actor.exile_pile.append(uid)
	else: actor.discard_pile.append(uid)

func finish(actor, uid: String) -> void:
	if actor.resolving.has(uid):
		actor.resolving.erase(uid)
		if str(instances.get(uid,{}).get("lifecycle","normal"))=="exile_on_finish": actor.exile_pile.append(uid)
		else: actor.discard_pile.append(uid)
