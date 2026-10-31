extends SceneTree
const Coordinator = preload("res://scripts/battle_presentation_coordinator.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("PRESENTATION_TICKET: " + message)

func _run() -> void:
    var p = Coordinator.new()
    p.begin(7, 0.6)
    _check(p.ticket == 7 and p.wait_remaining >= 0.6, "semantic queue owns ticket")
    _check(p.advance(1.0, 0.3, false) == -1, "animation tail holds ticket")
    _check(p.advance(0.1, 0.0, true) == -1, "path movement holds ticket")
    _check(p.advance(0.1, 0.0, false) == 7, "finished queue releases ticket")
    _check(p.skip() == -1 and p.advance(1.0, 0.0, false) == -1,
        "finished ticket cannot acknowledge twice")
    p.begin(8, 0.35)
    _check(p.skip() == 8 and p.skip() == -1, "manual skip is idempotent")
    p.begin(9, 0.35)
    p.cancel()
    _check(p.ticket == -1 and p.skip() == -1, "cancel abandons presentation")
    p.begin(7, 0.0)
    _check(p.advance(1.0, 0.0, false) == -1,
        "replayed ticket is never acknowledged twice")
    p.reset_battle()
    p.begin(7, 0.0)
    _check(p.advance(1.0, 0.0, false) == 7,
        "new battle resets per-ticket idempotency scope")
    print("PRESENTATION_TICKET_PASS checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)
