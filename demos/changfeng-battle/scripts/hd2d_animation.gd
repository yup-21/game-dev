extends RefCounted
## Event-driven AnimationPlayer playback. Owns only presentation cursors, never battle state.
## Authored action profiles are preferred; legacy 6x4 sheets remain compatible.
const Facing = preload("res://scripts/actor_facing.gd")
const ActionTimeline = preload("res://scripts/battle_action_timeline.gd")
const NativeClips = preload("res://scripts/battle_native_sprite_clips.gd")
const DURATIONS := {"idle": 1.0, "move": 0.55, "walk": 0.55, "run": 0.55,
    "attack1": 0.62, "attack2": 0.62, "attack3": 0.62, "attack4": 0.62, "attack": 0.62,
    "guard": 0.38, "hit": 0.46, "evade": 0.38, "skill": 0.55, "combo": 0.78, "defeat": 1.0}
var tracks: Dictionary = {}
var timeline: Array = []
var stage_left: float = 0.0
var stage_profile: String = ""
var stage_elapsed: float = 0.0
var stage_duration: float = 0.0
var pending_cues: Array = []
var action_timeline = ActionTimeline.new()

func register_actor(id: int, sprite: Sprite2D, initial_facing: Vector2i = Vector2i.RIGHT,
        profile: WuxiaActorAnimationProfile = null) -> void:
    var initial: Vector2i = Facing.from_delta(initial_facing)
    var horizontal: Vector2i = initial if initial in [Facing.EAST, Facing.WEST] else Facing.EAST
    var artwork_left: bool = bool(sprite.get_meta("faces_left_unflipped", false))
    sprite.hframes = profile.columns if profile != null else 6
    sprite.vframes = profile.rows if profile != null else 4
    var player: AnimationPlayer = NativeClips.attach(sprite, action_timeline, profile)
    tracks[id] = {"sprite": sprite, "player": player, "state": "idle", "elapsed": 0.0,
        "duration": 1.0, "loop": true, "facing": initial,
        "horizontal": horizontal, "artwork_left": artwork_left,
        "base_scale": sprite.scale}
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
    if not tracks.has(id):
        return
    var track: Dictionary = tracks[id]
    var player: AnimationPlayer = track.player
    if not is_instance_valid(player) or not player.has_animation(state):
        return
    track.state = state
    track.elapsed = 0.0
    track.duration = player.get_animation(state).length
    track.loop = player.get_animation(state).loop_mode != Animation.LOOP_NONE
    tracks[id] = track
    player.stop()
    player.play(state)
    player.advance(0.0)

func events(emitted: Array) -> void:
    # Preserve the semantic event order; an attack, response and hit should
    # not overwrite each other's sprites in the same frame.
    timeline.clear()
    stage_left = 0.0
    pending_cues.clear()
    var skill_actors: Dictionary = {}
    for event in emitted:
        if str(event.get("type", "")) == "ACTION_PRESENTATION":
            skill_actors[int(event.get("actor_id", -1))] = true
    for event in emitted:
        var kind := str(event.get("type", ""))
        var actor_id := int(event.get("actor_id", -1))
        var target_id := int(event.get("defender_id", event.get("target_id", -1)))
        var animation := ""
        var id := actor_id
        if kind == "CHAIN_LINK_ADDED" and tracks.has(actor_id):
            set_facing(actor_id,Vector2i(event.get("facing",facing_for(actor_id))))
        if kind in ["SHIELD", "INTERCEPT_JUDGED", "ATTACK_INTERRUPTED",
                "CHAIN_LINK_CANCELED"] and skill_actors.has(actor_id):
            continue
        var semantic: String = action_timeline.animation_for_event(kind)
        animation = str(event.get("animation_id", ""))
        if animation.is_empty():
            animation = semantic
        if kind == "ACTION_PRESENTATION" and animation.is_empty():
            animation = "skill"
            semantic = "skill"
        elif kind == "ATTACK_DECLARED" and str(event.get("animation_id", "")).is_empty():
            animation = "attack1"
        elif kind in ["MOVE", "MOVE_FREE"] and str(event.get("animation_id", "")).is_empty():
            animation = "run" if bool(event.get("run", false)) else "walk"
        elif kind == "HP_DAMAGED" and bool(event.get("defeated", false)):
            animation = "defeat"
            semantic = "defeat"
        if kind == "ACTION_PRESENTATION":
            semantic = "skill"
        elif semantic.is_empty():
            semantic = animation
        if kind in ["ATTACK_MISSED", "DAMAGE", "HP_DAMAGED", "SCORCH_TICK"]:
            id = target_id if target_id >= 0 else actor_id
        if not animation.is_empty() and tracks.has(id):
            var player: AnimationPlayer = tracks[id].player
            if not is_instance_valid(player):
                continue
            if not player.has_animation(animation):
                push_warning("Missing actor animation %s; using fallback" % animation)
                var fallback: String = "skill" if kind == "ACTION_PRESENTATION" else semantic
                animation = fallback if player.has_animation(fallback) else "idle"
            var duration: float=action_timeline.duration_for(semantic,
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
                "facing": presentation_facing, "profile": semantic,
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
    stage_left = maxf(float(next.duration), float(tracks[int(next.id)].duration))
    stage_profile = str(next.get("profile", next.state))
    stage_duration = stage_left
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
        var dt: float = 0.0 if stage_transitioned else maxf(0.0, delta)
        track.elapsed = float(track.elapsed) + dt
        if state not in ["idle", "move", "walk", "run", "defeat"] and float(track.elapsed) >= float(track.duration):
            tracks[id] = track
            play(int(id), "idle")
            continue
        if state in ["move", "walk", "run"] and not bool(moving.get(id, false)):
            tracks[id] = track
            play(int(id), "idle")
            continue
        tracks[id] = track
        var player: AnimationPlayer = track.player
        if is_instance_valid(player):
            player.advance(dt)

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
