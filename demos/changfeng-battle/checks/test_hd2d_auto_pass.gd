extends SceneTree
## Automatic, zero-prompt reaction pass (player and AI) using the same
## versioned BattleModel requests as manual play.
const Policy = preload("res://scripts/hd2d_response_policy.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("AUTO_PASS: " + description)

func _run() -> void:
    var pass_only := [{"kind": "PASS_REACTION"}]
    _check(Policy.should_auto_pass("CLASH", false, pass_only),
        "pass-only reaction must be skipped automatically")
    _check(not Policy.should_auto_pass("ACTION", false, pass_only),
        "action-phase must never be auto-passed")
    _check(not Policy.should_auto_pass("CLASH", true, pass_only),
        "animation ticket must block auto-pass")
    _check(not Policy.should_auto_pass("CLASH", false, []),
        "do not invent a pass absent from the legal set")
    _check(not Policy.should_auto_pass("CLASH", false,
        pass_only + [{"kind": "PLAY_CARD"}]),
        "available response card preserves the player's choice")
    _check(not Policy.should_auto_pass("CLASH", false,
        pass_only + [{"kind": "USE_ABILITY"}]),
        "available technique reaction preserves the player's choice")

    var packed: PackedScene = load("res://battle_hd2d.tscn") as PackedScene
    _check(packed != null, "illustrated battle scene loads")
    if packed == null:
        quit(1)
        return
    var scene: Node3D = packed.instantiate() as Node3D
    root.add_child(scene)
    await process_frame
    var model = scene.get("model")
    _check(model.state.actors.size() == 2,
        "standalone quick demo remains a duel")
    var attacker = model.state.get_actor(0)
    var defender = model.state.get_actor(1)
    attacker.cell = Vector2i(7, 4)
    defender.cell = Vector2i(8, 4)
    attacker.hand.clear()
    defender.hand.clear()
    scene.call("_refresh")
    var attack: Dictionary = {}
    for action in model.legal_actions(attacker.id):
        if str(action.get("kind", "")) == "BASIC_ATTACK":
            attack = action
            break
    _check(not attack.is_empty(), "seeded attacker can declare BASIC_ATTACK")
    if attack.is_empty():
        scene.queue_free()
        quit(1)
        return
    scene.call("_submit", "BASIC_ATTACK", {"target_id": defender.id})
    _check(model.state.mode == "CLASH" and model.state.animation_pending,
        "attack declares a pending clash, defender holds priority")
    _check(Policy.should_auto_pass("CLASH", false, model.legal_actions(defender.id)) == false,
        "do not auto-pass an unacknowledged attack animation")
    var started_ticket: int = int(model.state.animation_ticket)
    scene.set("animation_ticket", -1)
    scene.call("_accept", model.acknowledge_animation(started_ticket))
    var before_revision: int = int(model.state.revision)
    _check(scene.call("_auto_pass_unavailable_reactions"),
        "AI defender passes automatically with no eligible response")
    _check(model.state.mode == "CLASH" and int(model.state.clash.priority_actor_id) == attacker.id,
        "first pass yields priority to the player")
    _check(int(model.state.revision) == before_revision + 1
        and not model.state.animation_pending,
        "empty priority pass is acknowledged without unnecessary animation")
    _check(scene.call("_auto_pass_unavailable_reactions"),
        "player's empty response also passes without input")
    _check(model.state.mode != "CLASH" and int(model.state.revision) == before_revision + 2,
        "two consecutive passes resolve the attack through BattleModel")
    _check(model.state.animation_pending and int(scene.get("animation_ticket"))
        == int(model.state.animation_ticket),
        "attack outcome retains its combat animation ticket")
    _check(not Policy.should_auto_pass("CLASH", true, pass_only),
        "no pass can be submitted while combat resolution animates")
    _check(model.acknowledge_animation(int(model.state.animation_ticket)).success,
        "final combat animation can be acknowledged normally")
    print("AUTO_PASS_RESULT checks=%d failures=%d" % [checks, failures])
    scene.queue_free()
    await process_frame
    quit(1 if failures > 0 else 0)
