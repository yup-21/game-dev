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

    if scene.get("card_actions") == null or scene.get("phase_label") == null:
        push_error("HD2D_STARTUP: themed action UI missing")
        quit(1)
        return

    if scene.get_node_or_null("WuxiaScenery") == null:
        push_error("HD2D_STARTUP: wuxia scenery missing")
        quit(1)
        return

    if scene.get_node_or_null("Actor_0/Nameplate") == null:
        push_error("HD2D_STARTUP: character nameplate missing")
        quit(1)
        return

    var hero: Sprite3D = scene.get_node_or_null("Actor_0/Sprite3D") as Sprite3D
    var foe: Sprite3D = scene.get_node_or_null("Actor_1/Sprite3D") as Sprite3D
    if hero == null or foe == null or hero.hframes != 6 or hero.vframes != 4:
        push_error("HD2D_STARTUP: original sprite atlas missing")
        quit(1)
        return
    var texture: ImageTexture = hero.texture as ImageTexture
    if texture == null or texture.get_image().get_pixel(0, 0).a != 0.0:
        push_error("HD2D_STARTUP: sprite atlas is not transparent")
        quit(1)
        return
    var driver: RefCounted = scene.get("animation_driver") as RefCounted
    driver.call("play", 0, "attack")
    driver.call("update", 0.16, {})
    if hero.frame < 12 or hero.frame > 17:
        push_error("HD2D_STARTUP: attack animation frame not selected")
        quit(1)
        return

    driver.call("events", [{"type": "ATTACK_DECLARED", "actor_id": 0},
        {"type": "HP_DAMAGED", "actor_id": 1, "defender_id": 0}])
    if float(driver.call("remaining_seconds")) < 0.9:
        push_error("HD2D_STARTUP: semantic animation queue too short")
        quit(1)
        return
    driver.call("update", 0.65, {})
    if hero.frame != 19:
        push_error("HD2D_STARTUP: hit reaction did not follow attack")
        quit(1)
        return

    var vfx: RefCounted = scene.get("effects_driver") as RefCounted
    if vfx == null:
        push_error("HD2D_STARTUP: sword VFX controller missing")
        quit(1)
        return
    vfx.call("handle_events", [{"type": "ATTACK_DECLARED", "actor_id": 0}], scene.get("actor_nodes"))
    var bursts: Array = vfx.get("bursts")
    if bursts.is_empty():
        push_error("HD2D_STARTUP: slash VFX did not spawn")
        quit(1)
        return
    vfx.call("clear")

    print("HD2D_STARTUP_PASS actors=", snapshot.actors.size(), " grid=15x10 sprites=6x4")
    quit(0)
