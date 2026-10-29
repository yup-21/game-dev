extends RefCounted
## One authoritative inventory record per actor, independent of UI and BattleModel.
## Bag stores stack rows; equipment owns transferred items, with no duplicated quantities.
const MAX_SLOTS: int=9
const MAX_STACKS: int=120
const MAX_TOTAL_ITEMS: int=1000
var slots: Array=[]
var definitions: Dictionary={}
var load_error: String=""

func _init(path: String="res://data/items.json") -> void:
	if not FileAccess.file_exists(path):
		load_error="Missing item catalog"
		return
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema_version")!=1 or not data.get("items") is Array or not data.get("slots") is Array:
		load_error="Invalid item catalog"
		return
	slots=data.slots.duplicate()
	if slots.size()!=MAX_SLOTS: load_error="Expected nine equipment slots"; return
	var seen: Dictionary={}
	for slot in slots:
		if not slot is String or seen.has(slot): load_error="Duplicate equipment slot"; return
		seen[slot]=true
	for item in data.items:
		if not item is Dictionary or not item.get("id") is String or definitions.has(item.id): load_error="Invalid item ID"; return
		if item.get("kind") not in ["equipment","consumable","material","quest"]: load_error="Unknown item kind"; return
		if not item.get("weight") is float and not item.get("weight") is int: load_error="Invalid weight"; return
		if float(item.weight)<0.0 or float(item.weight)>1000.0: load_error="Invalid weight"; return
		if not item.get("stack_limit") is int or int(item.stack_limit)<1 or int(item.stack_limit)>999: load_error="Invalid stack limit"; return
		if item.kind=="equipment" and str(item.get("slot","")) not in slots+["accessory"]: load_error="Invalid equip slot"; return
		if not item.get("modifiers",[]) is Array: load_error="Invalid modifiers"; return
		if item.kind=="consumable":
			var effect: Variant=item.get("use",{})
			if not effect is Dictionary or effect.get("kind","") not in ["heal_hp","restore_qi","remove_status"]: load_error="Invalid consumable effect"; return
			if effect.kind in ["heal_hp","restore_qi"] and (not effect.get("amount") is int or int(effect.amount)<1 or int(effect.amount)>100): load_error="Invalid healing amount"; return
			if effect.kind=="remove_status" and (not effect.get("status_id") is String or str(effect.status_id).is_empty()): load_error="Invalid status effect"; return
		definitions[str(item.id)]=item.duplicate(true)

func item(id: String) -> Dictionary:
	return definitions.get(id,{}).duplicate(true)

func empty_record(capacity: int=18,max_weight: float=45.0) -> Dictionary:
	var worn: Dictionary={}
	for slot in slots: worn[str(slot)]=""
	return {"capacity":capacity,"max_weight":max_weight,"stacks":[],"equipment":worn}

func starter_record() -> Dictionary:
	var record: Dictionary=empty_record()
	for entry in [
		["old_saber",1],["traveler_coat",1],["soft_boots",1],
		["healing_powder",3],["qi_pill",2],["meridian_ointment",1],
		["iron_sword",1],["jade_pendant",1],["iron_ore",2]]:
		if not add(record,str(entry[0]),int(entry[1])): push_error("Starter inventory overflow")
	return record

func _compatible(slot: String,item_id: String) -> bool:
	if not definitions.has(item_id) or str(definitions[item_id].kind)!="equipment": return false
	var placement: String=str(definitions[item_id].get("slot",""))
	return placement==slot or (placement=="accessory" and slot in ["accessory_1","accessory_2"])

func valid(record: Variant) -> bool:
	if not record is Dictionary or not record.get("capacity") is int: return false
	if int(record.capacity)<1 or int(record.capacity)>MAX_STACKS: return false
	if not record.get("max_weight") is float and not record.get("max_weight") is int: return false
	if float(record.max_weight)<0.0 or float(record.max_weight)>10000.0: return false
	if not record.get("stacks") is Array or not record.get("equipment") is Dictionary: return false
	if record.stacks.size()>int(record.capacity): return false
	var equipped: Dictionary=record.equipment
	if equipped.size()!=slots.size(): return false
	for slot in equipped:
		if slot not in slots or not equipped[slot] is String: return false
		var name: String=str(equipped[slot])
		if not name.is_empty() and not _compatible(str(slot),name): return false
	if not str(equipped.get("offhand","")).is_empty() and bool(definitions.get(str(equipped.get("weapon","")) ,{}).get("two_handed",false)): return false
	var total: int=0
	for stack in record.stacks:
		if not stack is Dictionary or stack.size()!=2 or not stack.get("id") is String or not stack.get("count") is int: return false
		if not definitions.has(str(stack.id)) or int(stack.count)<1 or int(stack.count)>int(definitions[str(stack.id)].stack_limit): return false
		total+=int(stack.count)
	for slot in slots:
		if not str(equipped[slot]).is_empty(): total+=1
	return total<=MAX_TOTAL_ITEMS and weight(record)<=float(record.max_weight)+0.0001

func weight(record: Dictionary) -> float:
	var total: float=0.0
	for row in record.get("stacks",[]):
		if row is Dictionary:
			total+=float(definitions.get(str(row.get("id","")),{}).get("weight",0))*int(row.get("count",0))
	for id in record.get("equipment",{}).values():
		if not str(id).is_empty(): total+=float(definitions.get(str(id),{}).get("weight",0))
	return snappedf(total,0.0001)

func count(record: Dictionary,id: String) -> int:
	var amount: int=0
	for row in record.get("stacks",[]):
		if str(row.get("id",""))==id: amount+=int(row.count)
	return amount

func add(record: Dictionary,id: String,amount: int=1) -> bool:
	if not definitions.has(id) or amount<1 or amount>MAX_TOTAL_ITEMS or not valid(record): return false
	var tmp: Dictionary=record.duplicate(true)
	var left: int=amount
	for row in tmp.stacks:
		if str(row.id)!=id: continue
		var take: int=mini(left,int(definitions[id].stack_limit)-int(row.count))
		row.count+=take
		left-=take
	for _i in range(MAX_STACKS):
		if left==0: break
		if tmp.stacks.size()>=int(tmp.capacity): return false
		var n: int=mini(left,int(definitions[id].stack_limit))
		tmp.stacks.append({"id":id,"count":n})
		left-=n
	if left!=0 or not valid(tmp): return false
	record.clear()
	record.merge(tmp,true)
	return true

func remove(record: Dictionary,id: String,amount: int=1) -> bool:
	if amount<1 or count(record,id)<amount or not valid(record): return false
	var tmp: Dictionary=record.duplicate(true)
	var left: int=amount
	for index in range(tmp.stacks.size()-1,-1,-1):
		var row: Dictionary=tmp.stacks[index]
		if str(row.id)!=id: continue
		var take: int=mini(left,int(row.count))
		row.count=int(row.count)-take
		left-=take
		if int(row.count)==0: tmp.stacks.remove_at(index)
	if left!=0 or not valid(tmp): return false
	record.clear()
	record.merge(tmp,true)
	return true

func equip(record: Dictionary,id: String,slot: String) -> bool:
	if not _compatible(slot,id) or not valid(record) or count(record,id)<1: return false
	var tmp: Dictionary=record.duplicate(true)
	if not remove(tmp,id): return false
	if bool(definitions[id].get("two_handed",false)) and not str(tmp.equipment.offhand).is_empty(): return false
	if slot=="offhand" and bool(definitions.get(str(tmp.equipment.weapon),{}).get("two_handed",false)): return false
	var current: String=str(tmp.equipment[slot])
	tmp.equipment[slot]=id
	if not current.is_empty() and not add(tmp,current): return false
	if not valid(tmp): return false
	record.clear()
	record.merge(tmp,true)
	return true

func unequip(record: Dictionary,slot: String) -> bool:
	if slot not in slots or not valid(record): return false
	var id: String=str(record.equipment[slot])
	if id.is_empty(): return false
	var tmp: Dictionary=record.duplicate(true)
	tmp.equipment[slot]=""
	if not add(tmp,id): return false
	record.clear()
	record.merge(tmp,true)
	return true

func equipment_modifiers(record: Dictionary) -> Array:
	var result: Array=[]
	if not valid(record): return result
	for slot in slots:
		var id: String=str(record.equipment[slot])
		if id.is_empty(): continue
		for m in definitions[id].get("modifiers",[]):
			result.append(m.duplicate(true))
	return result

func usable(record: Dictionary,id: String,actor=null,statuses=null) -> bool:
	if not valid(record) or count(record,id)<1: return false
	var definition: Dictionary=item(id)
	if definition.get("kind","")!="consumable": return false
	var effect: Dictionary=definition.get("use",{})
	match str(effect.get("kind","")):
		"heal_hp": return actor!=null and actor.hp_u>0 and actor.hp_u<actor.max_hp_u
		"restore_qi": return actor!=null and actor.hp_u>0 and actor.qi_u<actor.max_qi_u
		"remove_status": return actor!=null and statuses!=null and statuses.has(actor.id,str(effect.status_id))
	return false

func consume(record: Dictionary,id: String,actor,statuses) -> bool:
	if not usable(record,id,actor,statuses): return false
	var effect: Dictionary=definitions[id].use
	if not remove(record,id): return false
	match str(effect.kind):
		"heal_hp": actor.hp_u=mini(actor.max_hp_u,actor.hp_u+int(effect.amount)*10000)
		"restore_qi": actor.qi_u=mini(actor.max_qi_u,actor.qi_u+int(effect.amount)*10000)
		"remove_status":
			var name: String=str(effect.status_id)
			var value: int=statuses.stacks(actor.id,name)
			statuses.remove(actor.id,name)
			if value>1: statuses.add(actor.id,name,value-1)
	return true
