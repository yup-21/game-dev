extends SceneTree
## Formal plot/scene transitions without requiring an AI-controlled battle outcome.
## The existing native-scene QA test separately covers actual four-zone walking.
const BattleModel = preload("res://scripts/battle_model.gd")

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("PROLOGUE_CHASE: " + label)

func exhaust_dialogue(scene: Node2D, choice_index: int = -1) -> void:
	for step in range(45):
		if not scene.dialogue_panel.visible:
			return
		var choices: Array = scene.story.available_choices(scene.session.flags)
		if not choices.is_empty():
			check(choice_index >= 0 and choice_index < choices.size(), "choice is available")
			if choice_index < 0 or choice_index >= choices.size():
				return
			scene._choose_formal_dialogue(choice_index)
		else:
			scene._advance_formal_dialogue()
	check(not scene.dialogue_panel.visible, "dialogue graph terminates")

func _run() -> void:
	var session: Node = root.get_node("GameSession")
	session.start_new_game()
	check(session.activate_prologue_chase(), "main menu can activate native chase")
	check(session.scene_for("prologue") == "res://scenes/prologue/prologue_exploration.tscn",
		"chapter router points to native four-zone exploration")
	var definition: Resource = load("res://data/native/stories/prologue_chase_story.tres")
	check(definition is WuxiaStoryDefinition and definition.to_record().dialogues.size() >= 20,
		"all playable dialogue nodes load as native Resource")
	for dialogue in definition.to_record().get("dialogues", []):
		var line: String = str(dialogue.get("text", ""))
		check(not line.contains("韩啸") and not line.contains("逆仙图录")
			and not line.contains("追兵要的是"),
			"prologue does not expose the commander, scroll title, or supposed treasure search")

	var scene: Node2D = load("res://scenes/prologue/prologue_exploration.tscn").instantiate()
	root.add_child(scene)
	check(scene.formal_mode and scene.current_zone.zone_id == "temple_hall",
		"formal play starts beside temple fire without activating QA ambush")
	for gate_name in ["ToCourtyard", "ToRoad"]:
		var gate: Marker2D = scene.current_zone.get_node("Exits/" + gate_name)
		scene.hero.position = gate.position
		check(scene.follow_portal(gate_name), "player follows gate " + gate_name)
	check(scene.current_zone.zone_id == "mountain_road", "reached the robbed escort cart")
	scene.hero.position = scene.current_zone.get_node("Landmarks/CartTraces").position
	check(scene.interact() and scene.dialogue_panel.visible, "cart opens rescue choice")
	exhaust_dialogue(scene, 1)
	check(session.prologue_stage == "failure" and scene.failure_panel.visible,
		"declining rescue results in explicit losing branch")
	scene._retry_roadside()
	check(session.prologue_stage == "roadside_retry" and scene.dialogue_panel.visible,
		"checkpoint returns to the moment of choice")
	exhaust_dialogue(scene, 0)
	check(session.prologue_stage == "healing" and scene.current_zone.zone_id == "temple_hall"
		and scene.escort_follower.visible, "rescue brings elder back to campfire")
	scene.hero.position = scene.current_zone.get_node("Landmarks/CampfireObservation").position
	check(scene.interact(), "healing triggered by campfire")
	exhaust_dialogue(scene)
	check(session.prologue_stage == "wave1_ready", "healing raises the first chase encounter")

	check(session.begin_prologue_wave(), "first two-scout encounter starts")
	check(session.encounter_options().get("combatants", []).size() == 3,
		"first fight is one hero against two anonymous scouts")
	check(session.encounter_options().get("passives", {}).get(0, {}).get("insight", -1) == 0,
		"insight is locked until the fragment awakens")
	var first_battle = BattleModel.new()
	first_battle.reset(session.encounter_seed(), 0, "tingfeng", session.encounter_options())
	check(first_battle.state.outcome == "playing" and first_battle.state.actors.size() == 3,
		"first scout formation is valid in the actual BattleModel")
	check(session.report_battle("victory", 0) and session.prologue_stage == "wave1_cleared",
		"first victory resumes native exploration")
	check(session.set_prologue_stage("wave2_ready"), "chase escalates on the mountain road")
	check(session.begin_prologue_wave(), "second three-scout encounter starts")
	check(session.encounter_options().get("combatants", []).size() == 4,
		"second wave has three scouts without exposing the boss")
	var second_battle = BattleModel.new()
	second_battle.reset(session.encounter_seed(), 0, "tingfeng", session.encounter_options())
	check(second_battle.state.outcome == "playing" and second_battle.state.actors.size() == 4,
		"second scout formation is valid in the actual BattleModel")
	check(session.report_battle("victory", 0) and session.prologue_stage == "wave2_cleared",
		"second victory unlocks trust and handover")

	check(scene._start_formal_dialogue("handover_open", "handover"), "elder's trust is earned after two wins")
	exhaust_dialogue(scene)
	check(session.prologue_stage == "lookout_ready" and session.flags.get("obtained_fragment", false)
		and session.items.get("unknown_fragment", 0) == 1,
		"elder leaves an unnamed fragment and stays to divert the search")
	scene._teleport_formal("broken_bridge", "FromRoad")
	scene.hero.position = scene.current_zone.get_node("StoryAnchors/FutureFerryTrailNotConnected").position
	check(scene.interact(), "ferry trail activates first encounter with the fragment")
	exhaust_dialogue(scene)
	check(session.flags.get("fragment_insight_unlocked", false)
		and session.prologue_stage == "lookout_battle", "fragment awakens against a lone lookout")
	check(session.encounter_options().get("combatants", []).size() == 2
		and session.encounter_options().get("passives", {}).get(0, {}).get("insight", -1) == 2,
		"native insight rank two reveals the lookout's current hand")
	var lookout_battle = BattleModel.new()
	lookout_battle.reset(session.encounter_seed(), 0, "tingfeng", session.encounter_options())
	check(lookout_battle.state.outcome == "playing" and lookout_battle.state.actors.size() == 2,
		"lookout encounter is accepted by the actual BattleModel")
	check(session.report_battle("victory", 0) and session.prologue_stage == "lookout_cleared",
		"lookout victory leaves no identifiable pursuer")
	check(scene.interact(), "player follows the creek toward Pingjiang")
	exhaust_dialogue(scene)
	check(session.flags.get("prologue_escaped", false) and session.prologue_stage == "escaped"
		and scene.story.phase == "complete", "prologue ends by escaping with an unresolved elder fate")
	if failures == 0:
		print("PROLOGUE_CHASE_FLOW_PASS: choice, retry, healing, 2+3 scouts, trust, fragment, insight, escape")
	quit(1 if failures else 0)
