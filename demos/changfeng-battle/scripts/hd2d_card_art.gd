extends RefCounted
## Explicit mapping: artwork never leaks card information or changes combat state.
## Art source: imported/in-use/legacy/ui/original/*.svg, original jade-and-ink vectors.
const PROBE = preload("res://assets/imported/in-use/legacy/ui/original/card_probe.svg")
const SUNDER = preload("res://assets/imported/in-use/legacy/ui/original/card_sunder.svg")
const STEP = preload("res://assets/imported/in-use/legacy/ui/original/card_step.svg")
const GUARD = preload("res://assets/imported/in-use/legacy/ui/original/card_guard.svg")
const CHANGE = preload("res://assets/imported/in-use/legacy/ui/original/card_change.svg")
const COMBO = preload("res://assets/imported/in-use/legacy/ui/original/card_combo.svg")
const BREATH = preload("res://assets/imported/in-use/legacy/ui/original/card_breath.svg")
const CLASH = preload("res://assets/imported/in-use/legacy/ui/original/card_clash.svg")
const SEAL = preload("res://assets/imported/in-use/legacy/ui/original/jade_seal.svg")

## Card art is bound to the currently imported vector assets.
## No legacy filename probing or hidden per-card image override.
static func _art(_name: String, vector_fallback: Texture2D) -> Texture2D:
    return vector_fallback

static func for_card(card: Dictionary) -> Texture2D:
    var id := str(card.get("definition_id", card.get("card_id", card.get("id", ""))))
    match id:
        "tf_probe", "wind_flow", "finger_seal", "needle_rain":
            return _art("probe", PROBE)
        "tf_sunder", "wind_final", "saber_charge", "saber_river", "finger_finish":
            return _art("sunder", SUNDER)
        "tf_step", "step_shadow", "step_swallow":
            return _art("step", STEP)
        "tf_guard", "tide_guard", "tide_return", "taixu_guard":
            return _art("guard", GUARD)
        "tf_change", "whip_coil", "whip_cut":
            return _art("change", CHANGE)
        "needle_hidden", "taixu_breath":
            return _art("breath", BREATH)
        "ember_fire", "ember_burst":
            return _art("clash", CLASH)
        "blood_burn", "blood_finish":
            return _art("combo", COMBO)
        _:
            # The name fallback also supports card snapshots without definition_id.
            var name := str(card.get("name", ""))
            if name.contains("游身") or name.contains("步"):
                return _art("step", STEP)
            if name.contains("化劲") or name.contains("护"):
                return _art("guard", GUARD)
            if name.contains("断岳") or name.contains("裂岳"):
                return _art("sunder", SUNDER)
            if name.contains("变锋") or name.contains("截势"):
                return _art("change", CHANGE)
            return _art("probe", PROBE)
