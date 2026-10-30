extends RefCounted
## Translates UI command intents into the existing authoritative BattleModel
## request/submit API. This adapter never mutates BattleState directly.
##
## Spatial commands have non-enumerable Vector2 destinations and must be
## validated transactionally by CombatRules. Legacy commands still need an
## exact match among legal_actions() before submission.
const DYNAMIC_COMMANDS := [
    "MOVE_FREE",
    "MOVE_AND_ATTACK",
    "SET_SPATIAL_MODE",
    "PLAY_CARD_FREE_MOVE",
]

static func dispatch(model: Variant, actor_id: int, kind: String,
        params: Dictionary = {}) -> Dictionary:
    if kind in DYNAMIC_COMMANDS:
        return {"dispatched": true,
            "result": model.submit(model.request(kind, actor_id, params))}

    for candidate in model.legal_actions(actor_id):
        if str(candidate.get("kind", "")) != kind:
            continue
        var matches := true
        for key in params:
            if not candidate.has(key) or candidate[key] != params[key]:
                matches = false
                break
        if matches:
            return {"dispatched": true,
                "result": model.submit(model.request(kind, actor_id, params))}

    # Previous HD2D behavior silently ignored input without a matching
    # enumerated action. Keep that behavior while extracting the adapter.
    return {"dispatched": false}
