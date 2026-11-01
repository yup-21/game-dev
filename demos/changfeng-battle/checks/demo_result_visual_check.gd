extends SceneTree
const StoryFixture = preload("res://checks/story_test_helper.gd")
## Windowed result screen regression: the finish click must redraw its new controls.
var failed: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: print("PASS: ",label)
	else:
		failed += 1
		push_error("FAIL: "+label)

func frames() -> void:
	for _i in range(3): await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var session = root.get_node("GameSession")
	session.start_new_game()
	StoryFixture.finish_prologue(session)
	if not session.begin_encounter():
		check(false,"story encounter initializes")
		quit(1)
		return
	session.report_battle("victory",0)
	var view = load("res://demo_result.tscn").instantiate()
	root.add_child(view)
	await frames()
	var finish_button: Dictionary = {}
	for button in view.buttons:
		if button.id=="finish": finish_button=button
	check(not finish_button.is_empty(),"aftermath exposes the finish button")
	if not finish_button.is_empty():
		var event = InputEventMouseButton.new()
		event.position=finish_button.rect.get_center()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=true
		root.push_input(event,true)
		await frames()
		check(session.phase=="complete","finish click completes the demo")
		check(view.buttons.size()==1 and view.buttons[0].id=="new","completion redraw replaces the old controls")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	check(root.get_texture().get_image().save_png("res://captures/demo-result-complete.png")==OK,"completion screenshot saved")
	print("DEMO RESULT VISUAL FAILURES: ",failed)
	quit(1 if failed else 0)
