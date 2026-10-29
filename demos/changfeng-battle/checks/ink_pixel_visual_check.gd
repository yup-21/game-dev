extends SceneTree
## Windowed regression: real canvas drawing and mouse input against legal party actions.
## godot --path demos/changfeng-battle --script res://checks/ink_pixel_visual_check.gd
## Optional user argument: --capture-dir=res://captures/ink-pixel

class RenderProbe:
	extends "res://scripts/ink_pixel_art.gd"
	var board_characters: Dictionary = {}
	var poses: Dictionary = {}
	var effects: Dictionary = {}

	func character(v: CanvasItem, foot: Vector2, variant: int, t: float, pose: String = "idle", scale_factor: float = 3.0, flip: bool = false, tint: Color = Color.WHITE, facing: int = -1) -> void:
		if scale_factor >= 3.0:
			board_characters[variant] = true
			poses["%d:%s" % [variant, pose]] = true
		super.character(v, foot, variant, t, pose, scale_factor, flip, tint, facing)

	func effect(v: CanvasItem, center: Vector2, kind: String, progress: float, scale_factor: float = 1.0) -> void:
		effects[kind] = true
		super.effect(v, center, kind, progress, scale_factor)

var view
var probe = RenderProbe.new()
var capture_dir: String = "res://captures/ink-pixel"
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.substr("--capture-dir=".length())
	call_deferred("_run")

func check(ok: bool, title: String) -> bool:
	if ok:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		push_error("INK_PIXEL_VISUAL_CHECK: " + title)
		call_deferred("_finish")
	return ok

func _frames(count: int = 2) -> void:
	for _i in range(count):
		view.queue_redraw()
		await process_frame

func _click(point: Vector2) -> void:
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = point
		event.global_position = point
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()

func _button(action: String) -> Dictionary:
	for button in view.buttons:
		if str(button.get("action", "")) == action: return button
	return {}

func _cue(kind: String, source: int, target: int) -> bool:
	for entry in view.cue:
		if str(entry.kind) == kind and int(entry.source_id) == source and int(entry.target_id) == target: return true
	return false

func _capture(name: String) -> bool:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if not check(not image.is_empty(), name + " has a rendered framebuffer"): return false
	var path: String = ProjectSettings.globalize_path(capture_dir).path_join(name + ".png")
	var result: Error = image.save_png(path)
	print("INK_PIXEL_CAPTURE: ", path)
	return check(result == OK, name + " screenshot saved")

func _run() -> void:
	if not check(DisplayServer.get_name() != "headless", "visual check has a windowed renderer"): return
	root.size = Vector2i(1600, 1000)
	var directory: String = ProjectSettings.globalize_path(capture_dir)
	if not check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory is writable"): return
	var scene = load("res://party_battle.tscn")
	if not check(scene is PackedScene, "party scene resolves"): return
	view = scene.instantiate()
	root.add_child(view)
	# Only wall-clock presentation and automatic decisions stop. Mouse input stays live.
	view.set_process(false)
	view.pixel = probe
	await _frames(3)
	if not check(view.model.state.outcome == "playing" and view.snap.actors.size() == 6, "party initializes six combatants"): return
	if not check(view.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "party keeps crisp nearest-neighbor sprites"): return
	var all_drawn: bool = probe.board_characters.size() == 6
	for actor_id in range(6): all_drawn = all_drawn and probe.board_characters.has(actor_id)
	if not check(all_drawn, "all six character variants reach the real board renderer"): return
	if not await _capture("ink-pixel-party-initial"): return
	# A real non-targeted command first establishes event-driven guard feedback.
	var guard: Dictionary = _button("BASIC_GUARD")
	if not check(not guard.is_empty() and view._human_turn(), "manual guard command is clickable"): return
	var revision: int = int(view.model.state.revision)
	await _click(guard.rect.get_center())
	if not check(view.model.state.revision == revision + 1 and view.model.state.get_actor(0).shield_u > 0, "mouse guard submits an authoritative action"): return
	if not check(_cue("guard", 0, 0) and probe.poses.has("0:guard") and probe.effects.has("guard"), "real SHIELD event draws guard pose and effect"): return
	if not await _capture("ink-pixel-party-guard"): return
	view.model.acknowledge_animation(view.model.state.animation_ticket)
	# Arrange adjacent opponents; requests and all interaction still use the live rules.
	view.model.state.get_actor(0).cell = Vector2i(7, 4)
	view.model.state.get_actor(1).cell = Vector2i(8, 4)
	view._sync()
	await _frames()
	var attack: Dictionary = _button("BASIC_ATTACK")
	if not check(not attack.is_empty(), "adjacent opponent exposes a legal attack command"): return
	revision = int(view.model.state.revision)
	await _click(attack.rect.get_center())
	if not check(view.selected_key == "BASIC_ATTACK" and view.model.state.revision == revision, "mouse group selection waits for a map target"): return
	var targets: Array = view._candidates()
	if not check(not targets.is_empty() and int(targets[0].get("target_id", -1)) == 1, "selected command projects its authoritative opponent target"): return
	if not await _capture("ink-pixel-party-target"): return
	probe.poses.clear()
	probe.effects.clear()
	await _click(view.cell_to_screen(view.model.state.get_actor(1).cell))
	if not check(view.model.state.revision == revision + 1 and view.model.state.mode == "CLASH" and int(view.model.state.attack.defender_id) == 1, "mouse target submits the legal attack"): return
	if not check(_cue("attack", 0, 1) and probe.poses.has("0:attack") and probe.effects.has("attack"), "real attack event draws attacker pose and target feedback"): return
	if not await _capture("ink-pixel-party-attack"): return
	await _finish()

func _finish() -> void:
	if is_instance_valid(view):
		view.queue_free()
		view = null
	await process_frame
	print("INK_PIXEL_VISUAL_CHECK_PASS: %d checks, six actors, mouse guard and targeted attack" % passed if failed == 0 else "INK_PIXEL_VISUAL_CHECK_FAIL: %d failures" % failed)
	quit(0 if failed == 0 else 1)
