extends RefCounted
## Item instances have stable UIDs; stackable consumables are counted separately.
## Consuming returns declarative effects. The authoritative command layer must
## execute them; inventory never mutates BattleState directly.
const ItemCatalog = preload("res://scripts/item_catalog.gd")
const Modifiers = preload("res://scripts/stat_modifier_system.gd")
var catalog
var stacks: Dictionary = {}
var instances: Dictionary = {}
var equipped: Dictionary = {}
var next_uid: int = 1
var last_added_uids: Array = []

func _init(source = null) -> void:
    catalog = ItemCatalog.new() if source == null else source

func add(definition_id: String, count: int = 1) -> bool:
    last_added_uids.clear()
    var item: Dictionary = catalog.get_item(definition_id)
    if item.is_empty() or count < 1 or count > 99: return false
    if item.kind == "consumable":
        var updated: int = int(stacks.get(definition_id,0)) + count
        if updated > int(item.stack_limit): return false
        stacks[definition_id] = updated
        return true
    for i in range(count):
        var uid: String = "item:%d" % next_uid
        next_uid += 1
        instances[uid] = {"definition_id":definition_id,"affixes":[]}
        last_added_uids.append(uid)
    return true

func equip(uid: String) -> bool:
    var instance: Dictionary = instances.get(uid,{})
    var item: Dictionary = catalog.get_item(str(instance.get("definition_id","")))
    if item.is_empty() or item.kind != "equipment": return false
    equipped[str(item.slot)] = uid
    return true

func unequip(slot: String) -> bool:
    if not equipped.has(slot): return false
    equipped.erase(slot)
    return true

func consume(definition_id: String, count: int = 1) -> Dictionary:
    var item: Dictionary = catalog.get_item(definition_id)
    if item.is_empty() or item.kind != "consumable" or count < 1 or count > int(stacks.get(definition_id,0)):
        return {"ok":false,"effects":[]}
    var remaining: int = int(stacks[definition_id]) - count
    if remaining == 0: stacks.erase(definition_id)
    else: stacks[definition_id] = remaining
    return {"ok":true,"effects":item.effects.duplicate(true),"count":count}


## Gear affixes are attached to an instance, never to the shared item template.
func _valid_affixes(item: Dictionary, ids: Variant) -> bool:
    if not ids is Array: return false
    if ids.size() > int(item.get("max_affixes",0)): return false
    var seen: Dictionary = {}
    for id in ids:
        if not id is String or seen.has(id) or not item.get("affix_pool",[]).has(id):
            return false
        var affix: Dictionary = catalog.affixes.get_affix(str(id))
        if affix.is_empty() or not affix.allowed_slots.has(str(item.slot)):
            return false
        seen[id] = true
    return true

func set_affixes(uid: String, ids: Array) -> bool:
    var instance: Dictionary = instances.get(uid,{})
    var item: Dictionary = catalog.get_item(str(instance.get("definition_id","")))
    if item.is_empty() or item.kind != "equipment" or not _valid_affixes(item,ids):
        return false
    instances[uid]["affixes"] = ids.duplicate(true)
    return true

## Deterministic rolls let map rewards or crafting use their own authoritative seed.
## This method is intentionally outside combat and charges no currency/material.
func reroll_affixes(uid: String, seed: int) -> bool:
    var instance: Dictionary = instances.get(uid,{})
    var item: Dictionary = catalog.get_item(str(instance.get("definition_id","")))
    if item.is_empty() or item.kind != "equipment": return false
    var pool: Array = item.get("affix_pool",[]).duplicate(true)
    var amount: int = int(item.get("max_affixes",0))
    if amount == 0: return false
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    var rolled: Array = []
    for _i in range(amount):
        rolled.append(pool.pop_at(rng.randi_range(0,pool.size()-1)))
    return set_affixes(uid,rolled)

func equipment_affixes() -> Dictionary:
    var result: Dictionary = {}
    for slot in equipped:
        var uid: String = str(equipped[slot])
        var record: Dictionary = instances.get(uid,{})
        var ids: Array = record.get("affixes",[]).duplicate(true)
        var names: Array = []
        for id in ids:
            names.append(str(catalog.affixes.get_affix(str(id)).get("name",id)))
        result[slot] = {"uid":uid,"definition_id":str(record.get("definition_id","")),
            "affixes":ids,"affix_names":names}
    return result

func available_consumables() -> Array:
    var result: Array = []
    var ids: Array = stacks.keys()
    ids.sort()
    for id in ids:
        var definition: Dictionary = catalog.get_item(str(id))
        if not definition.is_empty() and definition.kind == "consumable":
            result.append({"item_id":str(id),"name":str(definition.name),"count":int(stacks[id])})
    return result

func equipment_definitions() -> Dictionary:
    var result: Dictionary = {}
    for slot in equipped:
        var uid: String = str(equipped[slot])
        result[slot] = str(instances.get(uid,{}).get("definition_id",""))
    return result

func modifier_sources() -> Dictionary:
    var sources: Dictionary = {}
    for slot in equipped:
        var uid: String = str(equipped[slot])
        var item: Dictionary = catalog.get_item(str(instances.get(uid,{}).get("definition_id","")))
        if not item.is_empty() and item.kind == "equipment":
            sources["equipment:" + str(slot)] = item.modifiers.duplicate(true)
            var record: Dictionary = instances.get(uid,{})
            for affix_id in record.get("affixes",[]):
                var affix: Dictionary = catalog.affixes.get_affix(str(affix_id))
                if not affix.is_empty():
                    sources["affix:%s:%s:%s" % [str(slot),uid,str(affix_id)]] = affix.modifiers.duplicate(true)
    return sources

func snapshot() -> Dictionary:
    return {"schema_version":1,"stacks":stacks.duplicate(true),
        "instances":instances.duplicate(true),"equipped":equipped.duplicate(true),
        "next_uid":next_uid}

func restore(data: Variant) -> bool:
    if not data is Dictionary or data.get("schema_version") != 1: return false
    if not data.get("stacks") is Dictionary or not data.get("instances") is Dictionary or not data.get("equipped") is Dictionary:
        return false
    if not Modifiers._whole(data.get("next_uid"),1,2147483647): return false
    var normalized_stacks: Dictionary = {}
    for id in data.stacks:
        var definition: Dictionary = catalog.get_item(str(id))
        if definition.is_empty() or definition.kind != "consumable": return false
        if not Modifiers._whole(data.stacks[id],1,int(definition.stack_limit)): return false
        normalized_stacks[id] = int(data.stacks[id])
    var highest_uid: int = 0
    var normalized_instances: Dictionary = {}
    for uid in data.instances:
        if not uid is String or not str(uid).begins_with("item:") or not data.instances[uid] is Dictionary: return false
        var sequence: String = str(uid).trim_prefix("item:")
        if not sequence.is_valid_int() or int(sequence) < 1: return false
        highest_uid = maxi(highest_uid,int(sequence))
        var record: Dictionary = data.instances[uid]
        for key in record:
            if key not in ["definition_id","affixes"]: return false
        var definition: Dictionary = catalog.get_item(str(record.get("definition_id","")))
        if definition.is_empty() or definition.kind != "equipment": return false
        var rolled: Variant = record.get("affixes",[])
        if not _valid_affixes(definition,rolled): return false
        normalized_instances[uid] = {"definition_id":str(record.definition_id),"affixes":rolled.duplicate(true)}
    if int(data.next_uid) <= highest_uid: return false
    var seen: Dictionary = {}
    for slot in data.equipped:
        var uid: String = str(data.equipped[slot])
        if not data.instances.has(uid) or seen.has(uid): return false
        var definition: Dictionary = catalog.get_item(str(data.instances[uid].get("definition_id","")))
        if str(definition.get("slot","")) != str(slot): return false
        seen[uid] = true
    stacks = normalized_stacks
    instances = normalized_instances
    equipped = data.equipped.duplicate(true)
    next_uid = int(data.next_uid)
    last_added_uids.clear()
    return true
