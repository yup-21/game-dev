extends RefCounted
## Sprite2D atlas playback uses Godot AnimationPlayer/Animation resources.
## All tracks are cosmetic; event windows and combat authority stay elsewhere.
const FRAME_RATE := 9.0
const FRAMES_PER_ROW := 6
const POSE_SAMPLES_PER_SECOND := 30.0
## Fallback cells for legacy 6x4 sheets. Native authored clips may add any ID.
const STATE_ROW := {"idle": 0, "walk": 1, "run": 1, "move": 1,
    "attack1": 2, "attack2": 2, "attack3": 2, "attack4": 2,
    "attack": 2, "guard": 3, "hit": 3, "evade": 3,
    "skill": 3, "combo": 3, "defeat": 3}
const SINGLE_FRAMES := {"guard": 0, "hit": 1, "evade": 2,
    "skill": 4, "combo": 4, "defeat": 1}

static func attach(sprite: Sprite2D, timeline: Variant,
        profile: WuxiaActorAnimationProfile = null) -> AnimationPlayer:
    var player := AnimationPlayer.new()
    player.name = "NativeSpriteAnimation"
    player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    player.root_node = NodePath("..")
    sprite.add_child(player)
    var library := AnimationLibrary.new()
    var states: Array[String] = []
    for state in STATE_ROW.keys():
        states.append(str(state))
    if profile != null:
        for entry in profile.clips:
            var clip: WuxiaActorAnimationClip = entry as WuxiaActorAnimationClip
            if clip != null and not states.has(clip.action):
                states.append(clip.action)
    for state in states:
        var fallback_duration: float = 0.62
        match str(state):
            "idle": fallback_duration = 1.0
            "move", "walk", "run", "skill": fallback_duration = 0.55
            "guard", "evade": fallback_duration = 0.38
            "hit": fallback_duration = 0.46
            "combo": fallback_duration = 0.78
            "defeat": fallback_duration = 1.0
        var duration: float = timeline.duration_for(_timeline_id(str(state)), fallback_duration)
        var authored: WuxiaActorAnimationClip = _find_clip(profile, str(state))
        library.add_animation(str(state),
            _authored_clip(authored, duration) if authored != null
            else _clip(str(state), duration, sprite.scale))
    player.add_animation_library("", library)
    player.play("idle")
    player.advance(0.0)
    return player

## Resolve canonical action IDs to legacy art without mutating the source profile.
static func _find_clip(profile: WuxiaActorAnimationProfile, state: String) -> WuxiaActorAnimationClip:
    if profile == null:
        return null
    var authored: WuxiaActorAnimationClip = profile.clip_for(state)
    if authored != null:
        return authored
    var aliases: Array[String] = []
    match state:
        "walk", "run": aliases = ["walk", "move"]
        "move": aliases = ["walk"]
        "attack", "attack1": aliases = ["attack1", "attack"]
        "attack2", "attack3", "attack4": aliases = ["attack"]
        "combo": aliases = ["attack4", "attack"]
    for alias in aliases:
        authored = profile.clip_for(alias)
        if authored != null:
            return authored
    return null


static func _timeline_id(state: String) -> String:
    if state in ["walk", "run"]:
        return "move"
    if state in ["attack1", "attack2", "attack3", "attack4"]:
        return "attack"
    return state


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
    var row: int = int(STATE_ROW[state])
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
    return animation

## A real per-action atlas preserves the artist's poses and does not stretch
## sprites procedurally. Non-loop actions fit the semantic ActionTimeline window;
## idle/walk loops use their independently authored frame rate.
static func _authored_clip(clip: WuxiaActorAnimationClip, action_duration: float) -> Animation:
    var animation := Animation.new()
    var count: int = clip.frames.size()
    var cycle: float = float(count) / clip.loop_fps
    var duration: float = cycle if clip.loop else maxf(0.01, action_duration)
    animation.length = duration
    animation.loop_mode = Animation.LOOP_LINEAR if clip.loop else Animation.LOOP_NONE
    var frame_track: int = _value_track(animation, "frame", true)
    for index in range(count):
        var at: float = float(index) / clip.loop_fps if clip.loop else (
            duration * float(index) / float(count))
        animation.track_insert_key(frame_track, at, int(clip.frames[index]))
    return animation
