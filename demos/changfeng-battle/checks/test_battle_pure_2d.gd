extends SceneTree
## The one player-facing battle must not instantiate a hidden 3D world.
var failures := 0
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("PURE_BATTLE_2D: " + message)

func _run() -> void:
    var scene: Node2D = load("res://battle_hd2d.tscn").instantiate() as Node2D
    _check(scene != null, "formal battle scene root is Node2D")
    if scene == null:
        quit(1)
        return
    root.add_child(scene)
    await process_frame
    var camera: Camera2D = scene.get("camera") as Camera2D
    _check(camera != null and camera.is_current(), "active Camera2D created")
    _check(scene.find_children("*", "Node3D", true, false).is_empty(),
        "battle hierarchy has no 3D compatibility geometry")
    var painted = scene.get("illustrated_map")
    _check(painted != null and painted.scene_root is Node2D,
        "painted terrain is native CanvasLayer/Node2D")
    _check(painted.actors.size() >= 2 and
        painted.actors[0].get_node("ActionSprite") is Sprite2D,
        "actors use real Sprite2D animation atlas")
    var p: Vector2 = painted.point_for_cell(Vector2i(7, 4))
    painted.scene_root.position = Vector2(3, 5)
    _check(painted.cell_from_screen(p + Vector2(3, 5)) == Vector2i(7, 4),
        "mouse projection compensates for stage shake")
    _check(painted.to_battle_point(p + Vector2(3, 5)) == p,
        "continuous FREE click retains authoritative world point")
    _check(scene.get("effects_driver").canvas == painted.scene_root,
        "VFX uses only painted Node2D layer")
    print("PURE_BATTLE_2D_PASS checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)
