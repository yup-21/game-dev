extends "res://scripts/effects/effect_handler.gd"
## Demonstration of a new primitive without a CombatResolver match arm.

func valid_spec(effect: Dictionary) -> bool:
    if effect.get("type", "") != "r20_qi_by_status":
        return false
    if not effect.get("status_id") is String or str(effect.status_id).is_empty():
        return false
    var amount: Variant = effect.get("amount")
    return (amount is int or amount is float) and is_finite(float(amount)) and \
        float(amount) >= 0.0 and float(amount) <= 100.0

func execute(resolver, _source: int, target_id: int,
        effect: Dictionary, _choice: Dictionary) -> void:
    var actor = resolver.state.get_actor(target_id)
    if actor == null:
        return
    var status: Dictionary = actor.statuses.get(str(effect.status_id), {})
    var stacks: int = int(status.get("stacks", 0))
    if stacks > 0:
        resolver.gain_qi(target_id, float(effect.amount) * stacks)
