extends SceneTree
const Policy = preload("res://scripts/enemy_ai.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		push_error("FAIL: " + title)

func play(uid: String, usage: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"kind": "PLAY_CARD", "actor_id": 0, "card_uid": uid, "usage_id": usage}
	result.merge(extra)
	return result

func card(uid: String, definition_id: String, usages: Array) -> Dictionary:
	return {"uid": uid, "definition_id": definition_id, "usages": usages}

func context() -> Dictionary:
	var terrain: Dictionary = {}
	for x in range(15):
		for y in range(10): terrain[Vector2i(x, y)] = "grass"
	return {"battle_id": "policy-fixture", "revision": 1, "action_no": 1, "observer_id": 0, "phase": "ACTION", "reaction": "NONE", "terrain": terrain,
		"actors": [{"id": 0, "team_id": 0, "cell": Vector2i(6, 4), "hp": 20.0, "max_hp": 20.0, "qi": 3.0, "max_qi": 6.0, "shield": 0.0, "attributes": {}, "attack_history": []}, {"id": 1, "team_id": 1, "cell": Vector2i(7, 4), "hp": 20.0, "shield": 0.0, "attributes": {}, "observed_hand": [{"known": false}]}], "hand": [], "legal_actions": []}

func response(defender: bool = true) -> Dictionary:
	var c: Dictionary = context()
	c.phase = "CLASH"
	c.reaction = "DEFENSE" if defender else "ATTACK"
	c.attack = {"attacker_id": 1 if defender else 0, "defender_id": 0 if defender else 1, "base_damage": 5, "attack_bonus": 0, "defense_reduction": 0, "route": "thrust", "break_bonus": 0, "target_cell": Vector2i(6, 4) if defender else Vector2i(7, 4), "affected_cells": [Vector2i(6, 4) if defender else Vector2i(7, 4)]}
	c.clash = {"stack": []}
	c.legal_actions = [{"kind": "PASS_REACTION", "actor_id": 0}]
	return c

func run_tests() -> void:
	var policy = Policy.new()
	var c: Dictionary = context()
	c.hand = [card("p", "tf_probe", [{"id": "probe", "cost": {"qi": 1}, "effects": [{"type": "deal_damage", "amount": 2}]}, {"id": "follow", "cost": {"qi": 1}, "effects": [{"type": "deal_damage", "amount": 2}]}])]
	c.legal_actions = [play("p", "follow"), play("p", "probe"), {"kind": "END_ACTION", "actor_id": 0}]
	var before: String = var_to_str(c)
	var selected: Dictionary = policy.choose_action(c)
	check(selected.usage_id == "probe", "policy opens with probe when follow has no combo")
	check(var_to_str(c) == before and c.legal_actions.has(selected), "policy preserves visible input and returns legal action")
	selected.usage_id = "forged"
	check(policy.choose_action(c).usage_id == "probe", "policy returns independent copy and cached decision is stable")
	c.revision = 2
	c.actors[0].attack_history = [{"usage_id": "probe", "resolved": true}]
	check(policy.choose_action(c).usage_id == "follow", "policy follows own resolved probe for combo")
	c = context()
	c.actors[1].cell = Vector2i(9, 4)
	c.legal_actions = [{"kind": "MOVE", "actor_id": 0, "target_cell": Vector2i(5, 4)}, {"kind": "MOVE", "actor_id": 0, "target_cell": Vector2i(7, 4)}, {"kind": "END_ACTION", "actor_id": 0}]
	check(Policy.new().choose_action(c).get("target_cell") == Vector2i(7, 4), "policy moves toward opponent along legal board path")
	c = response()
	c.legal_actions.append(play("s", "evasion", {"target_cell": Vector2i(6, 5)}))
	check(Policy.new().choose_action(c).get("usage_id", "") == "evasion", "policy chooses legal landing outside locked footprint")
	c.attack.affected_cells.append(Vector2i(6, 5))
	check(Policy.new().choose_action(c).kind == "PASS_REACTION", "policy avoids futile evasion inside current coverage")
	c = response()
	c.legal_actions.append(play("g", "intercept"))
	check(Policy.new().choose_action(c).get("usage_id", "") == "intercept", "policy uses winning thrust intercept")
	c.attack.route = "crushing"
	c.attack.break_bonus = 2
	check(Policy.new().choose_action(c).kind == "PASS_REACTION", "policy avoids losing heavy intercept")
	c.legal_actions.append(play("g", "yield"))
	check(Policy.new().choose_action(c).get("usage_id", "") == "yield", "policy reduces heavy damage with yield")
	c = response(false)
	c.clash.stack = [{"link_id": 1, "actor_id": 1, "usage_id": "yield", "canceled": false}, {"link_id": 3, "actor_id": 1, "usage_id": "defense_counter", "canceled": false}]
	c.legal_actions.append(play("c", "attack_counter", {"link_id": 1}))
	c.legal_actions.append(play("c", "attack_counter", {"link_id": 3}))
	check(Policy.new().choose_action(c).get("link_id", -1) == 3, "policy counters most recent eligible LIFO link")
	c = response(false)
	c.clash.stack = [{"id": 1, "actor_id": 1, "usage_id": "evasion", "canceled": false}]
	c.legal_actions.append(play("c", "change"))
	check(Policy.new().choose_action(c).get("usage_id", "") == "change", "policy changes coverage after visible evasion response")
	c = context()
	c.legal_actions = [{"kind": "BASIC_ATTACK", "actor_id": 0}, {"kind": "END_ACTION", "actor_id": 0}]
	policy = Policy.new()
	for i in range(30):
		c.revision = i
		selected = policy.choose_action(c)
	check(selected.kind == "END_ACTION", "policy has hard per ACTION decision limit")
	c.action_no = 2
	c.revision += 1
	check(policy.choose_action(c).kind == "BASIC_ATTACK", "new ACTION resets policy decision budget")
	c.legal_actions = []
	check(policy.choose_action(c).is_empty(), "policy returns empty during automatic or terminal stages")
	print("RESULTS: %d PASS / %d FAIL - context-only tingfeng policy" % [passed, failed])
	quit(0 if failed == 0 else 1)
