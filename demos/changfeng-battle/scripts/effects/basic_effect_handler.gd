extends "res://scripts/effects/effect_handler.gd"
## Extracted existing primitives; delegates state mutation to CombatResolver APIs.

func valid_spec(effect: Dictionary) -> bool:
    return str(effect.get("type", "")) in [
        "gain_qi", "heal_hp", "add_shield", "apply_status", "consume_status"
    ]

func execute(resolver, _source: int, target_id: int,
        effect: Dictionary, _choice: Dictionary) -> void:
    match str(effect.type):
        "gain_qi":
            resolver.gain_qi(target_id, float(effect.amount))
        "heal_hp":
            resolver.heal_hp(target_id, float(effect.amount))
        "add_shield":
            resolver.add_shield(target_id, float(effect.amount),
                int(effect.get("expires_after_global_ticks", 100)))
        "apply_status":
            resolver.add_status(target_id, str(effect.status_id), [],
                int(effect.get("stacks", 1)))
        "consume_status":
            resolver.statuses.remove(target_id, str(effect.status_id))
            resolver.emit("STATUS_REMOVED", {
                "actor_id": target_id, "status_id": effect.status_id
            })
