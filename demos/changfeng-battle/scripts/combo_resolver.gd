extends RefCounted
var cards
var statuses
func _init(c,status_system) -> void:
	cards=c
	statuses=status_system

## A combo can be activated multiple times per actor action when authored so.
func _available(actor,combo: Dictionary) -> bool:
	var count: int = 0
	for used in actor.combo_used:
		if used == combo.id: count += 1
	return count < maxi(1,int(combo.get("max_activations_per_action",1)))

func declaration(actor,definition_id: String,usage_id: String) -> Dictionary:
	if actor.attack_history.is_empty(): return {}
	var prev: Dictionary=actor.attack_history.back()
	for combo in cards.combos:
		if combo.get("mode","")!="ordered_previous_resolved_active_attack" or not _available(actor,combo): continue
		var sequence: Array=combo.get("sequence",[])
		if sequence.size()!=2: continue
		if sequence[1].get("card_id")!=definition_id or sequence[1].get("usage_id")!=usage_id: continue
		if sequence[0].get("card_id")!=prev.get("definition_id") or sequence[0].get("usage_id")!=prev.get("usage_id"): continue
		if not prev.get("resolved",false) or prev.get("interrupted",false): continue
		if combo.get("require_hit",false) and not prev.get("hit",false): continue
		return combo.duplicate(true)
	return {}

func qualified_hit(actor,attack: Dictionary) -> Dictionary:
	for combo in cards.combos:
		if combo.get("mode","")!="on_qualified_hit" or not _available(actor,combo): continue
		if combo.get("attack_card_id")!=attack.get("definition_id") or combo.get("attack_usage_id")!=attack.get("usage_id"): continue
		var required_status: String=str(combo.get("target_has_status",""))
		if not required_status.is_empty() and not statuses.has(int(attack.defender_id),required_status): continue
		if combo.has("target_posture_at_least"):
			var defender=statuses.state.get_actor(int(attack.defender_id))
			if defender==null or int(defender.posture)<int(combo.target_posture_at_least): continue
		return combo.duplicate(true)
	return {}
