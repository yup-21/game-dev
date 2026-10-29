extends RefCounted
## Proficiency is persistent; technique stage is a separate runtime state.
## Rank thresholds require explicit breakthroughs (no surprise auto-unlock).
const RANK_THRESHOLDS=[0,50,150,350,700]
const MAX_RANK: int=5
const MAX_XP: int=1000000
var catalog: Dictionary={}

func _init(path: String="res://data/martial_catalog.json") -> void:
	if not FileAccess.file_exists(path): return
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema_version")!=1 or not parsed.get("disciplines") is Array: return
	for entry in parsed.disciplines:
		if entry is Dictionary and entry.get("id") is String and entry.get("tiers") is Array and entry.get("traits",[]) is Array:
			catalog[str(entry.id)]=entry.duplicate(true)

func discipline(id: String) -> Dictionary:
	return catalog.get(id,{}).duplicate(true)

func modifiers(actor) -> Array:
	var results: Array=[]
	var ids: Array=actor.martial_progress.keys()
	ids.sort()
	for id in ids:
		if not catalog.has(id): continue
		var definition: Dictionary=catalog[id]
		var record: Dictionary=actor.martial_progress[id]
		for tier in definition.get("tiers",[]):
			if int(tier.get("rank",99))>int(record.rank): continue
			for item in tier.get("bonus",[]): results.append(item.duplicate(true))
		for choice in definition.get("traits",[]):
			if record.get("traits",[]).has(str(choice.id)):
				for item in choice.get("modifiers",[]): results.append(item.duplicate(true))
	return results

func unlock_trait_record(record: Dictionary,id: String,trait_id: String) -> bool:
	if not valid(record) or not catalog.has(id) or not record.traits.is_empty(): return false
	for choice in catalog[id].get("traits",[]):
		if str(choice.get("id",""))==trait_id and int(record.rank)>=int(choice.get("required_rank",4)):
			record.traits.append(trait_id)
			return true
	return false

func create_record(rank: int=1) -> Dictionary:
	return {"rank":clampi(rank,1,MAX_RANK),"xp":0,"traits":[]}

func valid(record: Variant) -> bool:
	if not record is Dictionary or not record.get("rank") is int or not record.get("xp") is int: return false
	if int(record.rank)<1 or int(record.rank)>MAX_RANK or int(record.xp)<0 or int(record.xp)>MAX_XP: return false
	if not record.get("traits",[]) is Array or record.traits.size()>16: return false
	for trait_name in record.traits:
		if not trait_name is String or str(trait_name).is_empty(): return false
	return true

func configure(actor,records: Dictionary) -> bool:
	for id in records:
		if not id is String or not valid(records[id]): return false
	actor.martial_progress=records.duplicate(true)
	return true

func learn(actor,id: String,rank: int=1) -> bool:
	if id.is_empty() or rank<1 or rank>MAX_RANK: return false
	if actor.martial_progress.has(id): return true
	actor.martial_progress[id]=create_record(rank)
	return true

func award(actor,id: String,xp: int) -> bool:
	if not actor.martial_progress.has(id) or xp<1 or xp>1000: return false
	var record: Dictionary=actor.martial_progress[id]
	record.xp=mini(MAX_XP,int(record.xp)+xp)
	return true

func can_breakthrough(actor,id: String) -> bool:
	if not actor.martial_progress.has(id): return false
	var record: Dictionary=actor.martial_progress[id]
	var current: int=int(record.rank)
	if current>=MAX_RANK: return false
	return int(record.xp)>=int(RANK_THRESHOLDS[current])

func breakthrough(actor,id: String) -> bool:
	if not can_breakthrough(actor,id): return false
	var record: Dictionary=actor.martial_progress[id]
	record.rank=int(record.rank)+1
	if actor.technique_states.has(id):
		actor.technique_states[id].rank=record.rank
	return true

func unlock_trait(actor,id: String,trait_id: String,required_rank: int=4) -> bool:
	if not actor.martial_progress.has(id) or trait_id.is_empty(): return false
	var record: Dictionary=actor.martial_progress[id]
	if int(record.rank)<required_rank: return false
	return unlock_trait_record(record,id,trait_id)

func export_records(actor) -> Dictionary:
	return actor.martial_progress.duplicate(true)

func breakthrough_record(record: Dictionary) -> bool:
	if not valid(record): return false
	var current: int=int(record.rank)
	if current>=MAX_RANK or int(record.xp)<int(RANK_THRESHOLDS[current]): return false
	record.rank=current+1
	return true
