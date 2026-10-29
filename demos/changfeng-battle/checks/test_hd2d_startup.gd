extends SceneTree
## Direct startup regression for Issue #21.
## Importing the project alone does not parse every optional scene script.
const SCENE_PATH := "res://battle_hd2d.tscn"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load(SCENE_PATH) as PackedScene
    if packed == null:
        push_error("HD2D_STARTUP: scene/script load failed")
        quit(1)
        return

    var scene: Node = packed.instantiate()
    if scene == null:
        push_error("HD2D_STARTUP: PackedScene instantiate failed")
        quit(1)
        return

    root.add_child(scene)
    await process_frame

    var snapshot: Variant = scene.get("snap")
    if not snapshot is Dictionary or snapshot.get("actors", []).size() < 2:
        push_error("HD2D_STARTUP: BattleModel snapshot was not initialized")
        quit(1)
        return

    if scene.get_node_or_null("CameraRig/Camera3D") == null:
        push_error("HD2D_STARTUP: camera missing")
        quit(1)
        return

    if scene.get("card_actions") == null:
        push_error("HD2D_STARTUP: action UI missing")
        quit(1)
        return

    print("HD2D_STARTUP_PASS actors=", snapshot.actors.size(), " grid=15x10")
    quit(0)
