extends RefCounted
## Event-driven Sprite3D playback. Owns only animation cursors, never battle state.
## 6x4 atlas: idle, walk, attack, special (guard/hit/dodge/skill).
const FRAME_RATE := 9.0
const FRAMES_PER_ROW := 6
const STATE_ROW := {"idle": 0, "move": 1, "attack": 2, "guard": 3,
    "hit": 3, "evade": 3, "skill": 3, "defeat": 3}
const SINGLE_FRAMES := {"guard": 0, "hit": 1, "evade": 2, "skill": 4, "defeat": 1}
const DURATIONS := {"idle": 1.0, "move": 0.55, "attack": 0.62,
    "guard": 0.32, "hit": 0.40, "evade": 0.38, "skill": 0.55, "defeat": 1.0}
var tracks: Dictionary = {}
var timeline: Array = []
var stage_left: float = 0.0

func register_actor(id: int, sprite: Sprite3D) -> void:
    tracks[id] = {"sprite": sprite, "state": "idle", "elapsed": 0.0,
        "duration": 1.0, "loop": true}
    sprite.hframes = 6
    sprite.vframes = 4
    sprite.frame = 0

func play(id: int, state: String) -> void:
    if not tracks.has(id) or not STATE_ROW.has(state):
        return
    var track: Dictionary = tracks[id]
    track.state = state
    track.elapsed = 0.0
    track.duration = float(DURATIONS.get(state, 0.40))
    track.loop = state == "idle" or state == "move"
    tracks[id] = track

func events(emitted: Array) -> void:
    # Preserve the semantic event order; an attack, response and hit should
    # not overwrite each other's sprites in the same frame.
    timeline.clear()
    stage_left = 0.0
    for event in emitted:
        var kind := str(event.get("type", ""))
        var actor_id := int(event.get("actor_id", -1))
        var target_id := int(event.get("defender_id", event.get("target_id", -1)))
        var animation := ""
        var id := actor_id
        match kind:
            "MOVE":
                animation = "move"
            "ATTACK_DECLARED":
                animation = "attack"
            "COMBO_TRIGGERED":
                animation = "skill"
            "SHIELD", "INTERCEPT_JUDGED":
                animation = "guard"
            "ATTACK_MISSED":
                id = target_id
                animation = "evade"
            "DAMAGE", "HP_DAMAGED", "SCORCH_TICK":
                id = target_id if target_id >= 0 else actor_id
                animation = "hit"
            "ATTACK_INTERRUPTED":
                animation = "guard"
        if not animation.is_empty() and tracks.has(id):
            timeline.append({"id": id, "state": animation,
                "duration": float(DURATIONS.get(animation, 0.35))})
    _play_next()

func _play_next() -> void:
    if timeline.is_empty():
        stage_left = 0.0
        return
    var next: Dictionary = timeline.pop_front()
    play(int(next.id), str(next.state))
    stage_left = float(next.duration)

func remaining_seconds() -> float:
    var total: float = stage_left
    for event in timeline:
        total += float(event.duration)
    return total

func update(delta: float, moving: Dictionary = {}) -> void:
    var stage_transitioned: bool = false
    if stage_left > 0.0:
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
            if state == "evade" or state == "skill":
                index += mini(1, int(float(track.elapsed) / maxf(0.01, float(track.duration)) * 2.0))
        else:
            index = int(float(track.elapsed) * FRAME_RATE) % FRAMES_PER_ROW
        var sprite: Sprite3D = track.sprite
        if sprite != null:
            sprite.frame = int(STATE_ROW.get(state, 0)) * FRAMES_PER_ROW + index
        tracks[id] = track

func reset() -> void:
    timeline.clear()
    stage_left = 0.0
    for id in tracks.keys():
        play(int(id), "idle")
