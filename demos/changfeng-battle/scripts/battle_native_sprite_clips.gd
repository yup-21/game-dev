extends RefCounted
## Sprite2D atlas playback uses Godot AnimationPlayer/Animation resources.
## All tracks are cosmetic; event windows and combat authority stay elsewhere.
const FRAME_RATE := 9.0
const FRAMES_PER_ROW := 6
const POSE_SAMPLES_PER_SECOND := 30.0
const BASE_ACTIONS := ["idle", "walk", "run", "attack1", "attack2", "attack3",
    "attack4", "skill", "evade", "guard", "hit", "defeat",
    "move", "attack", "combo"]
const STATE_ROW := {"idle": 0, "move": 1, "walk": 1, "run": 1,
    "attack": 2, "attack1": 2, "attack2": 2, "attack3": 2,
    "attack4": 2, "guard": 3, "hit": 3, "evade": 3, "skill": 3,
    "combo": 3, "defeat": 3}
const SINGLE_FRAMES := {"guard": 0, "hit": 1, "evade": 2,
    "skill": 4, "combo": 4, "defeat": 1}

static func attach(sprite: Sprite2D, timeline: Variant,
        profile: WuxiaActorAnimationProfile = null) -> AnimationPlayer:
    var player: AnimationPlayer = sprite.get_node_or_null("NativeSpriteAnimation") as AnimationPlayer
    if player == null:
        player = AnimationPlayer.new()
        player.name = "NativeSpriteAnimation"
        sprite.add_child(player)
    player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    player.root_node = NodePath("..")
    if player.has_animation_library(""):
        # Never erase an artist-authored AnimationLibrary on an instanced scene.
        if profile != null and profile.native_frames != null and player.has_animation("idle"):
            _attach_native_visual(sprite, profile.native_frames)
            return player
        player.remove_animation_library("")
    var library := AnimationLibrary.new()
    var native: SpriteFrames = profile.native_frames if profile != null else null
    var actions: Array = BASE_ACTIONS.duplicate() if profile == null else []
    if native != null:
        for action in native.get_animation_names():
            actions.append(action)
        _attach_native_visual(sprite, native)
    elif profile != null:
        if not profile.valid_profile():
            push_error("Invalid animation profile Resource: " + str(profile.resource_path))
            return player
        # Register only authored actions and explicitly configured aliases.
        for entry in profile.clips:
            var clip: WuxiaActorAnimationClip = entry as WuxiaActorAnimationClip
            if clip != null and not actions.has(clip.action):
                actions.append(clip.action)
        for action in profile.action_fallbacks:
            if not actions.has(str(action)):
                actions.append(str(action))
    for state in actions:
        var semantic: String = semantic_for(str(state))
        var duration: float = timeline.duration_for(semantic, fallback_duration_for(semantic))
        if native != null:
            library.add_animation(str(state), _native_clip(native, str(state), sprite.scale,
                profile.resolved_clip_for(str(state)) if profile != null else null))
        elif profile != null:
            var authored: WuxiaActorAnimationClip = profile.resolved_clip_for(str(state))
            if authored == null:
                push_error("Unresolved configured action: " + str(state) + " (" + str(profile.resource_path) + ")")
                continue
            library.add_animation(str(state), _authored_clip(authored, duration, sprite.scale, profile))
        else:
            # Characters with no animation profile retain their generic demo pose.
            # This is not an implicit remapping for any provided Resource.
            library.add_animation(str(state), _clip(str(state), duration, sprite.scale))
    player.add_animation_library("", library)
    if player.has_animation("idle"):
        player.play("idle")
        player.advance(0.0)
    else:
        push_error("Missing idle animation in profile: " + str(profile.resource_path))
    return player


static func _attach_native_visual(sprite: Sprite2D, frames: SpriteFrames) -> void:
    var animated: AnimatedSprite2D = sprite.get_node_or_null("NativeFrames") as AnimatedSprite2D
    if animated == null:
        animated = AnimatedSprite2D.new()
        animated.name = "NativeFrames"
        sprite.add_child(animated)
        animated.offset = sprite.offset
        animated.texture_filter = sprite.texture_filter
    animated.sprite_frames = frames
    animated.animation = "idle"
    # The driver seeks native frames at deterministic presentation timestamps.
    animated.pause()
    sprite.texture = null


static func _native_clip(frames: SpriteFrames, action: String,
        base_scale: Vector2, legacy_pose: WuxiaActorAnimationClip = null) -> Animation:
    var animation := Animation.new()
    var duration := 0.0
    for index in range(frames.get_frame_count(action)):
        duration += frames.get_frame_duration(action, index) / frames.get_animation_speed(action)
    animation.length = maxf(0.01, duration)
    animation.loop_mode = Animation.LOOP_LINEAR if frames.get_animation_loop(action) else Animation.LOOP_NONE
    # SpriteFrames owns pixels, order and frame durations. AnimationPlayer owns
    # optional local pose/root changes, never duplicates those frame indices.
    for property_name in ["scale", "rotation", "position"]:
        var track: int = _value_track(animation, property_name)
        var baseline: Variant = base_scale if property_name == "scale" else (
            0.0 if property_name == "rotation" else Vector2.ZERO)
        animation.track_insert_key(track, 0.0, baseline)
    # SpriteFrames owns pixels and timing. Retain any approved per-frame
    # local foot/root offsets on AnimationPlayer's independent pose track.
    if legacy_pose != null and not legacy_pose.root_offsets.is_empty() and \
            legacy_pose.root_offsets.size() == frames.get_frame_count(action):
        var position_track := animation.find_track(NodePath(".:position"), Animation.TYPE_VALUE)
        var elapsed := 0.0
        for index in range(frames.get_frame_count(action)):
            animation.track_insert_key(position_track, elapsed,
                legacy_pose.root_offsets[index])
            elapsed += frames.get_frame_duration(action, index) / \
                frames.get_animation_speed(action)
    return animation

static func _value_track(animation: Animation, property_name: String,
        discrete: bool = false) -> int:
    var index: int = animation.add_track(Animation.TYPE_VALUE)
    animation.track_set_path(index, NodePath(".:" + property_name))
    animation.value_track_set_update_mode(index,
        Animation.UPDATE_DISCRETE if discrete else Animation.UPDATE_CONTINUOUS)
    animation.track_set_interpolation_type(index,
        Animation.INTERPOLATION_NEAREST if discrete else Animation.INTERPOLATION_LINEAR)
    return index

static func _clip(state: String, authored_duration: float,
        base_scale: Vector2) -> Animation:
    var animation := Animation.new()
    var looping: bool = state in ["idle", "move", "walk", "run"]
    # The walk/idle atlas cycles every six frames independent of event duration.
    var duration: float = float(FRAMES_PER_ROW) / FRAME_RATE if looping else maxf(0.01, authored_duration)
    animation.length = duration
    animation.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
    var frame_index: int = _value_track(animation, "frame", true)
    var row: int = int(STATE_ROW.get(state, 2))
    if SINGLE_FRAMES.has(state):
        var initial: int = row * FRAMES_PER_ROW + int(SINGLE_FRAMES[state])
        animation.track_insert_key(frame_index, 0.0, initial)
        if state in ["evade", "skill", "combo"]:
            animation.track_insert_key(frame_index, duration * 0.5, initial + 1)
    else:
        for index in range(FRAMES_PER_ROW):
            animation.track_insert_key(frame_index, float(index) / FRAME_RATE,
                row * FRAMES_PER_ROW + index)
    var scale_track: int = _value_track(animation, "scale")
    var rotation_track: int = _value_track(animation, "rotation")
    var count: int = maxi(2, ceili(duration * POSE_SAMPLES_PER_SECOND))
    for index in range(count + 1):
        var at: float = duration * float(index) / float(count)
        var phase: float = clampf(at / duration, 0.0, 1.0)
        var thrust: float = sin(phase * PI)
        var size := Vector2.ONE
        var tilt: float = 0.0
        match state:
            "move", "walk", "run":
                size.x = 1.0 + sin(at * 18.0) * 0.035
                tilt = sin(at * 12.0) * 0.045
            "attack", "attack1", "attack2", "attack3", "attack4", "combo", "skill":
                size = Vector2(1.0 + thrust * 0.14, 1.0 - thrust * 0.09)
                tilt = -thrust * (0.18 if state == "combo" else 0.11)
            "guard":
                size = Vector2(1.0 + thrust * 0.08, 1.0 - thrust * 0.13)
            "hit":
                size = Vector2(1.0 - thrust * 0.10, 1.0 + thrust * 0.07)
                tilt = thrust * 0.15
            "evade":
                tilt = thrust * 0.14
        # Loop seam returns to the baseline rather than accumulating a pose.
        if looping and index == count:
            size = Vector2.ONE
            tilt = 0.0
        animation.track_insert_key(scale_track, at, base_scale * size)
        animation.track_insert_key(rotation_track, at, tilt)
    # A procedurally animated fallback must restore the visual root as well.
    var root_track: int = _value_track(animation, "position")
    animation.track_insert_key(root_track, 0.0, Vector2.ZERO)
    return animation

## Semantic windows belong to ActionTimeline; authored frame beats preserve their
## relative spacing inside that window. Loops use their exact authored cadence.
static func semantic_for(action: String) -> String:
    if action in ["walk", "run", "move"]:
        return "move"
    if action.begins_with("attack") or action == "combo":
        return "combo" if action == "combo" else "attack"
    if action in ["idle", "guard", "hit", "evade", "skill", "defeat"]:
        return action
    return "skill"

static func fallback_duration_for(semantic: String) -> float:
    match semantic:
        "idle": return 1.0
        "move", "skill": return 0.55
        "guard", "evade": return 0.38
        "hit": return 0.46
        "combo": return 0.78
        "defeat": return 1.0
    return 0.62

static func _authored_clip(clip: WuxiaActorAnimationClip, action_duration: float,
        base_scale: Vector2, profile: WuxiaActorAnimationProfile) -> Animation:
    var animation := Animation.new()
    var count: int = clip.frames.size()
    var authored_total: float = 0.0
    for index in range(count):
        authored_total += float(clip.frame_durations[index]) if not clip.frame_durations.is_empty() \
            else 1.0 / clip.loop_fps
    var duration: float = authored_total if clip.loop else maxf(0.01, action_duration)
    animation.length = duration
    animation.loop_mode = Animation.LOOP_LINEAR if clip.loop else Animation.LOOP_NONE
    var texture_track: int = _value_track(animation, "texture", true)
    animation.track_insert_key(texture_track, 0.0, clip.effective_atlas(profile.atlas))
    var columns_track: int = _value_track(animation, "hframes", true)
    animation.track_insert_key(columns_track, 0.0, clip.effective_columns(profile.columns))
    var rows_track: int = _value_track(animation, "vframes", true)
    animation.track_insert_key(rows_track, 0.0, clip.effective_rows(profile.rows))
    var scale_track: int = _value_track(animation, "scale")
    animation.track_insert_key(scale_track, 0.0, base_scale)
    var rotation_track: int = _value_track(animation, "rotation")
    animation.track_insert_key(rotation_track, 0.0, 0.0)
    var root_track: int = _value_track(animation, "position")
    var frame_track: int = _value_track(animation, "frame", true)
    var elapsed: float = 0.0
    for index in range(count):
        var at: float = elapsed / authored_total * duration
        animation.track_insert_key(frame_track, at, int(clip.frames[index]))
        animation.track_insert_key(root_track, at,
            clip.root_offsets[index] if not clip.root_offsets.is_empty() else Vector2.ZERO)
        elapsed += float(clip.frame_durations[index]) if not clip.frame_durations.is_empty() \
            else 1.0 / clip.loop_fps
    return animation
