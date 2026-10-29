extends RefCounted
## Adapter between the HD-2D presentation and the existing authoritative model.
## Never manufactures actions or modifies combat state directly.
const Model = preload("res://scripts/battle_model.gd")

var model = Model.new()
var observer_id: int = 0

func start(seed: int, encounter_options: Dictionary = {}) -> void:
    model.reset(seed, -1, "tingfeng", encounter_options)
    observer_id = _first_player_id()

func _first_player_id() -> int:
    for actor in model.state.actors:
        if actor.team_id == 0 and actor.controller == "PLAYER":
            return actor.id
    return -1

func owner_id() -> int:
    var view: Dictionary = model.snapshot(observer_id)
    if str(view.get("phase", "")) == "CLASH":
        return int(view.get("clash", {}).get("priority_actor_id", -1))
    return int(view.get("active_id", -1))

func is_player_turn() -> bool:
    var actor = model.state.get_actor(owner_id())
    return actor != null and actor.controller == "PLAYER"

func visible_snapshot() -> Dictionary:
    var id: int = owner_id()
    var actor = model.state.get_actor(id)
    if actor != null and actor.controller == "PLAYER":
        observer_id = id
    return model.snapshot(observer_id)

func legal_actions() -> Array:
    if not is_player_turn():
        return []
    return model.legal_actions(owner_id())

func submit_legal(action: Dictionary) -> Dictionary:
    if not is_player_turn():
        return model.failure("NOT_PLAYER_TURN", "当前不属于玩家行动")
    var id: int = owner_id()
    for candidate in model.legal_actions(id):
        if candidate == action:
            var params: Dictionary = action.duplicate(true)
            params.erase("kind")
            params.erase("actor_id")
            return model.submit(model.request(str(action.get("kind", "")), id, params))
    return model.failure("ILLEGAL_ACTION", "行动不在当前合法行动集合内")

func acknowledge(ticket: int) -> Dictionary:
    return model.acknowledge_animation(ticket)
