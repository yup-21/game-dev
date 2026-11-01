extends SceneTree
## R30: native AnimationPlayer drives only painted actor presentation.
const Driver = preload("res://scripts/hd2d_animation.gd")
const Art = preload("res://scripts/hd2d_art_catalog.gd")
const Fallback = preload("res://scripts/fallback_assets.gd")
const Model = preload("res://scripts/battle_model.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("R30_NATIVE_ANIMATION: " + message)

func _run() -> void:
    var host := Node2D.new()
    root.add_child(host)
    var driver = Driver.new()
    var model = Model.new()
    var revision: int = int(model.state.revision)
    for actor_id in [0, 1]:
        var sprite := Sprite2D.new()
        sprite.texture = Art.sheet_for_actor(0) if actor_id == 0 else Fallback.ACTOR_SHEET
        sprite.scale = Vector2(0.75, 0.75) if actor_id == 0 else Vector2.ONE
        host.add_child(sprite)
        driver.register_actor(actor_id, sprite)
        var player: AnimationPlayer = sprite.get_node_or_null("NativeSpriteAnimation") as AnimationPlayer
        check(player != null, "actor %d has an AnimationPlayer child" % actor_id)
        if player == null:
            continue
        check(player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,
            "actor %d playback ticks only on presentation updates" % actor_id)
        for state in ["idle", "move", "attack", "guard", "hit", "evade", "skill", "combo", "defeat"]:
            check(player.has_animation(state), "native animation exists: %s" % state)
        var attack: Animation = player.get_animation("attack")
        check(attack.get_track_count() == 3 and
            attack.track_get_path(0) == NodePath(".:frame") and
            attack.value_track_get_update_mode(0) == Animation.UPDATE_DISCRETE,
            "frame is a discrete engine animation track")
        check(attack.track_get_path(1) == NodePath(".:scale") and
            attack.track_get_path(2) == NodePath(".:rotation"),
            "pose accents use native transform tracks")
        check(sprite.hframes == 6 and sprite.vframes == 4,
            "original and fallback art preserve the 6x4 atlas contract")
    driver.play(0, "attack")
    driver.update(0.22)
    var original_sprite: Sprite2D = host.get_child(0) as Sprite2D
    check(original_sprite.frame >= 12 and original_sprite.frame < 18,
        "attack frames are advanced by AnimationPlayer")
    check(original_sprite.scale != Vector2(0.75, 0.75) and
        absf(original_sprite.rotation) > 0.01,
        "native tracks animate the authored scale and tilt")
    driver.update(1.0)
    check(str(driver.tracks[0].state) == "idle" and
        original_sprite.frame < 6 and
        original_sprite.scale.is_equal_approx(Vector2(0.75, 0.75)),
        "finished action resets the original scale and idle pose")
    driver.play(1, "move")
    driver.update(0.25, {1: true})
    var fallback_sprite: Sprite2D = host.get_child(1) as Sprite2D
    check(fallback_sprite.frame >= 6 and fallback_sprite.frame < 12,
        "fallback atlas walks through native frame animation")
    driver.update(0.1, {})
    check(str(driver.tracks[1].state) == "idle" and fallback_sprite.frame < 6,
        "movement stops when the visual path is complete")
    driver.events([{"type": "ATTACK_DECLARED", "actor_id": 0, "target_id": 1}])
    check(driver.action_phase() == "startup", "semantic startup is preserved")
    driver.update(0.22)
    check(driver.action_phase() == "active" and
        not driver.drain_action_cues().is_empty(),
        "event cues remain authored and independent of native visuals")
    check(int(model.state.revision) == revision and
        not model.state.animation_pending,
        "native animation never mutates the authoritative BattleModel")
    driver.reset()
    check(driver.remaining_seconds() == 0.0 and driver.tracks[0].state == "idle",
        "presentation reset clears pending stages and returns to native idle")
    host.free()
    print("R30_NATIVE_ANIMATION_PASS failures=", failures)
    quit(1 if failures > 0 else 0)
