extends SceneTree
const StoryFixture = preload("res://checks/story_test_helper.gd")
## Windowed result screen regression: the native Button must change into
## the sole completion action without rebuilding the UI tree.
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
	var panel: Control = view.get_node("ResultUI/ResultPanel")
	var finish_button: Button = panel.get_node("PrimaryAction")
	check(finish_button.text == "结束试玩", "aftermath exposes the native finish button")
	if finish_button.text == "结束试玩":
		var event = InputEventMouseButton.new()
		event.position=finish_button.get_global_rect().get_center()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=true
		root.push_input(event,true)
		await frames()
		check(session.phase=="complete","finish click completes the demo")
		check(finish_button.text == "返回主菜单" and
			panel.get_node("Retry").visible == false and
			panel.get_node("Menu").visible == false,
			"completion updates the existing native controls")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	check(root.get_texture().get_image().save_png("res://captures/demo-result-complete.png")==OK,"completion screenshot saved")
	print("DEMO RESULT VISUAL FAILURES: ",failed)
	quit(1 if failed else 0)
