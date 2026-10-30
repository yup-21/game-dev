extends SceneTree
const Model = preload("res://scripts/battle_model.gd")
const Command = preload("res://scripts/battle_command_controller.gd")
const Input = preload("res://scripts/battle_input_controller.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("BATTLE_INPUT: " + message)

func _run() -> void:
    var point := Vector2(453.0, 319.0)
    var free_move: Dictionary = Input.world_click("FREE", true, true,
        "", false, "", "", -1, point, {})
    _check(str(free_move.get("kind", "")) == "MOVE_FREE"
        and Vector2(free_move.get("params", {}).get("target_position", Vector2.ZERO)) == point,
        "FREE click retains exact free landing point")
    var enemy: Dictionary = Input.world_click("FREE", true, true,
        "", false, "", "", 2, point, {})
    _check(str(enemy.get("kind", "")) == "MOVE_AND_ATTACK"
        and int(enemy.get("params", {}).get("target_id", -1)) == 2,
        "FREE hostile click chooses atomic auto-approach")
    var dodge: Dictionary = Input.world_click("FREE", true, true,
        "PLAY_CARD", true, "u2", "dodge", -1, point, {})
    _check(str(dodge.get("kind", "")) == "PLAY_CARD_FREE_MOVE"
        and str(dodge.get("params", {}).get("card_uid", "")) == "u2",
        "selected martial step takes priority")
    _check(Input.world_click("GRID", true, true, "PLAY_CARD", false,
        "", "", 2, point, {}).is_empty(), "selected normal card remains targeted by UI")
    _check(Input.world_click("GRID", true, true, "", false,
        "", "", -1, point, {}).is_empty(), "invalid GRID landing remains ignored")
    var grid: Dictionary = Input.world_click("GRID", true, true, "",
        false, "", "", -1, point, {"target_cell": Vector2i(4, 6)})
    _check(str(grid.get("kind", "")) == "MOVE"
        and grid.get("params", {}).get("target_cell") == Vector2i(4, 6),
        "GRID click routes only an enumerated cell")

    var model = Model.new()
    var snapshot: Dictionary = model.snapshot(0)
    var revision: int = int(model.state.revision)
    for blocked in [
        Command.from_view(model, snapshot, false, false, -1, "END_ACTION"),
        Command.from_view(model, snapshot, true, true, -1, "END_ACTION"),
        Command.from_view(model, snapshot, true, false, 42, "END_ACTION")
    ]:
        _check(not bool(blocked.get("dispatched", true)),
            "blocked view cannot bypass human/auto/ticket gates")
    _check(int(model.state.revision) == revision, "view gates do not mutate model")

    var accepted: Dictionary = Command.from_view(
        model, snapshot, true, false, -1, "END_ACTION")
    _check(bool(accepted.get("result", {}).get("success", false)),
        "valid human command reaches authoritative model")
    _check(bool(model.state.animation_pending), "valid command gets presentation ticket")

    print("BATTLE_INPUT_PASS checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)
