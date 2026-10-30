extends SceneTree
## End-to-end real six-unit bridge simulation using the production AI and map.
const Model = preload("res://scripts/battle_model.gd")
const Policy = preload("res://scripts/enemy_ai.gd")
const Director = preload("res://scripts/scenario_director.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var director = Director.new()
    if not director.load_error.is_empty():
        push_error(director.load_error)
        quit(1)
        return
    for seed in [2026, 2027, 2028]:
        var model = Model.new()
        model.reset(seed, -1, "tingfeng", director.battle_options("escort_ambush"))
        if model.state.actors.size() != 6 or model.state.outcome != "playing":
            push_error("Invalid bridge encounter")
            failures += 1
            continue
        var ai = Policy.new()
        var decisions := 0
        var turns: Dictionary = {}
        var rejected := false
        while model.state.outcome == "playing" and decisions < 4000 and model.state.action_no < 450:
            if model.state.animation_pending:
                var ack: Dictionary = model.acknowledge_animation(model.state.animation_ticket)
                if not bool(ack.get("success", false)):
                    rejected = true
                    break
            var snap: Dictionary = model.snapshot(0)
            var owner := int(snap.get("clash", {}).get("priority_actor_id", -1)) if snap.phase == "CLASH" else int(snap.active_id)
            if owner < 0:
                rejected = true
                break
            var context: Dictionary = model.decision_context(owner)
            var decision: Dictionary = ai.choose_action(context)
            if decision.is_empty() or not context.legal_actions.has(decision):
                rejected = true
                break
            var actor = model.state.get_actor(owner)
            if actor == null or actor.hp_u <= 0:
                rejected = true
                break
            turns[owner] = true
            var result: Dictionary = model.submit(model.request(str(decision.kind), owner, decision))
            if not bool(result.get("success", false)):
                rejected = true
                break
            decisions += 1
        if rejected or model.state.outcome == "playing":
            failures += 1
            push_error("Bridge auto-play stalled: seed=%d decisions=%d action=%d outcome=%s" % [seed, decisions, model.state.action_no, model.state.outcome])
        else:
            print("BRIDGE_AUTO_PASS seed=%d decisions=%d winner=%d actors=%d" % [seed, decisions, model.state.winning_team, turns.size()])
    quit(1 if failures > 0 else 0)
