extends SceneTree
## A rendered skip must acknowledge the exact model ticket once without
## re-submitting an already-committed attack/turn or charging resources.
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, reason: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("PRESENTATION_SKIP_UI: " + reason)

func _run() -> void:
    var scene: Node2D = load("res://battle_hd2d.tscn").instantiate() as Node2D
    root.add_child(scene)
    await process_frame
    var model: Variant = scene.get("model")
    var owner: int = int(model.state.active_id)
    var turn: Dictionary = model.submit(model.request("END_ACTION",owner))
    _check(bool(turn.get("success",false)), "authoritative END_ACTION succeeds")
    if not bool(turn.get("success",false)):
        quit(1)
        return
    scene.call("_accept",turn)
    var ticket: int = int(turn.get("ticket",-1))
    _check(ticket >= 0 and int(scene.get("animation_ticket")) == ticket,
        "presenter owns exact committed ticket")
    var revision: int = int(model.state.revision)
    scene.call("_submit","END_ACTION",{})
    _check(int(model.state.revision) == revision,
        "double-click while animating cannot submit a second turn")
    scene.call("_skip_presentation")
    _check(not bool(model.state.animation_pending) and
        int(scene.get("animation_ticket")) == -1,
        "skip releases the matching pending ticket")
    _check(int(model.state.revision) == revision,
        "skip does not mutate already-committed battle revision")
    scene.call("_skip_presentation")
    _check(int(scene.get("presentation").skip()) == -1,
        "second skip is idempotent and cannot acknowledge again")
    print("PRESENTATION_SKIP_UI_PASS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
