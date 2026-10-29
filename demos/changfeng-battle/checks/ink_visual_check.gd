extends RefCounted
## Real Godot canvas smoke test and reproducible screenshots for the presentation PR.
## Execute: godot --path demos/changfeng-battle -- --ink-visual-check

func _fail(view, message: String) -> void:
	push_error("INK_VISUAL_CHECK: "+message)
	view.get_tree().quit(1)

func _frames(view, count: int = 2) -> void:
	for _i in range(count): await view.get_tree().process_frame

func _find_action(view, kind: String) -> Dictionary:
	for action in view.model.legal_actions(0):
		if str(action.get("kind",""))==kind: return action
	return {}

func run(view) -> void:
	view.started=true
	view.next_decision=1.0e30
	view._sync()
	await _frames(view,3)
	if view.snap.terrain.size()!=150 or view.snap.actors.size()!=2:
		_fail(view,"battle grid or actor projection changed")
		return
	if view.art==null:
		_fail(view,"procedural presentation module not connected")
		return
	if view.buttons.is_empty():
		_fail(view,"interactive UI surfaces not drawn")
		return
	await view._capture("ink-action.png")
	# Exercise the same authoritative attack request and event stream as the game.
	view.model.state.actors[0].cell=Vector2i(7,4)
	view.model.state.actors[1].cell=Vector2i(8,4)
	view.model.state.actors[0].qi_u=60000
	view._sync()
	var attack: Dictionary=_find_action(view,"BASIC_ATTACK")
	if attack.is_empty():
		_fail(view,"expected attack was not legal")
		return
	var result: Dictionary=view.model.submit(attack)
	if not bool(result.get("success",false)):
		_fail(view,"attack was rejected")
		return
	view._consume(result)
	if view.combat_cues.is_empty():
		_fail(view,"attack event did not produce a presentation cue")
		return
	await _frames(view,2)
	await view._capture("ink-attack.png")
	# A learned stage must expose a real clickable skill-tray action, not a fake card.
	view.model.reset(2026,0,"tingfeng",{
		"technique_catalog_path":"res://checks/fixtures/technique_graph.json",
		"techniques":{0:{"test_chain":3}}
	})
	view.model.state.actors[0].cell=Vector2i(7,4)
	view.model.state.actors[1].cell=Vector2i(8,4)
	view.model.state.actors[0].qi_u=60000
	view.presentation_left=0.0
	view.combat_cues.clear()
	view._sync()
	await _frames(view,2)
	var has_ability_button: bool=false
	for button in view.buttons:
		if str(button.get("action",""))=="ability_slot:0": has_ability_button=true
	if not has_ability_button:
		_fail(view,"equipped stage does not appear in skill tray")
		return
	await view._capture("ink-ability-tray.png")
	view._button_action("ability_slot:0")
	if view.mode!="ability":
		_fail(view,"stage button did not open target selection")
		return
	view._click(view.cell_to_screen(Vector2i(8,4)))
	if view.snap.phase!="CLASH":
		_fail(view,"selected stage did not submit a legal attack")
		return
	print("INK_VISUAL_CHECK_PASS: art, HUD, ability tray, attack feedback")
	view.get_tree().quit(0)
