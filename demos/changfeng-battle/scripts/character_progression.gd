extends RefCounted
## Persistent character training; never writes temporary buffs into growth points.
const STATS=["STR","AGI","CON","MND"]
const MAX_GROWTH: int=90

func create_record() -> Dictionary:
	return {"growth":{"STR":0,"AGI":0,"CON":0,"MND":0},"unspent_points":0,
		"earned_points":0,"experience":0}

func valid(record: Variant) -> bool:
	if not record is Dictionary: return false
	if not record.get("growth",{}) is Dictionary: return false
	for key in record.get("growth",{}):
		if key not in STATS: return false
		var n: Variant=record.growth[key]
		if not n is int or int(n)<0 or int(n)>MAX_GROWTH: return false
	var earned: Variant=record.get("earned_points",0)
	var unspent: Variant=record.get("unspent_points",0)
	if not earned is int or not unspent is int or int(unspent)<0 or int(earned)<0: return false
	var spent: int=0
	for n in record.growth.values(): spent+=int(n)
	return spent+int(unspent)<=int(earned) and int(earned)<=1000

func configure(actor,record: Variant,attributes) -> bool:
	if not valid(record): return false
	actor.progression=record.duplicate(true)
	for key in STATS:
		actor.attributes[key]=clampi(int(actor.base_attributes.get(key,10))+int(actor.progression.growth.get(key,0)),1,100)
	attributes.recalculate(actor,null)
	return true

func earn(actor,points: int,experience: int=0) -> bool:
	if points<0 or points>50 or experience<0 or experience>100000: return false
	actor.progression.earned_points=int(actor.progression.get("earned_points",0))+points
	actor.progression.unspent_points=int(actor.progression.get("unspent_points",0))+points
	actor.progression.experience=int(actor.progression.get("experience",0))+experience
	return true

func allocate(actor,stat: String,amount: int,attributes,states) -> bool:
	if stat not in STATS or amount<1 or amount>20: return false
	if int(actor.progression.get("unspent_points",0))<amount: return false
	if int(actor.base_attributes.get(stat,10))+int(actor.progression.growth.get(stat,0))+amount>100: return false
	actor.progression.growth[stat]=int(actor.progression.growth.get(stat,0))+amount
	actor.progression.unspent_points=int(actor.progression.unspent_points)-amount
	actor.attributes[stat]=int(actor.base_attributes.get(stat,10))+int(actor.progression.growth[stat])
	attributes.recalculate(actor,states)
	return true

func export_record(actor) -> Dictionary:
	return actor.progression.duplicate(true)

func allocate_record(record: Dictionary,base: Dictionary,stat: String,amount: int=1) -> bool:
	if not valid(record) or stat not in STATS or amount<1 or amount>20: return false
	if int(record.get("unspent_points",0))<amount: return false
	if int(base.get(stat,10))+int(record.growth.get(stat,0))+amount>100: return false
	record.growth[stat]=int(record.growth.get(stat,0))+amount
	record.unspent_points=int(record.unspent_points)-amount
	return true
