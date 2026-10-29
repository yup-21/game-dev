extends RefCounted
## Safe, deterministic predicates. Unknown conditions fail closed.
var statuses

func _init(status_system) -> void:
	statuses=status_system

func allows(actor, condition: Variant, context: Dictionary = {}) -> bool:
	if condition==null or condition=={}: return true
	if not condition is Dictionary: return false
	if condition.has("all"):
		if not condition.all is Array: return false
		for item in condition.all:
			if not allows(actor,item,context): return false
		return true
	if condition.has("any"):
		if not condition.any is Array or condition.any.is_empty(): return false
		for item in condition.any:
			if allows(actor,item,context): return true
		return false
	if condition.has("not"): return not allows(actor,condition["not"],context)
	for key in condition:
		var value=condition[key]
		match str(key):
			"before_first_attack":
				if not value is bool or (value and not actor.attack_history.is_empty()): return false
			"after_active_attack":
				if not value is bool or (value and actor.attack_history.is_empty()): return false
			"has_status", "self_status":
				if not value is String or not statuses.has(actor.id,str(value)): return false
			"target_status":
				if not value is String or not context.has("target_id") or not statuses.has(int(context.target_id),str(value)): return false
			"qi_at_least":
				if not (value is int or value is float) or float(value)<0 or actor.qi<float(value): return false
			"same_action_continuation":
				if not value is bool or bool(context.get("same_action",false))!=value: return false
			_:
				return false
	return true
