extends RefCounted
## Read-only, bounded condition evaluation. Unknown predicates fail closed.
const MAX_DEPTH = 8

func allows(condition: Variant, actor, context: Dictionary = {}, depth: int = 0) -> bool:
	if depth > MAX_DEPTH or not condition is Dictionary: return false
	if condition.is_empty(): return true
	if condition.has("all"):
		if condition.size() != 1 or not condition.all is Array: return false
		for part in condition.all:
			if not allows(part, actor, context, depth + 1): return false
		return true
	if condition.has("any"):
		if condition.size() != 1 or not condition.any is Array or condition.any.is_empty(): return false
		for part in condition.any:
			if allows(part, actor, context, depth + 1): return true
		return false
	if condition.has("not"):
		return condition.size() == 1 and not allows(condition["not"], actor, context, depth + 1)
	var value = condition.get("value")
	match str(condition.get("type", "")):
		"timing": return value is String and value == context.get("timing", "")
		"qi_at_least": return (value is int or value is float) and float(actor.qi_u) >= float(value) * 10000.0
		"has_status": return value is String and actor.statuses.has(value)
		"attribute_at_least":
			return condition.get("stat") is String and (value is int or value is float) and float(actor.attributes.get(condition.stat, -999)) >= float(value)
		"technique_node":
			var id: String = str(condition.get("technique_id", ""))
			return value is String and actor.technique_states.has(id) and str(actor.technique_states[id].get("node", "")) == value
		"previous_attack_hit":
			return value is bool and not actor.attack_history.is_empty() and bool(actor.attack_history.back().get("hit", false)) == value
		_: return false
