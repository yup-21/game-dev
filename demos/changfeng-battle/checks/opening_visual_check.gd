extends RefCounted
## Windowed presentation smoke check. Captures actual Godot frames, not mock screenshots.
const Illustration = preload("res://scripts/hd2d_illustrated_factory.gd")
func _wait(view, frames: int = 3) -> void:
	for _i in range(frames): await view.get_tree().process_frame

func _capture(view, name: String) -> bool:
	var folder: String=ProjectSettings.globalize_path("res://captures")
	var err: int=DirAccess.make_dir_recursive_absolute(folder)
	if err!=OK: return false
	await _wait(view,2)
	var image: Image=view.get_viewport().get_texture().get_image()
	return image.save_png(folder.path_join(name))==OK

func _fail(view, message: String) -> void:
	push_error("OPENING_VISUAL_CHECK_FAILED: "+message)
	view.get_tree().quit(1)

func run(view) -> void:
	await _wait(view)
	if view.story.phase!="menu" or view.buttons.size()<5:
		_fail(view,"title screen/menu buttons")
		return
	var has_hd2d: bool = false
	for button in view.buttons:
		if str(button.action) == "hd2d":
			has_hd2d = true
	if not has_hd2d:
		_fail(view,"illustrated battle preview entry missing")
		return
	var sheet: Texture2D = Illustration.make_sheet(false)
	if sheet == null or sheet.get_size() != Vector2i(960, 800):
		_fail(view,"opening character illustration sheet not loaded")
		return
	if not await _capture(view,"opening-title.png"):
		_fail(view,"title screenshot write")
		return
	view._enter_new_game()
	await _wait(view)
	if view.story.phase!="cinematic" or view.story.current_beat().is_empty():
		_fail(view,"new game cinematic")
		return
	if not await _capture(view,"opening-cinematic.png"):
		_fail(view,"cinematic screenshot write")
		return
	view.story.skip_cinematic()
	view.player_pos=Vector2(1037,570)
	await _wait(view)
	if not await _capture(view,"opening-explore.png"):
		_fail(view,"exploration screenshot write")
		return
	view._start_dialogue()
	await _wait(view)
	if view.story.phase!="dialogue" or view.story.current_dialogue().is_empty():
		_fail(view,"escort dialogue")
		return
	view.visible_characters=float(view.story.current_dialogue().text.length())
	if not await _capture(view,"opening-dialogue.png"):
		_fail(view,"dialogue screenshot write")
		return
	for _i in range(16):
		if view.story.phase!="dialogue": break
		var node: Dictionary=view.story.current_dialogue()
		if not node.get("choices",[]).is_empty():
			view.visible_characters=float(node.text.length())
			if not await _capture(view,"opening-choice.png"):
				_fail(view,"choice screenshot write")
				return
			view._dialogue_choice(0)
		else:
			view.visible_characters=float(node.text.length())
			view._dialogue_next()
	if view.story.phase!="complete" or not view.story.obtained_fragment:
		_fail(view,"dialogue fails to reach final fragment")
		return
	if not await _capture(view,"opening-complete.png"):
		_fail(view,"chapter completion screenshot write")
		return
	print("OPENING_VISUAL_CHECK_PASS title/cinematic/explore/dialogue/choice/complete")
	view.get_tree().quit(0)
