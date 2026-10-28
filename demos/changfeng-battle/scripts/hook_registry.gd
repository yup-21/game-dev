extends RefCounted
## Hooks receive copies and return commands; execution belongs to CombatResolver.
var rules: Array = []
var validators: Dictionary = {}
var modifiers: Dictionary = {}

func clear() -> void:
	rules.clear()
	validators.clear()
	modifiers.clear()

func register_rule(id: String, owner: int, on_event: String, effects: Array, priority: int = 100, min_amount: float = 0.0, options: Dictionary = {}) -> void:
	for r in rules:
		if r.id==id and int(r.owner)==owner: return
	rules.append({"id":id,"owner":owner,"event":on_event,"effects":effects.duplicate(true),"priority":priority,"min_amount":min_amount,"options":options.duplicate(true)})
	rules.sort_custom(func(a,b):
		if a.priority!=b.priority: return a.priority<b.priority
		if a.owner!=b.owner: return a.owner<b.owner
		return str(a.id)<str(b.id))

func register_validator(id: String, callback: Callable) -> void:
	validators[id]=callback

func register_modifier(id: String, callback: Callable) -> void:
	modifiers[id]=callback

func validate(context: Dictionary) -> Dictionary:
	var keys: Array=validators.keys()
	keys.sort()
	for id in keys:
		var r=validators[id].call(context.duplicate(true))
		if not r is Dictionary or not bool(r.get("success",false)):
			return {"success":false,"message":str(r.get("message","Hook 拒绝行动")) if r is Dictionary else "校验 Hook 返回无效结果"}
	return {"success":true}

func modify(context: Dictionary, values: Dictionary, timing: String) -> Dictionary:
	var result: Dictionary=values.duplicate(true)
	result["valid"]=true
	var keys: Array=modifiers.keys()
	keys.sort()
	for id in keys:
		var r=modifiers[id].call(context.duplicate(true),result.duplicate(true),timing)
		if not r is Dictionary:
			result.valid=false
			return result
		for key in values:
			var v=r.get(key,result[key])
			if not (v is int or v is float) or not is_finite(float(v)) or float(v)!=float(int(v)) or absf(float(v))>100000000:
				result.valid=false
				return result
			result[key]=int(v)
	return result

func collect(event: Dictionary, context: Dictionary) -> Array:
	var commands: Array=[]
	for rule in rules:
		if rule.event!=event.get("type","") or int(rule.owner)!=int(event.get("actor_id",-1)): continue
		if float(event.get("amount",0))<float(rule.min_amount): continue
		commands.append({"hook_id":rule.id,"source":rule.owner,"effects":rule.effects.duplicate(true),"options":rule.options.duplicate(true),"event_id":event.get("event_id",""),"context":context.duplicate(true)})
	return commands
