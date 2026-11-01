extends SceneTree
## Single battle entry: legacy views have been replaced by model and live-scene tests.
const Router = preload("res://scripts/chapter_scene_router.gd")
const ACTIVE := "res://battle_hd2d.tscn"
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("BATTLE_ENTRY: " + description)

func _actions(view: Node) -> Array:
    var result: Array = []
    for button in view.get("buttons"):
        result.append(str(button.get("action", "")))
    return result

func _run() -> void:
    var main_scene: PackedScene = load("res://opening.tscn") as PackedScene
    var battle_scene: PackedScene = load(ACTIVE) as PackedScene
    _check(main_scene != null and battle_scene != null,
        "main menu and canonical illustrated battle must load")
    if main_scene == null or battle_scene == null:
        quit(1)
        return
    _check(str(ProjectSettings.get_setting("application/run/main_scene")) == "res://opening.tscn",
        "opening remains the only default startup scene")
    var view: Node2D = main_scene.instantiate() as Node2D
    root.add_child(view)
    await process_frame
    await process_frame
    _check(_actions(view) == ["start", "hd2d", "quit"],
        "main menu must offer one HD-2D battle, not duel/party variants")
    view.get("story").set("phase", "complete")
    view.queue_redraw()
    await process_frame
    await process_frame
    _check(_actions(view) == ["story_battle", "menu"],
        "prologue complete must show canonical story encounter only")
    var opening_code := FileAccess.get_file_as_string("res://scripts/opening_flow.gd")
    var result_code := FileAccess.get_file_as_string("res://scripts/demo_result.gd")
    for path in ["res://battle.tscn", "res://party_battle.tscn"]:
        _check(not opening_code.contains(path) and not result_code.contains(path),
            "public story/menu/result still points to deprecated " + path)
    _check(Router.path_for("battle") == ACTIVE
        and opening_code.contains('scene_for("battle")')
        and result_code.contains('scene_for("battle")'),
        "menu, story and retry resolve one canonical route; no duplicate scene constants")
    for path in ["res://battle.tscn", "res://party_battle.tscn"]:
        _check(not FileAccess.file_exists(path), "obsolete battle view is removed: " + path)
    view.queue_free()
    await process_frame
    print("BATTLE_ENTRY_PASS checks=%d failures=%d canonical=%s" % [
        checks, failures, ACTIVE])
    quit(1 if failures > 0 else 0)
