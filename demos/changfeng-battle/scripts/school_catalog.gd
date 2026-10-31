extends RefCounted
## Definition data only: this catalog never constructs card instances or touches battle state.
const StatusCatalog = preload("res://scripts/status_catalog.gd")
const NativeContent = preload("res://scripts/content/content_registry.gd")
const DEFAULT_FORMS = "res://data/native/rule_catalogs/r36_school_forms.tres"
const DEFAULT_TINGFENG = "res://data/native/rule_catalogs/r37_tingfeng_cards.tres"
const DEFAULT_SCHOOL = {"id":"tingfeng","name":"听风五式","identity":"观势藏锋、变招交锋"}
const CHILD_EFFECTS = ["effects","on_success","on_contested","on_failure","on_hit"]
const TARGETS = ["self","enemy_actor","reachable_cell","pending_root_attack","opponent_unresolved_response_link"]
const EFFECT_TARGETS = ["self","enemy","opponent","attack_target","attack_source"]
const ROUTES = ["thrust","sweep","crushing"]
const EFFECTS = ["deal_damage","on_attack_hit","on_attack_miss","move","add_shield","gain_qi","modify_pending_damage","contest_intercept","interrupt_root_attack","apply_status","force_move","draw_cards","damage_if_status","damage_if_shield","damage_if_low_hp"]
var schools: Array = []
var forms: Dictionary = {}
var statuses: Dictionary = {}
var combos: Array = []
var load_error: String = ""
var _all_status_ids: Dictionary = {}
var _base_form_ids: Dictionary = {}
var _generated_only_ids: Dictionary = {}

func _init(manifest_path: String = NativeContent.DEFAULT_MANIFEST) -> void:
	var native = NativeContent.new(manifest_path)
	if not native.load_error.is_empty():
		load_error = native.load_error
		return
	var rulebooks: Dictionary = native.entries("rule_catalog")
	var raw: Dictionary = rulebooks.get("r36_school_forms", {}).get("data", {})
	var base: Dictionary = rulebooks.get("r37_tingfeng_cards", {}).get("data", {})
	if raw.is_empty() or base.is_empty():
		load_error = "Required native martial rulebooks are missing"
		return
	var loaded: bool = _load(raw, base)
	if loaded:
		loaded = _load_native_schools(native)
	if not loaded:
		schools.clear()
		forms.clear()
		statuses.clear()
		combos.clear()

func _load_native_schools(native) -> bool:
	var skills: Dictionary = native.entries("skill")
	for item in native.entries("school").values():
		var id: String = str(item.get("id",""))
		if id.is_empty() or id == "tingfeng" or not get_school(id).is_empty():
			return _fail("Native school ID collision: " + id)
		if not _text(item.get("name")) or not _text(item.get("identity")):
			return _fail("Native school metadata invalid: " + id)
		var core: Variant = item.get("core_forms")
		var deck: Variant = item.get("deck",{}).get("cards",[])
		if not core is Array or core.size() != 2 or core[0] == core[1] or not deck is Array:
			return _fail("Native school requires two core forms and a deck: " + id)
		for form_id in core:
			var definition: Dictionary = skills.get(str(form_id),{})
			if definition.is_empty() or str(definition.get("school_id","")) != id or bool(definition.get("generated_only",true)):
				return _fail("Native school core form missing or generated: " + str(form_id))
		var seen: Dictionary = {}
		var total: int = 0
		for entry in deck:
			if not entry is Dictionary: return _fail("Native deck entry invalid: " + id)
			var card_id: String = str(entry.get("card_id",""))
			if card_id not in core or seen.has(card_id) or not _number(entry.get("count"),1,12):
				return _fail("Native deck contains duplicates or non-core cards: " + id)
			seen[card_id] = true
			total += int(entry.count)
		if total != 12 or not seen.has_all(core):
			return _fail("Native school deck must contain 12 core cards: " + id)
		schools.append(item.duplicate(true))
	return true

func options() -> Array:
	var result: Array = [DEFAULT_SCHOOL.duplicate(true)]
	for school in schools:
		result.append({"id":school.id,"name":school.name,"identity":school.identity})
	return result.duplicate(true)

func get_school(id: String) -> Dictionary:
	if id == "tingfeng": return DEFAULT_SCHOOL.duplicate(true)
	for school in schools:
		if school.id == id: return school.duplicate(true)
	return {}

func deck_for(id: String, default_deck: Array) -> Array:
	if id == "tingfeng": return default_deck.duplicate(true)
	var school: Dictionary = get_school(id)
	return school.get("deck",{}).get("cards",[]).duplicate(true)

func _fail(message: String) -> bool:
	if load_error.is_empty(): load_error = message
	return false

func _keys(value: Variant, allowed: Array, required: Array = []) -> bool:
	if not value is Dictionary: return _fail("目录字段必须为对象")
	for key in required:
		if not value.has(key): return _fail("目录缺少字段: " + str(key))
	for key in value:
		if key not in allowed: return _fail("目录未知字段: " + str(key))
	return true

func _text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()

func _number(value: Variant, minimum: float = 0, maximum: float = 10000, integer: bool = true) -> bool:
	if not (value is int or value is float) or not is_finite(float(value)): return false
	return float(value) >= minimum and float(value) <= maximum and (not integer or float(value) == floor(float(value)))

func _load(raw: Dictionary, base: Dictionary) -> bool:
	if not _keys(raw,["schema_version","source","design","statuses","schools","cards","combos"],["schema_version","source","design","statuses","schools","cards","combos"]): return false
	if raw.schema_version != "3.0-multi-usage-schools" or not _text(raw.source) or not _text(raw.design): return _fail("武学版本或元数据不合法")
	for key in ["statuses","schools","cards","combos"]:
		if not raw[key] is Array: return _fail("目录字段必须为数组: " + key)
	# Validate definitions, not the number of authored schools/forms/statuses/combos.
	if raw.schools.is_empty() or raw.cards.is_empty(): return _fail("武学目录至少需要一个流派及招式定义")
	# Independent buffs may be referenced by new martial-card effects.
	var buff_catalog = StatusCatalog.new()
	if not buff_catalog.load_error.is_empty(): return _fail(buff_catalog.load_error)
	for buff_id in buff_catalog.definitions:
		_all_status_ids[buff_id] = true
	if not base.get("cards") is Array or not base.get("statuses") is Array: return _fail("听风基础定义不完整")
	for item in base.statuses:
		if not item is Dictionary or not _text(item.get("id")) or _all_status_ids.has(item.id): return _fail("基础状态ID不合法或重复")
		_all_status_ids[item.id] = true
	for item in base.cards:
		if not item is Dictionary or not _text(item.get("id")) or _base_form_ids.has(item.id): return _fail("基础卡牌ID不合法或重复")
		_base_form_ids[item.id] = true
		if bool(item.get("generated_only",false)):
			_generated_only_ids[item.id] = true
	for item in raw.statuses:
		if not _valid_status(item) or _all_status_ids.has(item.id): return _fail("新增状态定义不合法或重复")
		statuses[item.id] = item.duplicate(true)
		_all_status_ids[item.id] = true
	if not statuses.has_all(["focus","qi_seal","scorch"]): return _fail("新增状态ID不完整")
	var school_ids: Dictionary = {}
	for item in raw.schools:
		if not _keys(item,["id","name","identity","core_forms","deck"],["id","name","identity","core_forms","deck"]): return false
		for key in ["id","name","identity"]:
			if not _text(item[key]): return _fail("流派文本不合法")
		if school_ids.has(item.id) or item.id == "tingfeng": return _fail("流派ID重复")
		if not item.core_forms is Array or item.core_forms.size() != 2 or item.core_forms[0] == item.core_forms[1]: return _fail("每门流派必须具有两个不同核心式")
		for id in item.core_forms:
			if not _text(id): return _fail("核心式引用不合法")
		if not _keys(item.deck,["cards"],["cards"]) or not item.deck.cards is Array: return _fail("流派牌组不合法")
		school_ids[item.id] = true
		schools.append(item.duplicate(true))
	for item in raw.cards:
		if not _valid_form(item,school_ids) or forms.has(item.id) or _base_form_ids.has(item.id): return _fail("核心式定义不合法或重复")
		forms[item.id] = _normalize_form(item)
	for school in schools:
		for id in school.core_forms:
			if not forms.has(id) or forms[id].school_id != school.id: return _fail("流派核心式引用不合法")
		var seen: Dictionary = {}
		var total: int = 0
		for entry in school.deck.cards:
			if not _keys(entry,["card_id","count"],["card_id","count"]) or not _text(entry.card_id) or not _number(entry.count,1,12): return _fail("流派牌组条目不合法")
			if seen.has(entry.card_id) or _generated_only_ids.has(str(entry.card_id)) or (not _base_form_ids.has(entry.card_id) and entry.card_id not in school.core_forms): return _fail("流派牌组引用重复、衍生卡或跨门派")
			seen[entry.card_id] = true
			total += int(entry.count)
		if total != 12 or not seen.has_all(school.core_forms): return _fail("流派牌组须含两核心式、合计12张")
	for id in forms:
		var owner: Dictionary = get_school(forms[id].school_id)
		if id not in owner.core_forms: return _fail("核心式未归属流派")
	var combo_ids: Dictionary = {}
	for item in raw.combos:
		if not _valid_combo(item) or combo_ids.has(item.id): return _fail("连携定义不合法或重复")
		combo_ids[item.id] = true
		combos.append(item.duplicate(true))
	return true

func _valid_status(item: Variant) -> bool:
	if not _keys(item,["id","name","public","stack_limit","expiry"],["id","name","public","stack_limit","expiry"]): return false
	if not _text(item.id) or not _text(item.name) or not item.public is bool or not _number(item.stack_limit,1,2): return false
	if not _keys(item.expiry,["kind","duration"],["kind","duration"]): return false
	return item.expiry.kind == "global_ticks_after_apply" and _number(item.expiry.duration,1)

func _valid_form(item: Variant, school_ids: Dictionary) -> bool:
	if not _keys(item,["id","name","school_id","tags","threat_level","usages"],["id","name","school_id","tags","threat_level","usages"]): return false
	if not _text(item.id) or not _text(item.name) or not school_ids.has(item.school_id) or item.threat_level not in ["LOW","NORMAL","MEDIUM","HIGH"]: return false
	if not item.tags is Array or not item.usages is Array or item.usages.is_empty(): return false
	for tag in item.tags:
		if not _text(tag): return false
	var usage_ids: Dictionary = {}
	for usage in item.usages:
		if not _valid_usage(usage) or usage_ids.has(usage.id): return false
		usage_ids[usage.id] = true
	return true

func _valid_usage(usage: Variant) -> bool:
	if not _keys(usage,["id","name","timing","cost","target","effects","attack_profile","once_per_action"],["id","name","timing","cost","target","effects"]): return false
	if not _text(usage.id) or not _text(usage.name) or usage.timing not in ["ACTION","ATTACK_REACTION","DEFENSE_REACTION"]: return false
	if not _keys(usage.cost,["qi","hp"],["qi"]): return false
	for cost in usage.cost.values():
		if not _number(cost): return false
	if usage.has("once_per_action") and not usage.once_per_action is bool: return false
	if not _keys(usage.target,["kind","min_distance","max_distance","line_of_sight"],["kind"]) or usage.target.kind not in TARGETS: return false
	for key in ["min_distance","max_distance"]:
		if usage.target.has(key) and not _number(usage.target[key],1): return false
	if usage.target.has("line_of_sight") and not usage.target.line_of_sight is bool: return false
	if usage.target.kind in ["enemy_actor","reachable_cell"] and not usage.target.has("max_distance"): return false
	if usage.target.get("min_distance",1) > usage.target.get("max_distance",1): return false
	if usage.has("attack_profile"):
		if not _keys(usage.attack_profile,["route","break_bonus"],["route","break_bonus"]): return false
		if usage.attack_profile.route not in ROUTES or not _number(usage.attack_profile.break_bonus): return false
	if not usage.effects is Array or usage.effects.is_empty(): return false
	var roots: int = 0
	var conditions: int = 0
	for effect in usage.effects:
		if not _valid_effect(effect): return false
		if effect.type == "deal_damage": roots += 1
		if effect.type in ["damage_if_status","damage_if_shield","damage_if_low_hp"]: conditions += 1
	if roots > 1 or conditions > 1 or (conditions > 0 and roots != 1): return false
	if roots == 1 and (usage.timing != "ACTION" or usage.target.kind != "enemy_actor" or not usage.has("attack_profile")): return false
	if usage.target.kind == "enemy_actor" and roots != 1: return false
	if usage.has("attack_profile") and roots != 1: return false
	return true

func _valid_effect(effect: Variant, depth: int = 0) -> bool:
	if depth > 6 or not effect is Dictionary or effect.get("type") not in EFFECTS: return false
	var allowed: Array = ["type"]
	var required: Array = ["type"]
	match str(effect.type):
		"deal_damage", "gain_qi":
			allowed += ["amount"]
			required += ["amount"]
		"add_shield":
			allowed += ["amount","expires_after_global_ticks"]
			required += ["amount","expires_after_global_ticks"]
		"apply_status":
			allowed += ["status_id","stacks","target"]
			required += ["status_id","stacks","target"]
		"move":
			allowed += ["max_distance"]
			required += ["max_distance"]
		"force_move":
			allowed += ["target","direction","distance"]
			required += ["target","direction","distance"]
		"modify_pending_damage": allowed += ["flat_delta","reduction"]
		"contest_intercept":
			allowed += ["parry_bonus","route_bonus","success_margin","failure_margin","on_success","on_contested","on_failure"]
			required += ["parry_bonus","route_bonus","success_margin","failure_margin","on_success","on_contested","on_failure"]
		"on_attack_hit", "on_attack_miss":
			allowed += ["effects"]
			required += ["effects"]
		"draw_cards":
			allowed += ["count"]
			required += ["count"]
		"damage_if_status":
			allowed += ["status_id","damage_per_stack","consume_on_hit"]
			required += ["status_id","damage_per_stack","consume_on_hit"]
		"damage_if_shield":
			allowed += ["bonus"]
			required += ["bonus"]
		"damage_if_low_hp":
			allowed += ["threshold_percent","bonus"]
			required += ["threshold_percent","bonus"]
	if not _keys(effect,allowed,required): return false
	if effect.type == "modify_pending_damage" and not effect.has("flat_delta") and not effect.has("reduction"): return false
	if depth > 0 and effect.type in ["damage_if_status","damage_if_shield","damage_if_low_hp"]: return false
	for key in ["amount","bonus","damage_per_stack"]:
		if effect.has(key) and not _number(effect[key]): return false
	for key in ["max_distance","distance","stacks","count","expires_after_global_ticks"]:
		if effect.has(key) and not _number(effect[key],1): return false
	for key in ["flat_delta","reduction","parry_bonus","success_margin","failure_margin"]:
		if effect.has(key) and not _number(effect[key],-10000): return false
	if effect.has("threshold_percent") and not _number(effect.threshold_percent,0,100,false): return false
	if effect.has("consume_on_hit") and not effect.consume_on_hit is bool: return false
	if effect.has("target") and effect.target not in EFFECT_TARGETS: return false
	if effect.has("status_id") and not _all_status_ids.has(effect.status_id): return false
	if effect.type == "force_move" and effect.direction not in ["away","toward"]: return false
	if effect.has("route_bonus"):
		if not _keys(effect.route_bonus,ROUTES): return false
		for n in effect.route_bonus.values():
			if not _number(n,-10000): return false
	for key in CHILD_EFFECTS:
		if not effect.has(key): continue
		if not effect[key] is Array: return false
		for child in effect[key]:
			if not _valid_effect(child,depth+1): return false
	return true

func _normalize_effect(effect: Dictionary) -> Dictionary:
	var result: Dictionary = effect.duplicate(true)
	if result.get("target","") == "opponent": result.target = "enemy"
	if result.type == "force_move":
		result.max_distance = result.distance
		result.erase("distance")
		result.direction = "away_from_attacker" if result.direction == "away" else "towards_attacker"
	for key in CHILD_EFFECTS:
		if not result.has(key): continue
		for i in range(result[key].size()): result[key][i] = _normalize_effect(result[key][i])
	return result

func _normalize_form(item: Dictionary) -> Dictionary:
	var result: Dictionary = item.duplicate(true)
	for usage in result.usages:
		var condition: Dictionary = {}
		var effects: Array = []
		for effect in usage.effects:
			match str(effect.type):
				"damage_if_shield": condition = {"if_self_shield_gt":0,"bonus":effect.bonus}
				"damage_if_low_hp": condition = {"if_self_hp_pct_lt_after_cost":float(effect.threshold_percent)/100.0,"bonus":effect.bonus}
				"damage_if_status": condition = {"bonus_per_target_status":effect.status_id,"bonus_each":effect.damage_per_stack,"consume_on_hit":effect.status_id if effect.consume_on_hit else ""}
				_: effects.append(_normalize_effect(effect))
		if not condition.is_empty():
			for effect in effects:
				if effect.type == "deal_damage": effect.conditional_bonus = condition.duplicate(true)
		usage.effects = effects
		if usage.target.kind == "enemy_actor":
			usage.attack_profile.range = int(usage.target.max_distance)
			if usage.target.get("line_of_sight",false):
				usage.target.line_mode = "orthogonal"
				usage.target.blocks_actors = true
	return result

func _valid_combo(item: Variant) -> bool:
	if not _keys(item,["id","name","mode","sequence","scope","max_activations_per_action","effects"],["id","name","mode","sequence","scope","max_activations_per_action","effects"]): return false
	if not _text(item.id) or not _text(item.name) or item.mode != "ordered_previous_resolved_active_attack" or item.scope != "same_actor_action" or not _number(item.max_activations_per_action,1): return false
	if not item.sequence is Array or item.sequence.size() != 2 or not item.effects is Array or item.effects.is_empty(): return false
	var school: String = ""
	for reference in item.sequence:
		if not _keys(reference,["card_id","usage_id"],["card_id","usage_id"]) or not _usage_exists(reference.card_id,reference.usage_id): return false
		var form: Dictionary = forms[reference.card_id]
		if not school.is_empty() and school != form.school_id: return false
		school = form.school_id
		var active: bool = false
		for usage in form.usages:
			if usage.id != reference.usage_id or usage.timing != "ACTION": continue
			for effect in usage.effects:
				if effect.type == "deal_damage": active = true
		if not active: return false
	for effect in item.effects:
		if not _valid_effect(effect) or effect.type != "modify_pending_damage": return false
	return true
