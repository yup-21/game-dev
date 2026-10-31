extends RefCounted
## One semantic event ticket at a time. Damage, CTB and cards are committed
## inside BattleModel before the effect animation starts; this class can only
## say when the already-committed presentation has finished.
var ticket := -1
var wait_remaining := 0.0
var acknowledged: Dictionary = {}

func begin(next_ticket: int, semantic_seconds: float) -> void:
    if next_ticket < 0:
        cancel()
        return
    if ticket == next_ticket:
        return
    ticket = next_ticket
    wait_remaining = maxf(0.35, semantic_seconds)

func advance(delta: float, semantic_seconds: float, paths_pending: bool) -> int:
    if ticket < 0:
        return -1
    wait_remaining = maxf(0.0, wait_remaining - maxf(0.0, delta))
    if wait_remaining > 0.0 or semantic_seconds > 0.0 or paths_pending:
        return -1
    return _consume_ticket()

func skip() -> int:
    # Both manual skip and normal completion use the same idempotent gate.
    return _consume_ticket()

func _consume_ticket() -> int:
    if ticket < 0:
        return -1
    var finished := ticket
    ticket = -1
    wait_remaining = 0.0
    if acknowledged.has(finished):
        return -1
    acknowledged[finished] = true
    return finished

func cancel() -> void:
    # Used by reset/scene changes and non-pending model responses.
    ticket = -1
    wait_remaining = 0.0

func reset_battle() -> void:
    cancel()
    acknowledged.clear()
