extends RefCounted
var state
var cards
var statuses
var refresh_seen: Dictionary = {}
func _init(s,c,status_system) -> void:
	state=s
	cards=c
	statuses=status_system

func refresh_intel(target_id: int, hand_refresh: bool = true) -> void:
	var target=state.get_actor(target_id)
	if target==null: return
	for observer in state.actors:
		if observer.id==target_id: continue
		var known: Dictionary=state.knowledge[observer.id]
		for uid in known.keys():
			if not target.hand.has(uid): known.erase(uid)
		if statuses.has(target_id,"hand_exposed"):
			for uid in target.hand: known[uid]=cards.instances[uid].definition_id
			continue
		if not hand_refresh: continue
		var key: String="%d:%d" % [observer.id,target_id]
		var stamp: String=str(target.hand_generation)
		if refresh_seen.get(key,"")==stamp: continue
		refresh_seen[key]=stamp
		var skill: int=int(observer.passives.insight)
		if skill<=int(target.passives.conceal): continue
		var budget: int=target.hand.size() if skill>=2 else 1
		for uid in target.hand:
			if known.has(uid): continue
			known[uid]=cards.instances[uid].definition_id
			budget-=1
			if budget<=0: break

func actor_view(actor, observer_id: int) -> Dictionary:
	var out: Dictionary=actor.public_data()
	out["observed_hand"]=[]
	out["danger"]=""
	if actor.id==observer_id:
		out["passives"]=actor.passives.duplicate(true)
		out["attack_history"]=actor.attack_history.duplicate(true)
	for uid in actor.hand:
		var known: bool=actor.id==observer_id or statuses.has(actor.id,"hand_exposed") or state.knowledge.get(observer_id,{}).has(uid)
		var entry: Dictionary={"known":known}
		var d: Dictionary=cards.canonical_definition(uid)
		if known: entry.merge({"uid":uid,"definition_id":d.id,"card_id":d.id,"name":d.name})
		out.observed_hand.append(entry)
		if d.get("threat_level","")=="HIGH": out.danger="危"
	var viewer=state.get_actor(observer_id)
	if actor.id!=observer_id and viewer!=null and int(actor.passives.conceal)>0 and int(actor.passives.conceal)>=int(viewer.passives.insight) and not statuses.has(actor.id,"hand_exposed"):
		out.danger="?"
	return out
