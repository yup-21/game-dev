@tool
class_name WuxiaTechniqueEffectDefinition
extends Resource
## Explicit effect shape for original stage abilities.
@export_enum("gain_qi", "modify_attack_area", "cancel_chain_link") var effect_type: String = "gain_qi"
@export var amount: int = 0
@export var shape: String = ""
@export var target_ref: String = ""
@export var single_original_target_only: bool = false
@export var respect_obstacles: bool = false

func to_record() -> Dictionary:
    match effect_type:
        "gain_qi":
            return {"type": effect_type, "amount": amount}
        "modify_attack_area":
            if shape.is_empty(): return {}
            return {"type": effect_type, "shape": shape,
                "single_original_target_only": single_original_target_only,
                "respect_obstacles": respect_obstacles}
        "cancel_chain_link":
            if target_ref.is_empty(): return {}
            return {"type": effect_type, "target": target_ref}
    return {}
