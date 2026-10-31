extends SceneTree
## P1: posture is a deterministic authoritative resource, never an animation cue.
## All gameplay effects below are committed through versioned BattleModel.submit.
const Model = preload("res://scripts/battle_model.gd")
const Posture = preload("res://scripts/posture_system.gd")
const UNIT: int = 10000
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("P1_POSTURE: " + message)

func _ack(model) -> void:
    if model.state.animation_pending:
        model.acknowledge_animation(model.state.animation_ticket)

func _finish_clash(model) -> void:
    var count: int = 0
    while model.state.mode == "CLASH" and count < 6:
        var responder: int = int(model.state.clash.priority_actor_id)
        var passed: Dictionary = model.submit(model.request("PASS_REACTION",responder))
        _check(bool(passed.get("success",false)), "bounded clash pass accepted")
        _ack(model)
        count += 1
    _check(model.state.mode != "CLASH", "response stack terminates")

func _heavy(model) -> void:
    var actor = model.state.get_actor(0)
    actor.qi_u = 6 * UNIT
    var uid: String = model.cards.create_instance(actor,"tf_sunder","hand")
    _check(not uid.is_empty(), "P1 heavy card is registered")
    var sent: Dictionary = model.submit(model.request("PLAY_CARD",0,
        {"card_uid":uid,"usage_id":"heavy","target_id":1}))
    _check(bool(sent.get("success",false)), "heavy attack declares")
    _ack(model)
    if bool(sent.get("success",false)):
        _finish_clash(model)

func _event_count(model, kind: String) -> int:
    var result: int = 0
    for entry in model.state.events:
        if str(entry.get("type","")) == kind:
            result += 1
    return result

func _run() -> void:
    var model = Model.new()
    var attacker = model.state.get_actor(0)
    var defender = model.state.get_actor(1)
    defender.cell = Vector2i(7,4)
    _check(int(defender.stats.max_posture)==10 and defender.posture==0,
        "default maximum and initial posture")
    _check(model.cards.valid_effect({"type":"deal_posture","amount":4,"target":"enemy"})
        and model.cards.valid_effect({"type":"recover_posture","amount":3})
        and not model.cards.valid_effect({"type":"deal_posture","amount":-1})
        and not model.cards.valid_effect({"type":"recover_posture","amount":0}),
        "new effects follow the bounded schema")
    var hp_before: int = defender.hp_u
    _heavy(model)
    _check(defender.posture==4 and defender.hp_u<hp_before,
        "landed heavy adds posture strain after root attack resolves")
    _check(_event_count(model,"POSTURE_DAMAGED")==1 and
        _event_count(model,"POSTURE_BROKEN")==0,
        "first hit emits damage but not broken")
    var posture_before_ack: int = defender.posture
    var bogus_ack: Dictionary = model.acknowledge_animation(-1)
    _check(not bool(bogus_ack.get("success",false)) and
        defender.posture==posture_before_ack,
        "animation acknowledgements cannot mutate authoritative posture")
    _heavy(model)
    _check(defender.posture==8 and not model.statuses.has(1,"opening"),
        "two hits remain below break threshold")
    _heavy(model)
    _check(defender.posture==0 and model.statuses.has(1,"opening"),
        "third landed heavy breaks stance and applies opening")
    _check(_event_count(model,"POSTURE_BROKEN")==1,
        "one break event per reached threshold")
    var published: Dictionary = {}
    for a in model.snapshot(0).actors:
        if int(a.id)==1:
            published=a
    _check(int(published.get("posture",-1))==0 and
        int(published.get("max_posture",-1))==10,
        "read-only combat projection exposes posture to HUD and AI")

    var guarding = Model.new()
    var owner = guarding.state.get_actor(0)
    owner.posture = 6
    var guard_uid: String = guarding.cards.create_instance(owner,"tf_guard","hand")
    var guard_result: Dictionary = guarding.submit(guarding.request("PLAY_CARD",0,
        {"card_uid":guard_uid,"usage_id":"guard"}))
    _check(bool(guard_result.get("success",false)), "guard action accepted")
    _ack(guarding)
    _check(owner.posture==3 and owner.shield_u>=3*UNIT and
        _event_count(guarding,"POSTURE_RECOVERED")==1,
        "guard recovers posture and preserves existing shield rule")

    var missed = Model.new()
    var moved = missed.state.get_actor(1)
    moved.cell = Vector2i(7,4)
    var original_hp: int = moved.hp_u
    var attacker2 = missed.state.get_actor(0)
    attacker2.qi_u = 6*UNIT
    var miss_uid: String = missed.cards.create_instance(attacker2,"tf_sunder","hand")
    var declared: Dictionary = missed.submit(missed.request("PLAY_CARD",0,
        {"card_uid":miss_uid,"usage_id":"heavy","target_id":1}))
    _check(bool(declared.get("success",false)), "miss fixture declares legal attack")
    _ack(missed)
    # Simulate a successful defensive repositioning during the priority window.
    moved.cell = Vector2i(8,4)
    _finish_clash(missed)
    _check(moved.hp_u==original_hp and moved.posture==0 and
        _event_count(missed,"POSTURE_DAMAGED")==0,
        "missed or evaded root attack never applies on-hit posture")
    var bare = Posture.new()
    var before_invalid: int = owner.posture
    bare.impact(owner,0)
    bare.recover(owner,-3)
    _check(owner.posture==before_invalid,
        "pure helper ignores zero and negative amounts")
    owner.modifier_sources["qa:stance"]=[{"stat":"max_posture","op":"flat","value":5}]
    guarding.attributes.recalculate(owner)
    _check(int(owner.stats.max_posture)==15,
        "posture cap supports declarative equipment and status modifiers")

    print("P1_POSTURE_PASS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
