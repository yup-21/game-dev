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

func _damage(usage: Dictionary) -> float:
	var damage: float = float(usage.get("attack_profile", {}).get("base_damage", 0))
	for effect in usage.get("effects", []):
		if str(effect.get("type", "")) == "deal_damage": damage = maxf(damage, float(effect.get("amount", 0)))
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
	var damage: float = 1.0 if kind == "BASIC_ATTACK" else _damage(usage)
	if damage > 0:
		var cost: float = float(usage.get("cost", {}).get("qi", 1))
		if usage_id == "follow" and last_attack == "probe": damage += 1
		if usage_id == "expose" and _has_status(enemy, "opening"): damage += 2
		var score: float = 30.0 + damage * 3.0 - cost * 2.0
		if usage_id == "probe" and last_attack != "probe": score += 2
		if usage_id == "expose" and not _has_status(enemy, "hand_exposed"): score += 1
		if damage >= float(enemy.get("hp", 20)) + float(enemy.get("shield", 0)): score += 100
		return score
	if kind == "PITCH_CARD":
		# A real paid discard action; no policy-side resource or damage mutation.
		if float(own.get("qi", 0)) >= minf(float(own.get("max_qi", 6)), 4.0): return 0
		var card: Dictionary = _card(context, option)
		return 19.0 if str(card.get("definition_id", "")) in ["tf_change", "tf_step"] else 8.0
	if kind == "MOVE" or usage_id == "step":
		if not option.has("target_cell"): return 0
		var before: int = _distance_to_enemy(context, own.cell, enemy.cell, int(own.id))
		var after: int = _distance_to_enemy(context, option.target_cell, enemy.cell, int(own.id))
		if after < 0 or before == 0 or (before >= 0 and after >= before): return 0
		return 22.0 + float(before - after) * 2.0 - float(after) * 0.1 + (0.5 if usage_id == "step" else 0.0)
	if kind == "BASIC_GUARD" or usage_id == "guard":
		var near: bool = _distance_to_enemy(context, own.cell, enemy.cell, int(own.id)) <= 2
		if near and float(own.get("shield", 0)) < 2 and float(own.get("hp", 20)) < float(own.get("max_hp", 20)) * 0.55:
			return 12.0 if usage_id == "guard" else 3.0
	return 0

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
	var raw: float = maxf(0.0, float(attack.get("base_damage", 0)) + float(attack.get("attack_bonus", 0)) - float(attack.get("defense_reduction", 0)))
	var loss: float = maxf(0.0, raw - float(own.get("shield", 0)))
	var stack: Array = context.get("clash", {}).get("stack", [])
	if usage_id in ["attack_counter", "defense_counter"]:
		for link in stack:
			if int(link.get("link_id", link.get("id", -1))) == int(option.get("link_id", -2)) and not bool(link.get("canceled", false)):
				return 55.0 + float(link.get("link_id", link.get("id", 0))) * 0.01
	if defender:
		if loss <= 0: return 0
		if usage_id == "evasion" and option.has("target_cell"):
			var affected: Array = attack.get("affected_cells", [attack.get("target_cell", own.cell)])
			if not affected.has(option.target_cell): return 45.0 + loss
		if usage_id == "intercept":
			var attacker: Dictionary = _actor(context, int(attack.get("attacker_id", -1)))
			var d: Dictionary = own.get("attributes", {})
			var a: Dictionary = attacker.get("attributes", {})
			var parry: int = 10 + floori(0.5 * (float(d.get("MND", 10)) - 10) + 0.25 * (float(d.get("AGI", 10)) - 10)) + 1
			var breaker: int = 10 + floori(0.5 * (float(a.get("STR", 10)) - 10) + 0.25 * (float(a.get("AGI", 10)) - 10))
			var route: String = str(attack.get("route", "thrust"))
			parry += int({"thrust": 2, "sweep": 0, "crushing": -1}.get(route, 0))
			breaker += int(attack.get("break_bonus", 2 if route == "crushing" else 0))
			if parry - breaker >= 2: return 48.0 + loss
			if parry - breaker > -2: return 7.0
		if usage_id == "yield": return 32.0 + minf(3.0, loss)
	else:
		if usage_id == "change":
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
