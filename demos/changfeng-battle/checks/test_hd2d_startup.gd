extends SceneTree
## Direct startup regression for Issue #21.
## Importing the project alone does not parse every optional scene script.
const SCENE_PATH := "res://battle_hd2d.tscn"
const Art = preload("res://scripts/hd2d_art_catalog.gd")

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

    # The formal scene must be 2D with a real Camera2D.
    var camera: Camera2D = scene.get("camera") as Camera2D
    if camera == null or camera.get_parent() != scene:
        push_error("HD2D_STARTUP: battle Camera2D missing")
        quit(1)
        return
    if scene.get_viewport().get_camera_2d() != camera:
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

    if scene.get("illustrated_map").actors[0].get_node_or_null("RoleName") == null:
        push_error("HD2D_STARTUP: character nameplate missing")
        quit(1)
        return

    var hero: Sprite2D = _actor_sprite(scene, 0)
    var foe: Sprite2D = _actor_sprite(scene, 1)
    if hero == null or foe == null:
        push_error("HD2D_STARTUP: actor Sprite2D missing")
        quit(1)
        return
    var hero_native: AnimatedSprite2D = hero.get_node_or_null("NativeFrames")
    var foe_native: AnimatedSprite2D = foe.get_node_or_null("NativeFrames")
    if (hero_native == null or hero_native.sprite_frames == null or
            foe_native == null or foe_native.sprite_frames == null):
        push_error("HD2D_STARTUP: approved native SpriteFrames missing")
        quit(1)
        return
    var texture: Texture2D = hero_native.sprite_frames.get_frame_texture("idle", 0)
    var rival_texture: Texture2D = foe_native.sprite_frames.get_frame_texture("idle", 0)
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
    if image.get_size() != Vector2i(256, 256) or rival_image.get_size() != Vector2i(256, 256):
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
    var hero_profile: WuxiaActorAnimationProfile = Art.animation_profile_for_character("shen_changfeng")
    if (hero_profile == null or hero_native.animation != "attack" or
            hero_native.frame >= hero_native.sprite_frames.get_frame_count("attack")):
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
    if (hero_native.animation != "hit" or
            hero_native.frame >= hero_native.sprite_frames.get_frame_count("hit")):
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
    if not bursts.is_empty():
        push_error("HD2D_STARTUP: attack VFX fired before effective animation cue")
        quit(1)
        return
    vfx.call("handle_action_cues", [{"name":"strike_active",
        "vfx_trigger":"strike_active", "profile":"attack",
        "event_type":"ATTACK_DECLARED", "actor_id":0}], scene.get("actor_nodes"))
    if vfx.get("bursts").is_empty():
        push_error("HD2D_STARTUP: slash VFX did not spawn on effective cue")
        quit(1)
        return
    vfx.call("clear")

    print("HD2D_STARTUP_PASS actors=", snapshot.actors.size(), " grid=15x10 native_spriteframes=256x256")
    quit(0)

func _actor_sprite(scene: Node, actor_id: int) -> Sprite2D:
    var painted = scene.get("illustrated_map")
    if painted == null or not painted.actors.has(actor_id):
        return null
    return painted.actors[actor_id].get_node_or_null("ActionSprite") as Sprite2D
