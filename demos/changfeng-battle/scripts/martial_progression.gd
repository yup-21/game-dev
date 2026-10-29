extends RefCounted
## Proficiency is persistent; technique stage is a separate runtime state.
## Rank thresholds require explicit breakthroughs (no surprise auto-unlock).
const RANK_THRESHOLDS=[0,50,150,350,700]
const MAX_RANK: int=5
const MAX_XP: int=1000000

func create_record(rank: int=1) -> Dictionary:
	return {"rank":clampi(rank,1,MAX_RANK),"xp":0,"traits":[]}

func valid(record: Variant) -> bool:
	if not record is Dictionary or not record.get("rank") is int or not record.get("xp") is int: return false
	if int(record.rank)<1 or int(record.rank)>MAX_RANK or int(record.xp)<0 or int(record.xp)>MAX_XP: return false
	if not record.get("traits",[]) is Array or record.traits.size()>16: return false
	for trait in record.traits:
		if not trait is String or str(trait).is_empty(): return false
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
	if int(record.rank)<required_rank or record.traits.has(trait_id): return false
	record.traits.append(trait_id)
	record.traits.sort()
	return true

func export_records(actor) -> Dictionary:
	return actor.martial_progress.duplicate(true)
