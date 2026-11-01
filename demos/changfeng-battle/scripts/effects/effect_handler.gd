extends RefCounted
## Interface for pure rule effects. Handlers run under CombatResolver authority.

func valid_spec(_effect: Dictionary) -> bool:
    return false

func execute(_resolver, _source: int, _target_id: int,
        _effect: Dictionary, _choice: Dictionary) -> void:
    pass
