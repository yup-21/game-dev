extends SceneTree
## R8 integration: the canonical scene owns separate world, presenter and HUD views.
const World = preload("res://scripts/battle_world_2d.gd")
const Presenter = preload("res://scripts/battle_presentation_player.gd")
const HUD = preload("res://scripts/battle_hud_view.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("R8_SCENE_COMPONENTS: " + reason)

func _run() -> void:
    var scene: Node2D = load("res://battle_hd2d.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var world = scene.get("world")
    var presenter = scene.get("presentation_player")
    var hud = scene.get("hud_view")
    _check(world is World and presenter is Presenter and hud is HUD,
        "canonical battle constructs all three R8 adapters")
    _check(world.illustrated_map == scene.get("illustrated_map") and
        world.camera == scene.get("camera"), "world owns painted scene and camera")
    _check(world.actor_nodes == scene.get("actor_nodes") and
        not world.actor_nodes.is_empty(), "world actors are projected to legacy view handles")
    _check(presenter.animator == scene.get("animation_driver") and
        presenter.coordinator == scene.get("presentation"),
        "presentation shares one ticket and one animator")
    _check(hud.controls.get("status") == scene.get("status_label") and
        hud.controls.get("rail") == scene.get("charge_rail"),
        "HUD binds the authoritative controls")
    var model = scene.get("model")
    var revision := int(model.state.revision)
    world.snap_to_authority(model.state.actors, presenter.animator)
    _check(not world.paths_pending() and int(model.state.revision) == revision,
        "snap updates visual world without committing rules")
    print("R8_SCENE_COMPONENTS_PASS failures=%d" % failures)
    quit(1 if failures else 0)
