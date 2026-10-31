extends RefCounted
## Pure deterministic modifier evaluator. Definitions never mutate actor state.
## All percentages are additive basis points (10000 = 100%), applied after flats.
const PRIMARY = ["STR","AGI","CON","MND"]
const DERIVED = ["max_hp","attack","defense","break_power","parry_power",
    "max_qi_u","qi_regen_u_per_100","hp_regen_u_per_100",
    "qi_cost_percent","charge_speed","move_budget"]
const ALL_STATS = ["STR","AGI","CON","MND","max_hp","attack","defense",
    "break_power","parry_power","max_qi_u","qi_regen_u_per_100",
    "hp_regen_u_per_100","qi_cost_percent","charge_speed","move_budget"]

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
    if not (value is int or value is float): return false
    var n: float = float(value)
    return is_finite(n) and n == floor(n) and n >= minimum and n <= maximum

static func valid_spec(spec: Variant) -> bool:
    if not spec is Dictionary: return false
    if spec.size() < 3 or spec.size() > 4: return false
    for key in spec:
        if key not in ["stat","op","value","stacks"]: return false
    if spec.get("stat") not in ALL_STATS: return false
    if spec.get("op") not in ["flat","percent_bp"]: return false
    if not _whole(spec.get("value"),-100000,100000): return false
    if spec.op == "percent_bp" and not _whole(spec.value,-9000,30000): return false
    return not spec.has("stacks") or _whole(spec.stacks,1,99)

func apply(base: Dictionary, sources: Dictionary) -> Dictionary:
    var result: Dictionary = base.duplicate(true)
    for stat in base:
        if stat not in ALL_STATS: continue
        var flats: int = 0
        var percentage_bp: int = 0
        for source in sources:
            var entries: Variant = sources[source]
            if not entries is Array: continue
            for spec in entries:
                if not valid_spec(spec) or str(spec.stat) != str(stat): continue
                var total: int = int(spec.value) * int(spec.get("stacks",1))
                if spec.op == "flat":
                    flats += total
                else:
                    percentage_bp += total
        # Percent bonuses/debuffs are additive, independent of source order.
        result[stat] = floori(float(int(base[stat]) + flats) *
            float(maxi(0,10000 + percentage_bp)) / 10000.0)
    return result
