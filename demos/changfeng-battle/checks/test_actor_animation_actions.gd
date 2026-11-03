extends SceneTree
## Twelve-action library, legacy aliases, skill cue/VFX routing and visual defeat.

const Clip = preload("res://scripts/content/actor_animation_clip.gd")
const Profile = preload("res://scripts/content/actor_animation_profile.gd")
const NativeClips = preload("res://scripts/battle_native_sprite_clips.gd")
const ActionTimeline = preload("res://scripts/battle_action_timeline.gd")
const Animator = preload("res://scripts/hd2d_animation.gd")
const VFX = preload("res://scripts/battle_vfx_2d.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("ACTOR_ACTIONS: " + reason)

func _run() -> void:
    var profile: WuxiaActorAnimationProfile = load(
        "res://data/templates/actor_animation_profile_12_actions.tres") as WuxiaActorAnimationProfile
    _check(profile != null and profile.valid_profile(), "modern twelve-action profile validates")
    if profile == null or not profile.valid_profile():
        quit(1)
        return
    var sprite := Sprite2D.new()
    sprite.texture = profile.idle_atlas()
    sprite.hframes = profile.idle_columns()
    sprite.vframes = profile.idle_rows()
    root.add_child(sprite)
    var timeline = ActionTimeline.new()
    _check(timeline.load_error.is_empty(), "semantic timeline loads")
    var player: AnimationPlayer = NativeClips.attach(sprite, timeline, profile)
    for action in Profile.REQUIRED_ACTIONS:
        _check(player.has_animation(action), "registered " + action)
    _check(player.get_animation("walk").loop_mode != Animation.LOOP_NONE and
        player.get_animation("run").loop_mode != Animation.LOOP_NONE,
        "walk and run loop independently")
    _check(player.get_animation("run").length < player.get_animation("walk").length,
        "run cadence can differ from walk")
    var heavy: Animation = player.get_animation("attack4")
    var frame_track: int = heavy.find_track(NodePath(".:frame"), Animation.TYPE_VALUE)
    _check(frame_track >= 0 and heavy.track_get_key_time(frame_track, 1) > 0.13,
        "uneven heavy-attack frame beats survive temporal normalization")
    var future := Clip.new()
    future.action = "attack5"
    future.frames = PackedInt32Array([12, 13, 14])
    var extended: WuxiaActorAnimationProfile = profile.duplicate(true) as WuxiaActorAnimationProfile
    extended.clips.append(future)
    _check(extended.valid_profile(), "future action IDs need no player code changes")
    var future_sprite := Sprite2D.new()
    future_sprite.texture = extended.idle_atlas()
    root.add_child(future_sprite)
    var future_player: AnimationPlayer = NativeClips.attach(future_sprite,
        timeline, extended)
    _check(future_player.has_animation("attack5"), "dynamic attack5 registered")

    var separate: WuxiaActorAnimationProfile = profile.duplicate(true) as WuxiaActorAnimationProfile
    var own: WuxiaActorAnimationClip = separate.clip_for("attack2")
    var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
    own.atlas = ImageTexture.create_from_image(img)
    own.columns = 1
    own.rows = 1
    own.frames = PackedInt32Array([0])
    _check(separate.valid_profile(), "independent atlas with matching cell scale")
    var independent_sprite := Sprite2D.new()
    independent_sprite.texture = separate.idle_atlas()
    independent_sprite.hframes = separate.idle_columns()
    independent_sprite.vframes = separate.idle_rows()
    root.add_child(independent_sprite)
    var independent_player: AnimationPlayer = NativeClips.attach(
        independent_sprite, timeline, separate)
    independent_player.play("attack2")
    independent_player.advance(0.0)
    _check(independent_sprite.texture == own.atlas and independent_sprite.hframes == 1,
        "per-clip texture and grid take effect together")

    var legacy: WuxiaActorAnimationProfile = load(
        "res://data/templates/actor_animation_profile.tres") as WuxiaActorAnimationProfile
    _check(legacy.valid_profile() and
        legacy.resolved_clip_for("attack3") == legacy.clip_for("attack") and
        legacy.resolved_clip_for("run") == legacy.clip_for("move"),
        "legacy nine-action profiles remain usable")
    var skill := WuxiaSkillUsageDefinition.new()
    skill.usage_id = "test_skill"
    skill.animation_action = "attack3"
    skill.vfx_slot = "sword_a"
    skill.vfx_trigger = "strike_active"
    _check(skill.to_record().get("animation_action", "") == "attack3" and
        skill.to_record().get("vfx_slot", "") == "sword_a",
        "skill usage exports one action and independent VFX slot")
    var node := WuxiaTechniqueNodeDefinition.new()
    node.node_id = "test_stage"
    node.animation_action = "attack3"
    node.vfx_slot = "sword_b"
    _check(node.to_record().get("animation_action", "") == "attack3" and
        node.to_record().get("vfx_slot", "") == "sword_b",
        "technique stage can share action but change VFX")

    var animator = Animator.new()
    var actor := Sprite2D.new()
    actor.texture = profile.idle_atlas()
    actor.hframes = profile.idle_columns()
    actor.vframes = profile.idle_rows()
    root.add_child(actor)
    animator.register_actor(7, actor, Vector2i.RIGHT, profile)
    var source_node := Node2D.new()
    root.add_child(source_node)
    var painted := Node2D.new()
    root.add_child(painted)
    var effects = VFX.new(painted)
    var nodes := {7: source_node}
    for slot in ["sword_a", "sword_b"]:
        var event := {"type": "ATTACK_DECLARED", "actor_id": 7,
            "definition_id": slot, "usage_id": "thrust",
            "animation_action": "attack3", "vfx_slot": slot,
            "vfx_trigger": "strike_active"}
        var before_count: int = effects.bursts.size()
        effects.handle_events([event], nodes)
        _check(effects.bursts.size() == before_count,
            "attack VFX is not fired on event receipt")
        animator.events([{"type":"CARD_PLAYED", "actor_id":7, "definition_id":slot,
            "usage_id":"thrust", "animation_action":"attack3", "vfx_slot":slot}, event])
        _check(str(animator.tracks[7].state) == "attack3" and
            animator.timeline.is_empty(), "single skill invocation queues only one action")
        animator.update(0.10)
        _check(animator.drain_action_cues().is_empty(), "no VFX cue before effective frame")
        animator.update(0.10)
        var cues: Array = animator.drain_action_cues()
        _check(cues.size() == 1 and str(cues[0].vfx_slot) == slot,
            "cue retains skill-specific VFX slot")
        effects.handle_action_cues(cues, nodes)
        _check(effects.bursts.size() == before_count + 1,
            "VFX fires only on matching action cue")
    animator.events([{"type":"MOVE_FREE", "actor_id":7,
        "path": PackedVector2Array([Vector2.ZERO, Vector2(320, 0)])}])
    _check(str(animator.tracks[7].state) == "run", "long movement chooses run")
    animator.events([{"type":"MOVE", "actor_id":7,
        "from": Vector2i.ZERO, "path":[Vector2i(1,0)]}])
    _check(str(animator.tracks[7].state) == "walk", "short movement chooses walk")
    animator.events([])
    animator.enqueue_defeat(7)
    animator.update(1.2)
    animator.update(1.2)
    _check(str(animator.tracks[7].state) == "defeat" and actor.frame == 19,
        "defeat retains authored terminal frame")
    animator.reset()
    _check(str(animator.tracks[7].state) == "idle", "reset releases defeat hold")
    print("ACTOR_ACTIONS_PASS failures=%d" % failures)
    quit(1 if failures else 0)
