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
    if str(view.get("story").phase) == "menu":
        for node in view.get_node("NativeMenuUI/MenuControls").get_children():
            if node is Button:
                result.append(str(node.get_meta("action", "")))
    elif str(view.get("story").phase) == "complete":
        for node in view.get_node("CompleteUI").get_children():
            if node is Button:
                result.append(str(node.get_meta("action", "")))
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
    var menu_actions := _actions(view)
    _check(menu_actions == ["start", "hd2d", "pingjiang_qa", "pingjiang_vertical_qa",
        "pingjiang_25d_qa", "pingjiang_south_gate_qa", "shen_house_qa", "pingjiang_exploration", "quit"]
        and menu_actions.count("hd2d") == 1,
        "main menu keeps one HD-2D battle and five isolated map QA entries plus four-area exploration, without duel/party variants")
    var menu_buttons: Array = []
    for node in view.get_node("NativeMenuUI/MenuControls").get_children():
        if node is Button:
            menu_buttons.append(node)
    for i in range(menu_buttons.size()):
        var rect: Rect2 = menu_buttons[i].get_rect()
        _check(Rect2(0, 0, 1600, 1000).encloses(rect), "menu button stays within viewport")
        for j in range(i + 1, menu_buttons.size()):
            _check(not rect.intersects(menu_buttons[j].get_rect()),
                "menu hit areas do not overlap: %s / %s" % [
                    menu_buttons[i].get_meta("action", ""), menu_buttons[j].get_meta("action", "")])
    view.get("story").set("phase", "complete")
    view.queue_redraw()
    await process_frame
    await process_frame
    _check(_actions(view) == ["story_battle", "menu"],
        "prologue complete must show canonical story encounter only")
    var opening_code := FileAccess.get_file_as_string("res://scripts/opening_flow.gd")
    var result_code := FileAccess.get_file_as_string("res://scripts/demo_result.gd")
    var perspective_qa := "res://prototypes/pingjiang_25d/pingjiang_25d_validation.tscn"
    _check(load(perspective_qa) is PackedScene
        and opening_code.contains('"pingjiang_25d_qa"')
        and opening_code.contains('KEY_T')
        and opening_code.contains(perspective_qa),
        "T shortcut and independent 2.5D test scene are reachable from title")
    for qa in [
        ["pingjiang_south_gate_qa", "KEY_G", "res://scenes/pingjiang_south_gate_qa.tscn"],
        ["shen_house_qa", "KEY_H", "res://scenes/pingjiang_shen_house_qa.tscn"],
        ["pingjiang_exploration", "KEY_J", "res://scenes/pingjiang_exploration.tscn"]]:
        _check(load(qa[2]) is PackedScene and opening_code.contains('"' + qa[0] + '"')
            and opening_code.contains(qa[1]) and opening_code.contains(qa[2]),
            "title retains isolated map QA shortcut for " + qa[0])
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
