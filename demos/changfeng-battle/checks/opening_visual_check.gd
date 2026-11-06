extends RefCounted
## Windowed presentation smoke check. Captures actual Godot frames, not mock screenshots.
func _wait(view, frames: int = 3) -> void:
	for _i in range(frames): await view.get_tree().process_frame

func _capture(view, name: String) -> bool:
	print("OPENING_RENDER_CAPTURE_BEGIN name=", name)
	var folder: String=ProjectSettings.globalize_path("res://captures")
	var err: int=DirAccess.make_dir_recursive_absolute(folder)
	if err!=OK: return false
	await _wait(view,2)
	var image: Image=view.get_viewport().get_texture().get_image()
	var saved: bool = image.save_png(folder.path_join(name))==OK
	print("OPENING_RENDER_CAPTURE_DONE name=",name," saved=",saved)
	return saved

## The previous screenshot smoke test only checked that a PNG existed.
## A fully WHITE first-act scene satisfied that check and shipped broken.
func _background_visible(view) -> bool:
    # Read the PNG we already captured; a second immediate GPU readback
    # from the same render frame may stall software/CI render backends.
    var image := Image.new()
    if image.load(ProjectSettings.globalize_path("res://captures/opening-explore.png")) != OK or image.is_empty():
        return false
    var scenic := 0
    for sample_y in [0.24, 0.41, 0.59, 0.72]:
        for sample_x in [0.13, 0.29, 0.45, 0.61, 0.78, 0.89]:
            var pixel: Color=image.get_pixel(
                mini(image.get_width()-1,int(float(image.get_width())*sample_x)),
                mini(image.get_height()-1,int(float(image.get_height())*sample_y)))
            if pixel.a>0.9 and minf(pixel.r,minf(pixel.g,pixel.b))<0.85:
                scenic+=1
    return scenic>=10

func _fail(view, message: String) -> void:
	push_error("OPENING_VISUAL_CHECK_FAILED: "+message)
	view.get_tree().quit(1)

func run(view) -> void:
	await _wait(view)
	var menu: Control = view.get_node("NativeMenuUI/MenuControls")
	var menu_actions: Array = []
	for node in menu.get_children():
		if node is Button:
			menu_actions.append(str(node.get_meta("action", "")))
	if view.story.phase != "menu" or menu_actions != [
			"start", "hd2d", "pingjiang_qa", "pingjiang_vertical_qa",
			"pingjiang_25d_qa", "pingjiang_south_gate_qa", "shen_house_qa",
			"pingjiang_exploration", "quit"]:
		_fail(view,"native title menu exposes all confirmed QA/test actions")
		return
	if view.player_sprite == null or view.escort_sprite == null:
		_fail(view,"story scene missing registered Sprite2D actors")
		return
	if not view.player_sprite.has_real_sprite or not view.escort_sprite.has_real_sprite:
		_fail(view,"character sprites cannot load")
		return
	if not view.player_sprite.body is Sprite2D or not view.escort_sprite.body is Sprite2D:
		_fail(view,"story characters must be genuine Sprite2D instances")
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
	if not view.characters_layer.visible or view.player_sprite.body.texture == null or view.escort_sprite.body.texture == null:
		_fail(view,"exploration must display both registered characters")
		return
	if not view.get_node("ExploreUI").visible or not view.get_node("ExploreUI/ExploreHUD/Prompt") is Label:
		_fail(view,"exploration HUD must be visible and editor-authored")
		return
	if not await _capture(view,"opening-explore.png"):
		_fail(view,"exploration screenshot write")
		return
	if not _background_visible(view):
		_fail(view,"first-act terrain is blank/white although screenshot file exists")
		return
	view._start_dialogue()
	await _wait(view)
	if view.story.phase!="dialogue" or view.story.current_dialogue().is_empty():
		_fail(view,"escort dialogue")
		return
	if not view.get_node("DialogueUI").visible or not view.get_node("DialogueUI/Body") is Label:
		_fail(view,"dialogue text must use native editable Label")
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
			await _wait(view)
			if not view.get_node("DialogueUI/Choice1").visible:
				_fail(view,"choices must render as native Buttons")
				return
			if not await _capture(view,"opening-choice.png"):
				_fail(view,"choice screenshot write")
				return
			view._dialogue_choice(0)
		else:
			view.visible_characters=float(node.text.length())
			view._dialogue_next()
	var session = view.get_node_or_null("/root/GameSession")
	if view.story.phase!="complete" or session==null or \
			not bool(session.flags.get("obtained_fragment",false)) or \
			int(session.items.get("taixu_fragment",0)) != 1:
		_fail(view,"dialogue fails to reach final fragment")
		return
	await _wait(view)
	var completion_actions: Array = []
	for node in view.get_node("CompleteUI").get_children():
		if node is Button:
			completion_actions.append(str(node.get_meta("action", "")))
	if completion_actions != ["story_battle", "menu"] or not view.get_node("CompleteUI").visible:
		_fail(view,"native completion must expose only canonical story battle and menu")
		return
	if not await _capture(view,"opening-complete.png"):
		_fail(view,"chapter completion screenshot write")
		return
	print("OPENING_VISUAL_CHECK_PASS title/cinematic/explore/dialogue/choice/complete")
	view.get_tree().quit(0)
