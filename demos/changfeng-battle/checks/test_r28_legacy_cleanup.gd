extends SceneTree
## R28: unused 3D presentation adapters are removed without touching the battle core.
const Router = preload("res://scripts/chapter_scene_router.gd")
const Native = preload("res://scripts/content/content_registry.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("R28 CLEANUP FAIL: " + label)

func _run() -> void:
    for path in ["res://scripts/hd2d_party_bridge.gd",
        "res://scripts/hd2d_scenery.gd","res://scripts/hd2d_vfx.gd"]:
        check(not FileAccess.file_exists(path),
            "unreferenced deprecated script is removed: " + path)
    check(Router.path_for("battle") == "res://battle_hd2d.tscn"
        and str(ProjectSettings.get_setting("application/run/main_scene")) == "res://opening.tscn",
        "only canonical Node2D battle is reachable from the player router")
    check(load("res://opening.tscn") is PackedScene
        and load("res://battle_hd2d.tscn") is PackedScene,
        "player opening and battle scenes remain valid")
    check(load("res://battle.tscn") is PackedScene
        and load("res://party_battle.tscn") is PackedScene,
        "historical regression scenes remain loadable")
    var native = Native.new()
    check(native.load_error.is_empty()
        and native.document("r25_school_forms").has("schools")
        and native.entries("character").has("shen_changfeng"),
        "canonical content remains registered in native Resources")
    print("R28_LEGACY_CLEANUP_PASS failures=",failures)
    quit(0 if failures == 0 else 1)
