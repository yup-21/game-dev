extends SceneTree
const Hand = preload("res://scripts/battle_hand_view.gd")
var rendered: Array = []
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("BATTLE_HUD: " + message)

func _none(_uid: String, _usage: String) -> Array:
    return []

func _false(_uid: String, _usage: String) -> bool:
    return false

func _playable(uid: String, _usage: String) -> bool:
    return uid == "hit"

func _record(card: Dictionary, usage: Dictionary, playable: bool) -> void:
    rendered.append({"uid": card.uid, "usage": usage.id, "playable": playable})

func _run() -> void:
    var hand: Array = [
        {"uid": "hit", "usages": [
            {"id": "stab", "timing": "ACTION"}, {"id": "deflect", "timing": "CLASH"}]},
        {"uid": "guard", "usages": [
            {"id": "guard", "timing": "CLASH"}, {"id": "ready", "timing": "ACTION"}]}
    ]
    var result: Dictionary = Hand.render_physical_hand(hand, true, false,
        Callable(self, "_none"), Callable(self, "_playable"),
        Callable(self, "_false"), Callable(self, "_record"))
    _check(int(result.displayed_count) == 2 and int(result.playable_count) == 2,
        "all physical cards remain visible and playable usages counted")
    _check(rendered.size() == 3 and rendered[0].playable
        and rendered[1].playable and not rendered[2].playable,
        "one disabled tile for unplayable physical card")
    _check(str(rendered[2].usage) == "ready",
        "fallback prioritizes ACTION face over CLASH-only usage")

    rendered.clear()
    result = Hand.render_physical_hand(hand, false, false,
        Callable(self, "_none"), Callable(self, "_false"),
        Callable(self, "_false"), Callable(self, "_record"))
    _check(int(result.displayed_count) == 2 and int(result.playable_count) == 0,
        "hand survives unavailable decision and animation")
    _check(rendered.size() == 2 and not rendered[0].playable and not rendered[1].playable,
        "both physical cards are disabled, not deleted")

    rendered.clear()
    result = Hand.render_physical_hand(hand, true, true,
        Callable(self, "_none"), Callable(self, "_playable"),
        Callable(self, "_false"), Callable(self, "_record"))
    _check(rendered.size() == 2 and int(result.playable_count) == 0,
        "auto-pass CLASH retains hand while suppressing responses")
    print("BATTLE_HUD_PASS checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)
