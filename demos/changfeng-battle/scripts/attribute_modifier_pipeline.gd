extends RefCounted
## Single deterministic stat pipeline; growth is permanent, states are reversible.
const UNIT: int=10000
const BASE_STATS=["STR","AGI","CON","MND"]
const DERIVED_STATS=["max_hp","attack","defense","break_power","parry_power","max_qi_u","qi_regen_u_per_100","hp_regen_u_per_100","qi_cost_percent","charge_speed","move_budget"]
const LIMITS={"STR":[1,100],"AGI":[1,100],"CON":[1,100],"MND":[1,100],
	"max_hp":[1,500],"attack":[1,1000],"defense":[1,1000],
	"break_power":[0,1000],"parry_power":[0,1000],"max_qi_u":[10000,1000000],
	"qi_regen_u_per_100":[0,1000000],"hp_regen_u_per_100":[0,1000000],
	"qi_cost_percent":[1,500],"charge_speed":[1,1000],"move_budget":[1,20]}
var attributes

func _init(attribute_system) -> void:
	attributes=attribute_system

func _clamp(stat: String,value: float) -> int:
	var span: Array=LIMITS.get(stat,[0,1000000])
	return clampi(roundi(value),int(span[0]),int(span[1]))

func _apply(source: Dictionary,modifiers: Array,keys: Array) -> Dictionary:
	var result: Dictionary=source.duplicate(true)
	var flat: Dictionary={}
	var rate: Dictionary={}
	for modifier in modifiers:
		if not modifier is Dictionary: continue
		var key: String=str(modifier.get("stat",""))
		if key not in keys: continue
		var number: float=float(modifier.get("value",0))
		var op: String=str(modifier.get("op","flat"))
		if op=="flat": flat[key]=float(flat.get(key,0.0))+number
		elif op=="percent": rate[key]=float(rate.get(key,0.0))+number
	for key in keys:
		if not result.has(key): continue
		var value: float=float(result[key])+float(flat.get(key,0.0))
		result[key]=_clamp(str(key),value*(100.0+float(rate.get(key,0.0)))/100.0)
	return result

func collect(actor,states) -> Array:
	var entries: Array=[]
	var keys: Array=actor.statuses.keys()
	keys.sort()
	for status_id in keys:
		if not states.has(actor.id,str(status_id)): continue
		var definition: Dictionary=states.definition(str(status_id))
		var instance: Dictionary=actor.statuses[status_id]
		for index in range(definition.get("modifiers",[]).size()):
			var item: Dictionary=definition.modifiers[index].duplicate(true)
			item["value"]=float(item.value)*int(instance.get("stacks",1))
			entries.append({"source":str(status_id),"index":index,"modifier":item})
	entries.sort_custom(func(a,b):
		if a.source==b.source: return a.index<b.index
		return str(a.source)<str(b.source))
	var result: Array=[]
	for entry in entries: result.append(entry.modifier)
	return result

func recalculate(actor,states) -> void:
	var modifiers: Array=collect(actor,states)
	# Gear uses the same flat -> percent -> clamp semantics as states.
	for mod in actor.equipment_modifiers:
		modifiers.append(mod.duplicate(true))
	for mod in actor.martial_modifiers:
		modifiers.append(mod.duplicate(true))
	actor.effective_attributes=_apply(actor.attributes,modifiers,BASE_STATS)
	var permanent: Dictionary=attributes.derive(actor.attributes)
	actor.base_max_hp_u=int(permanent.max_hp)*UNIT
	var effective: Dictionary=attributes.derive(actor.effective_attributes)
	effective=_apply(effective,modifiers,DERIVED_STATS)
	actor.stats=effective
	actor.max_hp_u=int(effective.max_hp)*UNIT
	actor.max_qi_u=int(effective.max_qi_u)
	# Never heal on cap increase; preserve elapsed CTB gauge and fractional regen.
	actor.hp_u=mini(actor.hp_u,actor.max_hp_u)
	actor.qi_u=mini(actor.qi_u,actor.max_qi_u)
