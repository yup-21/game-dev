extends RefCounted
## Event-driven Sprite2D playback. Owns only animation cursors, never battle state.
## 6x4 atlas: idle, walk, attack, special (guard/hit/dodge/skill).
const Facing = preload("res://scripts/actor_facing.gd")
const ActionTimeline = preload("res://scripts/battle_action_timeline.gd")
const FRAME_RATE := 9.0
const FRAMES_PER_ROW := 6
const STATE_ROW := {"idle": 0, "move": 1, "attack": 2, "guard": 3,
    "hit": 3, "evade": 3, "skill": 3, "combo": 3, "defeat": 3}
const SINGLE_FRAMES := {"guard": 0, "hit": 1, "evade": 2, "skill": 4, "combo": 4, "defeat": 1}
const DURATIONS := {"idle": 1.0, "move": 0.55, "attack": 0.62,
    "guard": 0.38, "hit": 0.46, "evade": 0.38, "skill": 0.55, "combo": 0.78, "defeat": 1.0}
var tracks: Dictionary = {}
var timeline: Array = []
var stage_left: float = 0.0
var stage_profile: String = ""
var stage_elapsed: float = 0.0
var stage_duration: float = 0.0
var pending_cues: Array = []
var action_timeline = ActionTimeline.new()

func register_actor(id: int, sprite: Sprite2D, initial_facing: Vector2i = Vector2i.RIGHT) -> void:
    var initial: Vector2i = Facing.from_delta(initial_facing)
    var horizontal: Vector2i = initial if initial in [Facing.EAST, Facing.WEST] else Facing.EAST
    var artwork_left: bool = bool(sprite.get_meta("faces_left_unflipped", false))
    tracks[id] = {"sprite": sprite, "state": "idle", "elapsed": 0.0,
        "duration": 1.0, "loop": true, "facing": initial,
        "horizontal": horizontal, "artwork_left": artwork_left,
        "base_scale": sprite.scale}
    sprite.hframes = 6
    sprite.vframes = 4
    sprite.frame = 0
    sprite.flip_h = (horizontal == Facing.EAST) if artwork_left else (horizontal == Facing.WEST)

func set_facing(id: int, facing: Vector2i) -> void:
    if not tracks.has(id): return
    var track: Dictionary = tracks[id]
    track.facing = Facing.from_delta(facing,track.facing)
    # A 6x4 atlas has no dedicated north/south poses. Preserve the last
    # horizontal silhouette instead of flipping on each vertical step.
    if Vector2i(track.facing) in [Facing.EAST, Facing.WEST]:
        track.horizontal = track.facing
    tracks[id] = track
    var sprite: Sprite2D = track.sprite
    if sprite != null:
        var horizontal: Vector2i = Vector2i(track.horizontal)
        var artwork_left: bool = bool(track.artwork_left)
        sprite.flip_h = (horizontal == Facing.EAST) if artwork_left else (horizontal == Facing.WEST)

func facing_for(id: int) -> Vector2i:
    return Vector2i(tracks[id].facing) if tracks.has(id) else Facing.EAST

func play(id: int, state: String) -> void:
    if not tracks.has(id) or not STATE_ROW.has(state):
        return
    var track: Dictionary = tracks[id]
    track.state = state
    track.elapsed = 0.0
    track.duration = action_timeline.duration_for(state, float(DURATIONS.get(state, 0.40)))
    track.loop = state == "idle" or state == "move"
    tracks[id] = track

func events(emitted: Array) -> void:
    # Preserve the semantic event order; an attack, response and hit should
    # not overwrite each other's sprites in the same frame.
    timeline.clear()
    stage_left = 0.0
    pending_cues.clear()
    for event in emitted:
        var kind := str(event.get("type", ""))
        var actor_id := int(event.get("actor_id", -1))
        var target_id := int(event.get("defender_id", event.get("target_id", -1)))
        var animation := ""
        var id := actor_id
        if kind == "CHAIN_LINK_ADDED" and tracks.has(actor_id):
            set_facing(actor_id,Vector2i(event.get("facing",facing_for(actor_id))))
        animation = action_timeline.animation_for_event(kind)
        if kind in ["ATTACK_MISSED", "DAMAGE", "HP_DAMAGED", "SCORCH_TICK"]:
            id = target_id if target_id >= 0 else actor_id
        if not animation.is_empty() and tracks.has(id):
            var duration: float=action_timeline.duration_for(animation,
                float(DURATIONS.get(animation, 0.35)))
            var presentation_facing: Vector2i=Vector2i(event.get("facing",facing_for(id)))
            if kind == "MOVE":
                var path: Array=event.get("path",[])
                duration=maxf(duration,float(path.size()) * 0.33)
                if not path.is_empty():
                    presentation_facing=Facing.from_delta(
                        Vector2i(path[0])-Vector2i(event.get("from",Vector2i.ZERO)),
                        presentation_facing)
            elif kind == "MOVE_FREE":
                var route: PackedVector2Array=event.get("path",PackedVector2Array())
                var distance: float=0.0
                for index in range(1,route.size()):
                    distance+=route[index-1].distance_to(route[index])
                duration=maxf(duration,distance/160.0)
                if route.size()>1:
                    var heading: Vector2=route[1]-route[0]
                    presentation_facing=Facing.from_delta(Vector2i(roundi(heading.x),roundi(heading.y)),presentation_facing)
            timeline.append({"id": id, "state": animation,
                "facing": presentation_facing, "profile": animation,
                "duration": duration})
    _play_next()

func _play_next() -> void:
    if timeline.is_empty():
        stage_left = 0.0
        stage_profile = ""
        stage_duration = 0.0
        stage_elapsed = 0.0
        return
    var next: Dictionary = timeline.pop_front()
    set_facing(int(next.id),Vector2i(next.facing))
    play(int(next.id), str(next.state))
    stage_left = float(next.duration)
    stage_profile = str(next.get("profile", next.state))
    stage_duration = float(next.duration)
    stage_elapsed = 0.0

func remaining_seconds() -> float:
    var total: float = stage_left
    for event in timeline:
        total += float(event.duration)
    return total

func update(delta: float, moving: Dictionary = {}) -> void:
    var stage_transitioned: bool = false
    if stage_left > 0.0:
        var previous: float = stage_elapsed
        stage_elapsed = minf(stage_duration, stage_elapsed + maxf(0.0, delta))
        pending_cues.append_array(action_timeline.cues_between(
            stage_profile, previous, stage_elapsed, stage_duration))
        stage_left = maxf(0.0, stage_left - delta)
        if stage_left <= 0.0:
            _play_next()
            stage_transitioned = true
    for id in tracks.keys():
        var track: Dictionary = tracks[id]
        var state: String = str(track.state)
        track.elapsed = float(track.elapsed) + (0.0 if stage_transitioned else delta)
        if state != "idle" and state != "move" and float(track.elapsed) >= float(track.duration):
            state = "idle"
            track.state = state
            track.elapsed = 0.0
        if state == "move" and not bool(moving.get(id, false)):
            state = "idle"
            track.state = state
            track.elapsed = 0.0
        var index: int = 0
        if SINGLE_FRAMES.has(state):
            index = int(SINGLE_FRAMES[state])
            if state in ["evade", "skill", "combo"]:
                index += mini(1, int(float(track.elapsed) / maxf(0.01, float(track.duration)) * 2.0))
        else:
            index = int(float(track.elapsed) * FRAME_RATE) % FRAMES_PER_ROW
        var sprite: Sprite2D = track.sprite
        if sprite != null:
            sprite.frame = int(STATE_ROW.get(state, 0)) * FRAMES_PER_ROW + index
            # Pose accents stay presentation-only and never touch BattleModel.
            var phase: float = clampf(float(track.elapsed) / maxf(0.01, float(track.duration)), 0.0, 1.0)
            var thrust: float = sin(phase * PI)
            var target_scale := Vector2.ONE
            var tilt := 0.0
            match state:
                "move":
                    target_scale.x = 1.0 + sin(float(track.elapsed) * 18.0) * 0.035
                    tilt = sin(float(track.elapsed) * 12.0) * 0.045
                "attack", "combo", "skill":
                    target_scale = Vector2(1.0 + thrust * 0.14, 1.0 - thrust * 0.09)
                    tilt = -thrust * (0.18 if state == "combo" else 0.11)
                "guard":
                    target_scale = Vector2(1.0 + thrust * 0.08, 1.0 - thrust * 0.13)
                "hit":
                    target_scale = Vector2(1.0 - thrust * 0.10, 1.0 + thrust * 0.07)
                    tilt = thrust * 0.15
                "evade":
                    tilt = thrust * 0.14
            sprite.scale = sprite.scale.lerp(Vector2(track.base_scale) * target_scale, minf(1.0, delta * 18.0))
            sprite.rotation = lerpf(sprite.rotation, tilt, minf(1.0, delta * 17.0))
        tracks[id] = track

func reset() -> void:
    timeline.clear()
    stage_left = 0.0
    stage_profile = ""
    stage_duration = 0.0
    stage_elapsed = 0.0
    pending_cues.clear()
    for id in tracks.keys():
        play(int(id), "idle")

## Queryable visual metadata. BattleModel remains the ONLY rule authority.
func action_phase() -> String:
    return action_timeline.phase_at(stage_profile, stage_elapsed, stage_duration)

func visual_window_open(kind: String) -> bool:
    return action_timeline.window_open(stage_profile, kind,
        stage_elapsed, stage_duration)

func drain_action_cues() -> Array:
    var delivered: Array = pending_cues.duplicate(true)
    pending_cues.clear()
    return delivered
