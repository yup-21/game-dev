extends RefCounted
## Deterministic symmetric policy. Only the caller's permission-filtered context enters here.
const MAX_DECISIONS_PER_ACTION: int = 24
const MAX_DECISIONS_PER_TURN: int = MAX_DECISIONS_PER_ACTION
const DIRECTIONS: Array = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
var _usage: Dictionary = {}

func choose_action(context: Dictionary) -> Dictionary:
	var legal: Array = context.get("legal_actions", [])
	if legal.is_empty(): return {}
	var observer: int = int(context.get("observer_id", -1))
	var own: Dictionary = _actor(context, observer)
	if own.is_empty(): return {}
	var key: String = "%s:%d:%d" % [context.get("battle_id", ""), int(context.get("action_no", own.get("turns_started", 0))), observer]
	var record: Dictionary = _usage.get(observer, {})
	if str(record.get("key", "")) != key:
		record = {"key": key, "decisions": 0, "revision": -1, "fingerprint": 0, "action": {}}
	var fingerprint: int = context.hash()
	var revision: int = int(context.get("revision", -1))
	if revision == int(record.revision) and fingerprint == int(record.fingerprint) and legal.has(record.action):
		return record.action.duplicate(true)
	var clash: bool = str(context.get("phase", "")) == "CLASH" or str(context.get("reaction", "NONE")) != "NONE"
	var selected: Dictionary = _fallback(legal, clash)
	if int(record.decisions) < MAX_DECISIONS_PER_ACTION:
		var best_score: float = 0.0
		for option in legal:
			var score: float = _response_score(context, option) if clash else _action_score(context, option, record)
			if score > best_score:
				best_score = score
				selected = option
	if selected.is_empty(): return {}
	record.decisions = int(record.decisions) + 1
	record.revision = revision
	record.fingerprint = fingerprint
	record.action = selected.duplicate(true)
	_usage[observer] = record
	return selected.duplicate(true)

func _actor(context: Dictionary, actor_id: int) -> Dictionary:
	for actor in context.get("actors", []):
		if int(actor.get("id", -1)) == actor_id: return actor
	return {}

func _enemy(context: Dictionary) -> Dictionary:
	for actor in context.get("actors", []):
		if int(actor.get("id", -1)) != int(context.get("observer_id", -1)) and float(actor.get("hp", 0)) > 0: return actor
	return {}

func _card(context: Dictionary, option: Dictionary) -> Dictionary:
	var uid: String = str(option.get("card_uid", option.get("card_id", "")))
	for card in context.get("hand", []):
		if str(card.get("uid", card.get("card_id", ""))) == uid: return card
	return {}

func _usage_for(context: Dictionary, option: Dictionary) -> Dictionary:
	for usage in _card(context, option).get("usages", []):
		if str(usage.get("id", "")) == str(option.get("usage_id", "")): return usage
	return {}

func _damage(usage: Dictionary, own: Dictionary = {}, enemy: Dictionary = {}) -> float:
	var damage: float = float(usage.get("attack_profile", {}).get("base_damage", 0))
	for effect in usage.get("effects", []):
		if str(effect.get("type", "")) == "deal_damage":
			var amount: float = float(effect.get("amount", 0))
			var condition: Dictionary = effect.get("conditional_bonus", {})
			var qualifies: bool = true
			if condition.has("if_self_shield_gt"): qualifies = float(own.get("shield", 0)) > float(condition.if_self_shield_gt)
			if condition.has("if_target_status"): qualifies = qualifies and _has_status(enemy, str(condition.if_target_status))
			if condition.has("if_self_hp_pct_lt_after_cost"): qualifies = qualifies and (float(own.get("hp", 20)) - float(usage.get("cost", {}).get("hp", 0))) / maxf(1, float(own.get("max_hp", 20))) < float(condition.if_self_hp_pct_lt_after_cost)
			if qualifies:
				amount += float(condition.get("bonus", 0))
				if condition.has("bonus_per_target_status"): amount += _status_stacks(enemy, str(condition.bonus_per_target_status)) * float(condition.get("bonus_each", 0))
			damage = maxf(damage, amount)
	return damage

func _fallback(legal: Array, clash: bool) -> Dictionary:
	for option in legal:
		if str(option.get("kind", "")) == ("PASS_REACTION" if clash else "END_ACTION"): return option
	return {}

func _action_score(context: Dictionary, option: Dictionary, _record: Dictionary) -> float:
	var own: Dictionary = _actor(context, int(context.observer_id))
	var enemy: Dictionary = _enemy(context)
	if enemy.is_empty(): return 0
	var kind: String = str(option.get("kind", ""))
	var usage: Dictionary = _usage_for(context, option)
	var usage_id: String = str(option.get("usage_id", ""))
	var last_attack: String = ""
	var history: Array = own.get("attack_history", [])
	if not history.is_empty() and bool(history.back().get("resolved", false)):
		last_attack = str(history.back().get("usage_id", ""))
	var damage: float = 1.0 if kind == "BASIC_ATTACK" else _damage(usage, own, enemy)
	if damage > 0:
		var cost: float = float(usage.get("cost", {}).get("qi", 1))
		if usage_id == "follow" and last_attack == "probe": damage += 1
		if usage_id == "expose" and _has_status(enemy, "opening"): damage += 2
		var hp_cost: float = float(usage.get("cost", {}).get("hp", 0))
		if hp_cost > 0 and float(own.get("hp", 20)) - hp_cost <= 3 and damage < float(enemy.get("hp", 20)): return 1
		var score: float = 30.0 + damage * 3.0 - cost * 2.0 - hp_cost * 2.0
		score += _status_stacks(own, "focus") * 3.0
		if usage_id == "probe" and last_attack != "probe": score += 2
		if usage_id == "expose" and not _has_status(enemy, "hand_exposed"): score += 1
		if damage >= float(enemy.get("hp", 20)) + float(enemy.get("shield", 0)): score += 100
		return score
	if kind == "PITCH_CARD":
		# A real paid discard action; no policy-side resource or damage mutation.
		if float(own.get("qi", 0)) >= minf(float(own.get("max_qi", 6)), 4.0): return 0
		var card: Dictionary = _card(context, option)
		return 19.0 if str(card.get("definition_id", "")) in ["tf_change", "tf_step"] else 8.0
	if kind == "MOVE" or not _effect(usage, "move").is_empty() or usage_id == "step":
		if not option.has("target_cell"): return 0
		var before: int = _distance_to_position(context, own.cell, enemy.cell, int(own.id))
		var after: int = _distance_to_position(context, option.target_cell, enemy.cell, int(own.id))
		if after < 0 or before == 0 or (before >= 0 and after >= before): return 0
		return 22.0 + float(before - after) * 2.0 - float(after) * 0.1 + (0.5 if usage_id == "step" else 0.0)
	var qi_cost: float = float(usage.get("cost", {}).get("qi", 0))
	var hp_cost: float = float(usage.get("cost", {}).get("hp", 0))
	if hp_cost > 0 and float(own.get("hp", 20)) < maxf(8, hp_cost + 4): return 0
	var gain: Dictionary = _effect(usage, "gain_qi")
	var draw: Dictionary = _effect(usage, "draw_cards")
	var focus: Dictionary = _effect(usage, "apply_status")
	if not gain.is_empty() and float(own.get("qi", 0)) < float(own.get("max_qi", 6)) - 0.5:
		var net_gain: float = minf(float(gain.get("amount", 0)), float(own.get("max_qi", 6)) - float(own.get("qi", 0)) + qi_cost) - qi_cost
		if net_gain > 0: return 40.0 + net_gain * 2 - hp_cost * 3
	if not draw.is_empty() and context.get("hand", []).size() < 7 and float(own.get("qi", 0)) >= 2:
		return 25.0 + float(draw.get("count", 1)) - qi_cost - hp_cost * 2
	if str(focus.get("status_id", "")) == "focus" and _status_stacks(own, "focus") < 2 and float(own.get("qi", 0)) >= qi_cost + 1:
		return 41.0 + float(focus.get("stacks", 1)) - qi_cost
	if kind == "BASIC_GUARD" or not _effect(usage, "add_shield").is_empty() or usage_id == "guard":
		var near: bool = _distance_to_enemy(context, own.cell, enemy.cell, int(own.id)) <= 2
		if int(context.get("action_no", 0)) < 60 and near and float(own.get("shield", 0)) < 2 and float(own.get("hp", 20)) < float(own.get("max_hp", 20)) * 0.55:
			return 12.0 if usage_id == "guard" else 3.0
	return 0

func _effect(usage: Dictionary, effect_type: String) -> Dictionary:
	for effect in usage.get("effects", []):
		if str(effect.get("type", "")) == effect_type: return effect
	return {}

func _status_stacks(actor: Dictionary, status_id: String) -> int:
	var statuses = actor.get("statuses", {})
	if statuses is Dictionary:
		var entry = statuses.get(status_id, {})
		return int(entry.get("stacks", 1)) if entry is Dictionary and not entry.is_empty() else (1 if statuses.has(status_id) else 0)
	for entry in statuses:
		if entry is Dictionary and str(entry.get("id", entry.get("status_id", ""))) == status_id: return int(entry.get("stacks", 1))
	return 1 if _has_status(actor, status_id) else 0

func _distance_to_position(context: Dictionary, start: Vector2i, enemy: Vector2i, own_id: int) -> int:
	# Choose the range of the strongest card in the visible hand, including minimum range.
	var minimum: int = 1
	var maximum: int = 1
	var strongest: float = 1
	for card in context.get("hand", []):
		for usage in card.get("usages", []):
			if str(usage.get("timing", "ACTION")) != "ACTION": continue
			var damage: float = _damage(usage)
			if damage <= strongest: continue
			strongest = damage
			minimum = int(usage.get("target", {}).get("min_distance", 1))
			maximum = int(usage.get("target", {}).get("max_distance", usage.get("attack_profile", {}).get("range", 1)))
	if maximum <= 1: return _distance_to_enemy(context, start, enemy, own_id)
	var terrain: Dictionary = context.get("terrain", {})
	var frontier: Array = [start]
	var distances: Dictionary = {start: 0}
	var head: int = 0
	while head < frontier.size():
		var cell: Vector2i = frontier[head]
		head += 1
		var distance: int = absi(cell.x - enemy.x) + absi(cell.y - enemy.y)
		if distance >= minimum and distance <= maximum and (cell.x == enemy.x or cell.y == enemy.y):
			var step: Vector2i = Vector2i(signi(enemy.x - cell.x), signi(enemy.y - cell.y))
			var cursor: Vector2i = cell + step
			var clear: bool = true
			while cursor != enemy:
				if not terrain.has(cursor) or str(terrain[cursor]) in ["water", "rock", "bamboo"]:
					clear = false
					break
				cursor += step
			if clear: return int(distances[cell])
		for direction in DIRECTIONS:
			var next: Vector2i = cell + Vector2i(direction)
			if distances.has(next) or next == enemy or not terrain.has(next) or str(terrain[next]) in ["water", "rock", "bamboo"]: continue
			distances[next] = int(distances[cell]) + 1
			frontier.append(next)
	return -1

func _has_status(actor: Dictionary, status_id: String) -> bool:
	var statuses = actor.get("statuses", [])
	if statuses is Dictionary: return statuses.has(status_id)
	for status in statuses:
		if (status is String and status == status_id) or (status is Dictionary and str(status.get("id", status.get("status_id", ""))) == status_id): return true
	return false

func _response_score(context: Dictionary, option: Dictionary) -> float:
	if str(option.get("kind", "")) != "PLAY_CARD": return 0
	var attack: Dictionary = context.get("attack", {})
	if attack.is_empty(): return 0
	var own: Dictionary = _actor(context, int(context.observer_id))
	var defender: bool = int(attack.get("defender_id", -1)) == int(own.id)
	var usage_id: String = str(option.get("usage_id", ""))
	var usage: Dictionary = _usage_for(context, option)
	var raw: float = maxf(0.0, float(attack.get("base_damage", 0)) + float(attack.get("attack_bonus", 0)) - float(attack.get("defense_reduction", 0)))
	var loss: float = maxf(0.0, raw - float(own.get("shield", 0)))
	var stack: Array = context.get("clash", {}).get("stack", [])
	if usage_id in ["attack_counter", "defense_counter"] or not _effect(usage, "cancel_chain_link").is_empty():
		for link in stack:
			if int(link.get("link_id", link.get("id", -1))) == int(option.get("link_id", -2)) and not bool(link.get("canceled", false)):
				return 55.0 + float(link.get("link_id", link.get("id", 0))) * 0.01
	if defender:
		if loss <= 0: return 0
		if (usage_id == "evasion" or not _effect(usage, "move").is_empty()) and option.has("target_cell"):
			var affected: Array = attack.get("affected_cells", [attack.get("target_cell", own.cell)])
			if not affected.has(option.target_cell): return 45.0 + loss
		if usage_id == "intercept" or not _effect(usage, "contest_intercept").is_empty():
			var attacker: Dictionary = _actor(context, int(attack.get("attacker_id", -1)))
			var d: Dictionary = own.get("attributes", {})
			var a: Dictionary = attacker.get("attributes", {})
			var contest: Dictionary = _effect(usage, "contest_intercept")
			var parry: int = 10 + floori(0.5 * (float(d.get("MND", 10)) - 10) + 0.25 * (float(d.get("AGI", 10)) - 10)) + int(contest.get("parry_bonus", 1))
			var breaker: int = 10 + floori(0.5 * (float(a.get("STR", 10)) - 10) + 0.25 * (float(a.get("AGI", 10)) - 10))
			var route: String = str(attack.get("route", "thrust"))
			parry += int(contest.get("route_bonus", {"thrust": 2, "sweep": 0, "crushing": -1}).get(route, 0))
			breaker += int(attack.get("break_bonus", 2 if route == "crushing" else 0))
			if parry - breaker >= 2: return 48.0 + loss
			if parry - breaker > -2: return 7.0
		var modifier: Dictionary = _effect(usage, "modify_pending_damage")
		if usage_id == "yield" or float(modifier.get("flat_delta", 0)) < 0 or float(modifier.get("reduction", 0)) > 0: return 32.0 + minf(3.0, loss)
	else:
		var modifier: Dictionary = _effect(usage, "modify_pending_damage")
		if float(modifier.get("flat_delta", 0)) > 0 and float(own.get("hp", 20)) - float(usage.get("cost", {}).get("hp", 0)) > 3: return 22.0 + float(modifier.flat_delta)
		if usage_id == "change" or not _effect(usage, "modify_attack_area").is_empty():
			for link in stack:
				if str(link.get("usage_id", "")) == "evasion" and not bool(link.get("canceled", false)): return 40.0
			var target: Dictionary = _actor(context, int(attack.get("defender_id", -1)))
			if not attack.get("affected_cells", []).has(target.get("cell", Vector2i(-1, -1))): return 40.0
	return 0

func _distance_to_enemy(context: Dictionary, start: Vector2i, enemy: Vector2i, own_id: int) -> int:
	var terrain: Dictionary = context.get("terrain", {})
	var blocked: Dictionary = {}
	for actor in context.get("actors", []):
		if int(actor.get("id", -1)) != own_id and float(actor.get("hp", 0)) > 0: blocked[actor.cell] = true
	var frontier: Array = [start]
	var distances: Dictionary = {start: 0}
	var head: int = 0
	while head < frontier.size():
		var current: Vector2i = frontier[head]
		head += 1
		var distance: int = int(distances[current])
		if absi(current.x - enemy.x) + absi(current.y - enemy.y) == 1: return distance
		for direction in DIRECTIONS:
			var next: Vector2i = current + Vector2i(direction)
			if distances.has(next) or blocked.has(next) or not terrain.has(next) or str(terrain[next]) in ["water", "rock", "bamboo"]: continue
			distances[next] = distance + 1
			frontier.append(next)
	return -1
