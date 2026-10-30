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

static var _painted_cache: Dictionary = {}

static func _art(name: String, vector_fallback: Texture2D) -> Texture2D:
    # Optional full-detail 384x512 art; keep an always-available vector fallback.
    if _painted_cache.has(name):
        return _painted_cache[name]
    var path := "res://assets/ui/original/painted/card_%s.png" % name
    var texture := vector_fallback
    if ResourceLoader.exists(path):
        var imported := ResourceLoader.load(path) as Texture2D
        if imported != null:
            texture = imported
    _painted_cache[name] = texture
    return texture

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
