extends SceneTree
## The UI command adapter must preserve the prior command routing behavior.
## Only BattleModel validates and commits effects; no view-side state mutation.
const Model = preload("res://scripts/battle_model.gd")
const Dispatcher = preload("res://scripts/battle_command_dispatcher.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("COMMAND_DISPATCH: " + message)

func _run() -> void:
    var model = Model.new()
    var owner: int = int(model.state.active_id)
    var initial_revision: int = int(model.state.revision)

    var unmatched: Dictionary = Dispatcher.dispatch(model, owner, "MOVE",
        {"target_cell": Vector2i(-1, -1)})
    _check(not bool(unmatched.get("dispatched", false)),
        "unmatched enumerated input remains ignored")
    _check(model.state.revision == initial_revision,
        "ignored input does not alter authoritative revision")

    var ended: Dictionary = Dispatcher.dispatch(model, owner, "END_ACTION")
    _check(bool(ended.get("dispatched", false))
        and bool(ended.get("result", {}).get("success", false)),
        "enumerated legal END_ACTION reaches BattleModel")
    _check(model.state.animation_pending,
        "an accepted request retains the model's presentation ticket")
    if model.state.animation_pending:
        var ack: Dictionary = model.acknowledge_animation(
            int(ended.get("result", {}).get("ticket", -1)))
        _check(bool(ack.get("success", false)),
            "accepted ticket can be acknowledged once")

    model.reset(2026, -1, "tingfeng",
        {"map_definition_path": "res://data/maps/rainy_bridge.tres"})
    owner = int(model.state.active_id)
    var before_mode: int = int(model.state.revision)
    var switched: Dictionary = Dispatcher.dispatch(model, owner,
        "SET_SPATIAL_MODE", {"spatial_mode": "FREE"})
    _check(bool(switched.get("dispatched", false))
        and bool(switched.get("result", {}).get("success", false)),
        "continuous mode command bypasses finite enumeration and validates")
    _check(model.state.spatial_mode == "FREE"
        and model.state.revision == before_mode + 1,
        "mode change remains authoritative and versioned")
    if model.state.animation_pending:
        model.acknowledge_animation(
            int(switched.get("result", {}).get("ticket", -1)))

    var before_invalid: int = int(model.state.revision)
    var bad_free: Dictionary = Dispatcher.dispatch(model, owner,
        "MOVE_FREE", {"target_position": Vector2(-10000, -10000)})
    _check(bool(bad_free.get("dispatched", false))
        and not bool(bad_free.get("result", {}).get("success", true)),
        "invalid continuous point reaches rules and is rejected")
    _check(model.state.revision == before_invalid,
        "rejected continuous command does not commit any revision")

    print("COMMAND_DISPATCH_PASS checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)
