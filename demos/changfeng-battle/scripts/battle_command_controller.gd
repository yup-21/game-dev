extends RefCounted
## The view's interaction gate. CommandDispatcher owns exact action matching;
## BattleModel alone owns validation, revision, costs and effects.
const Dispatcher = preload("res://scripts/battle_command_dispatcher.gd")

static func from_view(model: Variant, snapshot: Dictionary, player_decision: bool,
        auto_battle: bool, pending_ticket: int, kind: String,
        params: Dictionary = {}) -> Dictionary:
    if not player_decision or auto_battle or pending_ticket >= 0:
        return {"dispatched": false}
    if str(snapshot.get("outcome", "playing")) != "playing":
        return {"dispatched": false}
    var owner := int(snapshot.get("active_id", -1))
    if str(snapshot.get("phase", "")) == "CLASH":
        owner = int(snapshot.get("clash", {}).get("priority_actor_id", -1))
    if owner < 0:
        return {"dispatched": false}
    return Dispatcher.dispatch(model, owner, kind, params)
