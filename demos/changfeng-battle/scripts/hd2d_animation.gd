extends RefCounted
## Event-driven AnimationPlayer playback. Owns only presentation cursors, never battle state.
## Authored action profiles are preferred; legacy 6x4 sheets remain compatible.
const Facing = preload("res://scripts/actor_facing.gd")
const ActionTimeline = preload("res://scripts/battle_action_timeline.gd")
const NativeClips = preload("res://scripts/battle_native_sprite_clips.gd")
const DURATIONS := {"idle": 1.0, "move": 0.55, "attack": 0.62,
    "guard": 0.38, "hit": 0.46, "evade": 0.38, "skill": 0.55, "combo": 0.78, "defeat": 1.0}
var tracks: Dictionary = {}
var timeline: Array = []
var stage_left: float = 0.0
var stage_profile: String = ""
var stage_elapsed: float = 0.0
var stage_duration: float = 0.0
var stage_event: Dictionary = {}
var pending_cues: Array = []
var action_timeline = ActionTimeline.new()

func register_actor(id: int, sprite: Sprite2D, initial_facing: Vector2i = Vector2i.RIGHT,
        profile: WuxiaActorAnimationProfile = null) -> void:
    var initial: Vector2i = Facing.from_delta(initial_facing)
    var horizontal: Vector2i = initial if initial in [Facing.EAST, Facing.WEST] else Facing.EAST
    var artwork_left: bool = bool(sprite.get_meta("faces_left_unflipped", false))
    sprite.hframes = profile.idle_columns() if profile != null else 6
    sprite.vframes = profile.idle_rows() if profile != null else 4
    var player: AnimationPlayer = NativeClips.attach(sprite, action_timeline, profile)
    tracks[id] = {"sprite": sprite, "player": player, "state": "idle", "elapsed": 0.0,
        "duration": 1.0, "loop": true, "facing": initial,
        "horizontal": horizontal, "artwork_left": artwork_left,
        "base_scale": sprite.scale, "defeated": false}
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

func play(id: int, state: String, duration: float = -1.0) -> void:
    if not tracks.has(id):
        return
    var track: Dictionary = tracks[id]
    if bool(track.defeated) and state != "defeat":
        return
    var player: AnimationPlayer = track.player
    if not is_instance_valid(player) or not player.has_animation(state):
        push_error("Actor %d requested an undefined animation: %s" % [id, state])
        return
    track.state = state
    track.elapsed = 0.0
    track.loop = player.get_animation(state).loop_mode != Animation.LOOP_NONE
    var semantic: String = NativeClips.semantic_for(state)
    track.duration = duration if duration > 0.0 else action_timeline.duration_for(
        semantic, NativeClips.fallback_duration_for(semantic))
    tracks[id] = track
    player.stop()
    player.speed_scale = 1.0 if bool(track.loop) else (
        player.get_animation(state).length / maxf(0.01, float(track.duration)))
    player.play(state)
    player.advance(0.0)

func enqueue_defeat(id: int) -> void:
    if not tracks.has(id) or bool(tracks[id].defeated):
        return
    var track: Dictionary = tracks[id]
    track.defeated = true
    tracks[id] = track
    timeline.append({"id": id, "state": "defeat", "facing": facing_for(id),
        "profile": "defeat", "duration": action_timeline.duration_for("defeat", 1.0),
        "event_type": "DEFEAT"})
    if stage_left <= 0.0:
        _play_next()

func _chosen_action(event: Dictionary, semantic: String, id: int,
        kind: String) -> String:
    var requested: String = str(event.get("animation_action", ""))
    if requested.is_empty():
        requested = str(event.get("animation_id", ""))
    if not requested.is_empty():
        return requested
    if kind in ["MOVE", "MOVE_FREE"]:
        var distance: float = 0.0
        if kind == "MOVE":
            distance = float(event.get("path", []).size()) * 40.0
        else:
            var path: PackedVector2Array = event.get("path", PackedVector2Array())
            for index in range(1, path.size()):
                distance += path[index - 1].distance_to(path[index])
        return "run" if distance >= 180.0 else "walk"
    # All semantic actions (including basic attack and combo) resolve through
    # this actor's Profile. There is no implicit attack1/attack4 selection.
    return semantic

func _default_trigger(semantic: String) -> String:
    match semantic:
        "attack": return "strike_active"
        "combo": return "combo_visual_active"
        "skill": return "skill_visual_active"
        "guard": return "guard_active"
        "evade": return "evade_visual_start"
    return ""

func events(emitted: Array) -> void:
    # Keep semantic order. Ignore card/ability declarations if an attack event
    # for the same usage follows; one skill invocation plays one action.
    timeline.clear()
    stage_left = 0.0
    pending_cues.clear()
    var attacks: Dictionary = {}
    var presentation_actors: Dictionary = {}
    for event in emitted:
        if str(event.get("type", "")) == "ATTACK_DECLARED":
            var attack_key := str(event.get("actor_id", -1)) + ":" + str(
                event.get("definition_id", "")) + ":" + str(event.get("usage_id", ""))
            attacks[attack_key] = true
    for event in emitted:
        if str(event.get("type", "")) == "ACTION_PRESENTATION":
            presentation_actors[int(event.get("actor_id", -1))] = true
    for event in emitted:
        var kind: String = str(event.get("type", ""))
        var actor_id: int = int(event.get("actor_id", -1))
        var target_id: int = int(event.get("defender_id", event.get("target_id", -1)))
        if kind == "CHAIN_LINK_ADDED" and tracks.has(actor_id):
            set_facing(actor_id, Vector2i(event.get("facing", facing_for(actor_id))))
        var semantic: String = action_timeline.animation_for_event(kind)
        if kind in ["SHIELD", "INTERCEPT_JUDGED", "ATTACK_INTERRUPTED",
                "CHAIN_LINK_CANCELED"] and presentation_actors.has(actor_id):
            continue
        if kind == "ACTION_PRESENTATION":
            semantic = "skill"
        if kind in ["CARD_PLAYED", "ABILITY_USED"]:
            var key := str(actor_id) + ":" + str(event.get("definition_id", event.get(
            "technique_id", ""))) + ":" + str(event.get("usage_id", event.get("node_id", "")))
            if attacks.has(key) or (str(event.get("animation_action", "")).is_empty()
                    and str(event.get("vfx_slot", "")).is_empty()):
                continue
            semantic = NativeClips.semantic_for(str(event.get("animation_action", "skill")))
        var id: int = actor_id
        if kind in ["ATTACK_MISSED", "DAMAGE", "HP_DAMAGED", "SCORCH_TICK"]:
            id = target_id if target_id >= 0 else actor_id
        if semantic.is_empty() or not tracks.has(id) or bool(tracks[id].defeated):
            continue
        var action: String = _chosen_action(event, semantic, id, kind)
        var player: AnimationPlayer = tracks[id].player
        if not is_instance_valid(player):
            continue
        if not player.has_animation(action):
            push_error("Actor %d has no configured animation '%s' for event '%s'" %
                [id, action, kind])
            continue
        var duration: float = action_timeline.duration_for(
            semantic, NativeClips.fallback_duration_for(semantic))
        var presentation_facing: Vector2i = Vector2i(event.get("facing", facing_for(id)))
        if kind == "MOVE":
            var path: Array = event.get("path", [])
            duration = maxf(duration, float(path.size()) * 0.33)
            if not path.is_empty():
                presentation_facing = Facing.from_delta(
                    Vector2i(path[0]) - Vector2i(event.get("from", Vector2i.ZERO)),
                    presentation_facing)
        elif kind == "MOVE_FREE":
            var route: PackedVector2Array = event.get("path", PackedVector2Array())
            var distance: float = 0.0
            for index in range(1, route.size()):
                distance += route[index - 1].distance_to(route[index])
            duration = maxf(duration, distance / 160.0)
            if route.size() > 1:
                var heading: Vector2 = route[1] - route[0]
                presentation_facing = Facing.from_delta(
                    Vector2i(roundi(heading.x), roundi(heading.y)), presentation_facing)
        timeline.append({"id": id, "state": action, "profile": semantic,
            "facing": presentation_facing, "duration": duration, "event_type": kind,
            "vfx_slot": str(event.get("vfx_slot", "")),
            "vfx_trigger": str(event.get("vfx_trigger", ""))})
    _play_next()

func _play_next() -> void:
    if timeline.is_empty():
        stage_left = 0.0
        stage_profile = ""
        stage_duration = 0.0
        stage_elapsed = 0.0
        stage_event.clear()
        return
    var next: Dictionary = timeline.pop_front()
    set_facing(int(next.id), Vector2i(next.facing))
    play(int(next.id), str(next.state), float(next.duration))
    stage_left = float(next.duration)
    stage_profile = str(next.get("profile", next.state))
    stage_duration = float(next.duration)
    stage_elapsed = 0.0
    stage_event = next

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
        var cues: Array = action_timeline.cues_between(
            stage_profile, previous, stage_elapsed, stage_duration)
        for cue in cues:
            var delivered: Dictionary = cue.duplicate(true)
            delivered["actor_id"] = int(stage_event.get("id", -1))
            delivered["event_type"] = str(stage_event.get("event_type", ""))
            delivered["vfx_slot"] = str(stage_event.get("vfx_slot", ""))
            delivered["vfx_trigger"] = str(stage_event.get(
                "vfx_trigger", _default_trigger(stage_profile)))
            if str(delivered.vfx_trigger).is_empty():
                delivered.vfx_trigger = _default_trigger(stage_profile)
            pending_cues.append(delivered)
        stage_left = maxf(0.0, stage_left - delta)
        if stage_left <= 0.0:
            _play_next()
            stage_transitioned = true
    for id in tracks.keys():
        var track: Dictionary = tracks[id]
        var state: String = str(track.state)
        var dt: float = 0.0 if stage_transitioned else maxf(0.0, delta)
        track.elapsed = float(track.elapsed) + dt
        if state == "defeat":
            # A defeated actor retains the final authored frame indefinitely.
            var fallen_player: AnimationPlayer = track.player
            if is_instance_valid(fallen_player):
                fallen_player.advance(minf(dt, maxf(0.0,
                    float(track.duration) - float(track.elapsed) + dt)))
            tracks[id] = track
            continue
        if not bool(track.loop) and state != "idle" and \
                float(track.elapsed) >= float(track.duration):
            tracks[id] = track
            play(int(id), "idle")
            continue
        if state in ["walk", "run", "move"] and not bool(moving.get(id, false)):
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
    stage_event.clear()
    for id in tracks.keys():
        var track: Dictionary = tracks[id]
        track.defeated = false
        tracks[id] = track
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
