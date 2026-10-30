extends RefCounted
## Presentation orchestrator for an uncontested clash. The BattleModel is
## still the sole authority: use the legal action list, not hand count,
## because cards may be unaffordable, mistimed or rejected by conditions.
const RESPONSE_ACTIONS := ["PLAY_CARD", "USE_ABILITY"]

static func has_response(actions: Array) -> bool:
    for action in actions:
        if str(action.get("kind", "")) in RESPONSE_ACTIONS:
            return true
    return false

static func should_auto_pass(phase: String, animation_pending: bool,
        actions: Array) -> bool:
    if phase != "CLASH" or animation_pending:
        return false
    var may_pass := false
    for action in actions:
        if str(action.get("kind", "")) == "PASS_REACTION":
            may_pass = true
        if str(action.get("kind", "")) in RESPONSE_ACTIONS:
            return false
    return may_pass
