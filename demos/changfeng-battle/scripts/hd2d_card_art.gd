extends RefCounted
## Explicit mapping: artwork never leaks card information or changes combat state.
## Art source: assets/ui/original/*.svg, original jade-and-ink vectors.
const PROBE = preload("res://assets/ui/original/card_probe.svg")
const SUNDER = preload("res://assets/ui/original/card_sunder.svg")
const STEP = preload("res://assets/ui/original/card_step.svg")
const GUARD = preload("res://assets/ui/original/card_guard.svg")
const CHANGE = preload("res://assets/ui/original/card_change.svg")
const COMBO = preload("res://assets/ui/original/card_combo.svg")
const BREATH = preload("res://assets/ui/original/card_breath.svg")
const CLASH = preload("res://assets/ui/original/card_clash.svg")
const SEAL = preload("res://assets/ui/original/jade_seal.svg")

static func for_card(card: Dictionary) -> Texture2D:
    var id := str(card.get("definition_id", card.get("card_id", card.get("id", ""))))
    match id:
        "tf_probe", "wind_flow", "finger_seal", "needle_rain":
            return PROBE
        "tf_sunder", "wind_final", "saber_charge", "saber_river", "finger_finish":
            return SUNDER
        "tf_step", "step_shadow", "step_swallow":
            return STEP
        "tf_guard", "tide_guard", "tide_return", "taixu_guard":
            return GUARD
        "tf_change", "whip_coil", "whip_cut":
            return CHANGE
        "needle_hidden", "taixu_breath":
            return BREATH
        "ember_fire", "ember_burst":
            return CLASH
        "blood_burn", "blood_finish":
            return COMBO
        _:
            # The name fallback also supports card snapshots without definition_id.
            var name := str(card.get("name", ""))
            if name.contains("游身") or name.contains("步"):
                return STEP
            if name.contains("化劲") or name.contains("护"):
                return GUARD
            if name.contains("断岳") or name.contains("裂岳"):
                return SUNDER
            if name.contains("变锋") or name.contains("截势"):
                return CHANGE
            return PROBE
