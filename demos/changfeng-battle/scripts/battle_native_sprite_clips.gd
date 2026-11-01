extends RefCounted
## Sprite2D atlas playback uses Godot AnimationPlayer/Animation resources.
## All tracks are cosmetic; event windows and combat authority stay elsewhere.
const FRAME_RATE := 9.0
const FRAMES_PER_ROW := 6
const POSE_SAMPLES_PER_SECOND := 30.0
const STATE_ROW := {"idle": 0, "move": 1, "attack": 2, "guard": 3,
    "hit": 3, "evade": 3, "skill": 3, "combo": 3, "defeat": 3}
const SINGLE_FRAMES := {"guard": 0, "hit": 1, "evade": 2,
    "skill": 4, "combo": 4, "defeat": 1}

static func attach(sprite: Sprite2D, timeline: Variant) -> AnimationPlayer:
    var player := AnimationPlayer.new()
    player.name = "NativeSpriteAnimation"
    player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    player.root_node = NodePath("..")
    sprite.add_child(player)
    var library := AnimationLibrary.new()
    for state in STATE_ROW.keys():
        var fallback_duration: float = 0.62
        match str(state):
            "idle": fallback_duration = 1.0
            "move", "skill": fallback_duration = 0.55
            "guard", "evade": fallback_duration = 0.38
            "hit": fallback_duration = 0.46
            "combo": fallback_duration = 0.78
            "defeat": fallback_duration = 1.0
        var duration: float = timeline.duration_for(str(state), fallback_duration)
        library.add_animation(str(state), _clip(str(state), duration, sprite.scale))
    player.add_animation_library("", library)
    player.play("idle")
    player.advance(0.0)
    return player

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
    var looping: bool = state in ["idle", "move"]
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
            "move":
                size.x = 1.0 + sin(at * 18.0) * 0.035
                tilt = sin(at * 12.0) * 0.045
            "attack", "combo", "skill":
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
