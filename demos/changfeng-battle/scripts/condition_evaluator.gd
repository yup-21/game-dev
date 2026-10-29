extends RefCounted
## Shared, deterministic condition interpreter. No arbitrary code in JSON.
const MAX_DEPTH: int = 8
var statuses

func _init(status_system = null) -> void:
	statuses = status_system

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _has_status(actor, status_id: String) -> bool:
	if statuses != null: return statuses.has(actor.id, status_id)
	return actor.statuses.has(status_id)

func valid_spec(spec: Variant, depth: int = 0) -> bool:
	if depth > MAX_DEPTH or not spec is Dictionary: return false
	if spec.is_empty(): return true
	for combinator in ["all", "any"]:
		if spec.has(combinator):
			if spec.size() != 1 or not spec[combinator] is Array or spec[combinator].size() > 32: return false
			if combinator == "any" and spec[combinator].is_empty(): return false
			for item in spec[combinator]:
				if not valid_spec(item, depth + 1): return false
			return true
	if spec.has("not"):
		return spec.size() == 1 and valid_spec(spec["not"], depth + 1)
	if spec.has("type"):
		if not spec.type is String: return false
		var value: Variant = spec.get("value")
		match str(spec.type):
			"timing", "has_status", "self_status", "target_status", "previous_attack_tag", "technique_node":
				return value is String and (spec.type != "technique_node" or spec.get("technique_id") is String)
			"qi_at_least", "attribute_at_least":
				return _number(value) and float(value) >= 0 and (spec.type != "attribute_at_least" or spec.get("stat") in ["STR","AGI","CON","MND"])
			"previous_attack_hit", "same_action_continuation":
				return value is bool
			_: return false
	for key in spec:
		var value: Variant = spec[key]
		match str(key):
			"before_first_attack", "after_active_attack", "same_action_continuation", "previous_attack_hit":
				if not value is bool: return false
			"has_status", "self_status", "target_status", "previous_attack_tag", "timing":
				if not value is String: return false
			"qi_at_least":
				if not _number(value) or float(value) < 0: return false
			_:
				return false
	return true

func allows(actor, condition: Variant, context: Dictionary = {}, depth: int = 0) -> bool:
	if depth > MAX_DEPTH or not condition is Dictionary: return false
	if condition.is_empty(): return true
	if condition.has("all"):
		if condition.size() != 1 or not condition.all is Array: return false
		for item in condition.all:
			if not allows(actor, item, context, depth + 1): return false
		return true
	if condition.has("any"):
		if condition.size() != 1 or not condition.any is Array or condition.any.is_empty(): return false
		for item in condition.any:
			if allows(actor, item, context, depth + 1): return true
		return false
	if condition.has("not"):
		return condition.size() == 1 and not allows(actor, condition["not"], context, depth + 1)
	if condition.has("type"):
		if not valid_spec(condition): return false
		var value: Variant = condition.get("value")
		match str(condition.type):
			"timing": return value == context.get("timing", "")
			"has_status", "self_status": return _has_status(actor, str(value))
			"target_status":
				return context.has("target_id") and statuses != null and statuses.has(int(context.target_id), str(value))
			"qi_at_least": return actor.qi_u >= roundi(float(value) * 10000.0)
			"attribute_at_least": return float(actor.attributes.get(str(condition.stat), -1)) >= float(value)
			"technique_node":
				var id: String = str(condition.technique_id)
				return actor.technique_states.has(id) and str(actor.technique_states[id].get("node", "")) == str(value)
			"previous_attack_tag": return not actor.attack_history.is_empty() and value in actor.attack_history.back().get("tags", [])
			"previous_attack_hit": return not actor.attack_history.is_empty() and bool(actor.attack_history.back().get("hit", false)) == value
			"same_action_continuation": return bool(context.get("same_action", false)) == value
			_: return false
	if not valid_spec(condition): return false
	for key in condition:
		var value: Variant = condition[key]
		match str(key):
			"before_first_attack":
				if value and not actor.attack_history.is_empty(): return false
			"after_active_attack":
				if value and actor.attack_history.is_empty(): return false
			"has_status", "self_status":
				if not _has_status(actor, str(value)): return false
			"target_status":
				if not context.has("target_id") or statuses == null or not statuses.has(int(context.target_id), str(value)): return false
			"qi_at_least":
				if actor.qi_u < roundi(float(value) * 10000.0): return false
			"same_action_continuation":
				if bool(context.get("same_action", false)) != value: return false
			"previous_attack_hit":
				if actor.attack_history.is_empty() or bool(actor.attack_history.back().get("hit", false)) != value: return false
			"previous_attack_tag":
				if actor.attack_history.is_empty() or value not in actor.attack_history.back().get("tags", []): return false
			"timing":
				if value != context.get("timing", ""): return false
			_: return false
	return true
