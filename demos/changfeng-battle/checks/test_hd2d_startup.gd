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

    # Runtime-created nodes have generated names unless named explicitly.
    # Validate the actual rendering camera instead of assuming its child name.
    var camera: Camera3D = scene.get("camera") as Camera3D
    var rig: Node = scene.get_node_or_null("CameraRig")
    if camera == null or rig == null or camera.get_parent() != rig:
        push_error("HD2D_STARTUP: battle camera missing from CameraRig")
        quit(1)
        return
    if scene.get_viewport().get_camera_3d() != camera:
        push_error("HD2D_STARTUP: battle camera is not active in its viewport")
        quit(1)
        return

    if scene.get("card_actions") == null or scene.get("phase_label") == null:
        push_error("HD2D_STARTUP: themed action UI missing")
        quit(1)
        return

    if scene.get("illustrated_map") == null or scene.get("illustrated_map").picture.texture == null:
        push_error("HD2D_STARTUP: flat illustrated battlefield missing")
        quit(1)
        return

    if scene.get_node_or_null("Actor_0/Nameplate") == null:
        push_error("HD2D_STARTUP: character nameplate missing")
        quit(1)
        return

    var hero: Sprite3D = _actor_sprite(scene, 0)
    var foe: Sprite3D = _actor_sprite(scene, 1)
    if hero == null or foe == null:
        push_error("HD2D_STARTUP: actor Sprite3D missing")
        quit(1)
        return
    if hero.hframes != 6 or hero.vframes != 4 or foe.hframes != 6 or foe.vframes != 4:
        push_error("HD2D_STARTUP: 6x4 illustrated atlas missing")
        quit(1)
        return
    var texture: ImageTexture = hero.texture as ImageTexture
    var rival_texture: ImageTexture = foe.texture as ImageTexture
    if texture == null or rival_texture == null:
        push_error("HD2D_STARTUP: illustrated atlas is not an image texture")
        quit(1)
        return
    var image: Image = texture.get_image()
    var rival_image: Image = rival_texture.get_image()
    if image == null or rival_image == null or image.is_empty() or rival_image.is_empty():
        push_error("HD2D_STARTUP: illustrated atlas image is empty")
        quit(1)
        return
    if image.get_size() != Vector2i(1536, 1024) or rival_image.get_size() != Vector2i(1536, 1024):
        push_error("HD2D_STARTUP: 256x256 supplied pose atlas frames expected")
        quit(1)
        return
    if image.get_pixel(0, 0).a != 0.0 or rival_image.get_pixel(0, 0).a != 0.0:
        push_error("HD2D_STARTUP: illustrated atlas is not transparent")
        quit(1)
        return
    var driver: RefCounted = scene.get("animation_driver") as RefCounted
    if driver == null:
        push_error("HD2D_STARTUP: sprite animation controller missing")
        quit(1)
        return
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

    print("HD2D_STARTUP_PASS actors=", snapshot.actors.size(), " grid=15x10 supplied_sprites=6x4_256x256")
    quit(0)

func _actor_sprite(scene: Node, actor_id: int) -> Sprite3D:
    var actor: Node = scene.get_node_or_null("Actor_%d" % actor_id)
    if actor == null:
        return null
    var sprites: Array[Node] = actor.find_children("*", "Sprite3D", false, false)
    return sprites[0] as Sprite3D if sprites.size() == 1 else null
