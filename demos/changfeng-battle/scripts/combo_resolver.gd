extends RefCounted
var cards
var statuses
func _init(c,status_system) -> void:
	cards=c
	statuses=status_system

func declaration(actor,definition_id: String,usage_id: String) -> Dictionary:
	if actor.attack_history.is_empty(): return {}
	var prev: Dictionary=actor.attack_history.back()
	for combo in cards.combos:
		if combo.get("mode","")!="ordered_previous_resolved_active_attack" or actor.combo_used.has(combo.id): continue
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
		if combo.get("mode","")!="on_qualified_hit" or actor.combo_used.has(combo.id): continue
		if combo.get("attack_card_id")!=attack.get("definition_id") or combo.get("attack_usage_id")!=attack.get("usage_id"): continue
		if not statuses.has(int(attack.defender_id),str(combo.get("target_has_status",""))): continue
		return combo.duplicate(true)
	return {}
