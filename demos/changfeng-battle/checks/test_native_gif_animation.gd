extends SceneTree
## New-native and legacy profiles must share battle timing without duplicate
## image indices or any change to BattleModel authority.
const Driver = preload("res://scripts/hd2d_animation.gd")
const Clips = preload("res://scripts/battle_native_sprite_clips.gd")
const Importer = preload("res://addons/wuxia_art_importer/native_gif_import.gd")

var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("NATIVE_GIF_ANIMATION: " + message)

func _run() -> void:
    var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    image.fill_rect(Rect2i(8, 8, 16, 16), Color(0.7, 0.9, 0.3))
    var texture := ImageTexture.create_from_image(image)
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    for action in ["idle", "walk", "attack1", "defeat"]:
        frames.add_animation(action)
        frames.set_animation_speed(action, 10.0)
        frames.set_animation_loop(action, action in ["idle", "walk"])
        frames.add_frame(action, texture, 1.0)
        frames.add_frame(action, texture, 3.0)
    var profile := WuxiaActorAnimationProfile.new()
    profile.native_frames = frames
    check(profile.valid_profile(), "native SpriteFrames-only profile is accepted")
    var save_path := OS.get_cache_dir().path_join("native-gif-check-" + str(Time.get_ticks_usec()) + ".tres")
    var saved: Error = ResourceSaver.save(frames, save_path)
    check(saved == OK, "Godot SpriteFrames saves to editable .tres")
    if saved == OK:
        var reopened: SpriteFrames = ResourceLoader.load(save_path) as SpriteFrames
        check(reopened != null and reopened.get_frame_count("attack1") == 2 and \
            is_equal_approx(reopened.get_frame_duration("attack1", 1), 3.0),
            "serialized native resource preserves action frames and per-frame timing")
        DirAccess.remove_absolute(save_path)
    check(profile.idle_atlas() == texture and profile.idle_columns() == 1,
        "native first frame is the idle reference without legacy grid")
    var mapping := Importer.parse_mapping("idle=/candidate/idle.gif\nattack1=/candidate/thrust.gif")
    check(str(mapping["error"]).is_empty() and mapping["actions"].size() == 2,
        "GIF mapping is explicit and allows action-to-file renames")
    check(not str(Importer.parse_mapping("walk=/candidate/walk.gif")["error"]).is_empty(),
        "GIF input requires explicit idle action")
    check(not str(Importer.parse_mapping("idle=x.gif\nidle=y.gif")["error"]).is_empty(),
        "duplicate action names fail before import")
    for scene_path in ["res://scenes/actors/battle_actor.tscn", "res://scenes/actors/story_role.tscn"]:
        var packed := ResourceLoader.load(scene_path) as PackedScene
        check(packed != null, "native actor scene loads: " + scene_path)
        if packed != null:
            var instance: Node = packed.instantiate()
            var visual: AnimatedSprite2D = instance.find_child("NativeFrames", true, false) as AnimatedSprite2D
            check(visual != null, "the authored scene has an editable AnimatedSprite2D")
            instance.free()
    var host := Node2D.new()
    root.add_child(host)
    var sprite := Sprite2D.new()
    sprite.texture = texture
    host.add_child(sprite)
    var driver = Driver.new()
    driver.register_actor(4, sprite, Vector2i.RIGHT, profile)
    var native: AnimatedSprite2D = sprite.get_node_or_null("NativeFrames") as AnimatedSprite2D
    check(native != null and native.sprite_frames == frames and sprite.texture == null,
        "native AnimatedSprite2D displays SpriteFrames instead of the legacy sheet")
    check(driver.tracks[4].player.get_animation("attack1").find_track(
        NodePath(".:frame"), Animation.TYPE_VALUE) < 0,
        "AnimationPlayer no longer duplicates native frame indices")
    driver.play(4, "attack1", 0.4)
    driver.update(0.2)
    check(native.frame == 1 and native.animation == "attack1",
        "runtime honors native frame lengths while keeping semantic duration")
    driver.update(0.25)
    check(native.animation == "idle", "nonloop native action returns to idle")
    driver.enqueue_defeat(4)
    driver.update(0.5)
    driver.update(0.51)
    check(native.animation == "defeat" and native.frame == 1,
        "defeat retains final native SpriteFrames frame")
    var legacy := load("res://data/templates/actor_animation_profile.tres") as WuxiaActorAnimationProfile
    check(legacy != null and legacy.valid_profile() and legacy.native_frames == null,
        "legacy Atlas/Clip resources still load unchanged")
    var fallback_sprite := Sprite2D.new()
    fallback_sprite.texture = legacy.atlas
    host.add_child(fallback_sprite)
    var player := Clips.attach(fallback_sprite, driver.action_timeline, legacy)
    check(player.has_animation("attack") and fallback_sprite.get_node_or_null("NativeFrames") == null,
        "legacy playback retains AnimationPlayer atlas track")
    host.free()
    print("NATIVE_GIF_ANIMATION_PASS failures=", failures)
    quit(1 if failures > 0 else 0)
