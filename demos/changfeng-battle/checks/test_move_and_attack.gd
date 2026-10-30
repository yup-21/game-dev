extends SceneTree
## Atomic, authority-owned move+attack regression. Tests include reaction entry
## and cards, rather than testing only the spatial search helper.
const Model = preload("res://scripts/battle_model.gd")
const MapBake = preload("res://scripts/map_bake.gd")
var checks: int = 0
var failures: int = 0

func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("APPROACH_ATTACK: " + label)

func _new_model():
    var m = Model.new()
    m.reset(2026,-1,"tingfeng",{"map_definition_path":MapBake.DEFAULT_PATH})
    return m

func _attack_card(m,actor) -> Dictionary:
    for uid in actor.hand + actor.draw_pile:
        for usage in m.cards.canonical_definition(str(uid)).get("usages",[]):
            if str(usage.get("timing","")) != "ACTION" or str(usage.get("target",{}).get("kind","")) != "enemy_actor":
                continue
            var attack: bool=false
            for effect in usage.get("effects",[]):
                if str(effect.get("type",""))=="deal_damage":
                    attack=true
            if attack:
                if not actor.hand.has(uid):
                    actor.draw_pile.erase(uid)
                    actor.hand.append(uid)
                return {"card_uid":str(uid),"usage_id":str(usage.id)}
    return {}

func _run() -> void:
    var m = _new_model()
    _check(m.state.outcome=="playing" and m.state.spatial!=null, "mapped encounter active")
    var id: int=m.state.active_id
    var actor=m.state.get_actor(id)
    var target=m.state.get_actor(1 if id==0 else 0)
    var from_position: Vector2=actor.position
    var old_qi: int=actor.qi_u
    var req: Dictionary=m.request("MOVE_AND_ATTACK",id,{"attack_kind":"BASIC_ATTACK","target_id":target.id})
    var check: Dictionary=m.validate(req)
    _check(bool(check.get("success",false)),"target outside basic attack range has legal approach")
    _check(actor.position==from_position and actor.qi_u==old_qi and not actor.basic_attack_used,
        "precommit validation has no authority mutation")
    var result: Dictionary=m.submit(req)
    _check(bool(result.get("success",false)),"composite movement and basic attack accepted")
    _check(actor.position!=from_position and actor.normal_moves_used>0 and actor.basic_attack_used,
        "one atomic action moves the actor and spends basic attack")
    _check(actor.qi_u==old_qi-int(check.get("plan",{}).get("qi_u",-1)),
        "movement and attack Qi are paid once")
    _check(m.state.mode=="CLASH" and int(m.state.attack.get("defender_id",-1))==target.id,
        "attack enters the original CTB clash/reaction pipeline")
    var move_seen := false
    var declared := false
    var order_correct := true
    for e in result.get("events",[]):
        var kind: String=str(e.get("type",""))
        if kind=="MOVE_FREE":
            if declared: order_correct=false
            move_seen=true
        if kind=="ATTACK_DECLARED":
            declared=true
            if not move_seen: order_correct=false
    _check(move_seen and declared and order_correct,
        "single event stream declares attack only after movement")
    var stale: Dictionary=m.submit(req)
    _check(not bool(stale.get("success",false)),
        "replayed composite action cannot perform movement or attack twice")

    var blocked = _new_model()
    var b_id: int=blocked.state.active_id
    var b_actor=blocked.state.get_actor(b_id)
    var b_target=blocked.state.get_actor(1 if b_id==0 else 0)
    b_actor.normal_moves_used=int(b_actor.stats.move_budget)
    var unchanged: Vector2=b_actor.position
    var qi_before: int=b_actor.qi_u
    var rev_before: int=blocked.state.revision
    var no_budget: Dictionary=blocked.submit(blocked.request("MOVE_AND_ATTACK",b_id,
        {"attack_kind":"BASIC_ATTACK","target_id":b_target.id}))
    _check(not bool(no_budget.get("success",false)) and b_actor.position==unchanged
        and b_actor.qi_u==qi_before and not b_actor.basic_attack_used
        and blocked.state.revision==rev_before,
        "insufficient movement budget rejects the whole action without costs")
    b_actor.normal_moves_used=0
    b_actor.qi_u=10000
    var poor: Dictionary=blocked.submit(blocked.request("MOVE_AND_ATTACK",b_id,
        {"attack_kind":"BASIC_ATTACK","target_id":b_target.id}))
    _check(not bool(poor.get("success",false)) and b_actor.position==unchanged
        and b_actor.qi_u==10000 and not b_actor.basic_attack_used,
        "combined Qi shortage cannot move or attack")
    var bake=blocked.state.spatial.bake
    _check(not blocked.state.spatial.attack_line_clear(
        bake.cell_center(Vector2i(4,3)),bake.cell_center(Vector2i(12,3))),
        "line of sight cannot pass through the authored river bank")
    var forbidden_position: Dictionary=blocked.submit(blocked.request("MOVE_AND_ATTACK",b_id,{
        "attack_kind":"BASIC_ATTACK","target_id":b_target.id,
        "target_position":b_actor.position}))
    _check(str(forbidden_position.get("error_code",""))=="MALFORMED_REQUEST",
        "client cannot inject a forged composite landing position")
    var ally: Dictionary=blocked.submit(blocked.request("MOVE_AND_ATTACK",b_id,
        {"attack_kind":"BASIC_ATTACK","target_id":b_id}))
    _check(str(ally.get("error_code",""))=="INVALID_TARGET","self-attack rejected")
    var nonexistent: Dictionary=blocked.submit(blocked.request("MOVE_AND_ATTACK",b_id,
        {"attack_kind":"BASIC_ATTACK","target_id":999}))
    _check(str(nonexistent.get("error_code",""))=="INVALID_TARGET","unknown target rejected")
    var forged: Dictionary=blocked.submit(blocked.request("MOVE_AND_ATTACK",b_id,
        {"attack_kind":"PLAY_CARD","target_id":b_target.id,
         "card_uid":"not-in-hand","usage_id":"probe"}))
    _check(str(forged.get("error_code",""))=="INVALID_CARD","unowned attack card rejected")
    var bad_type: Dictionary=blocked.submit(blocked.request("MOVE_AND_ATTACK",b_id,
        {"attack_kind":"BASIC_ATTACK","target_id":"actor"}))
    _check(str(bad_type.get("error_code",""))=="MALFORMED_REQUEST",
        "typed target request validation")

    var melee = _new_model()
    var near_id: int=melee.state.active_id
    var own=melee.state.get_actor(near_id)
    var enemy=melee.state.get_actor(1 if near_id==0 else 0)
    own.cell=Vector2i(7,4)
    own.position=melee.state.spatial.bake.cell_center(own.cell)
    var still: Vector2=own.position
    var near_req: Dictionary=melee.request("MOVE_AND_ATTACK",near_id,
        {"attack_kind":"BASIC_ATTACK","target_id":enemy.id})
    var near_check: Dictionary=melee.validate(near_req)
    _check(bool(near_check.get("success",false)) and int(near_check.get("plan",{}).get("move_units",-1))==0,
        "already-in-range target needs no movement")
    var near_result: Dictionary=melee.submit(near_req)
    _check(bool(near_result.get("success",false)) and own.position==still
        and own.normal_moves_used==0 and own.qi_u==20000,
        "in-range composite pays only normal attack Qi")

    var martial = _new_model()
    var caster=martial.state.get_actor(martial.state.active_id)
    var victim=martial.state.get_actor(1 if caster.id==0 else 0)
    var card: Dictionary=_attack_card(martial,caster)
    _check(not card.is_empty(),"at least one genuine attack card is available for regression")
    if not card.is_empty():
        caster.qi_u=60000
        var card_req: Dictionary=martial.request("MOVE_AND_ATTACK",caster.id,{
            "attack_kind":"PLAY_CARD","target_id":victim.id,
            "card_uid":card.card_uid,"usage_id":card.usage_id})
        var card_check: Dictionary=martial.validate(card_req)
        _check(bool(card_check.get("success",false)),"out-of-range martial card gains an approach route")
        if bool(card_check.get("success",false)):
            var before: int=caster.qi_u
            var card_result: Dictionary=martial.submit(card_req)
            _check(bool(card_result.get("success",false)) and martial.state.mode=="CLASH",
                "martial card declares attack using original chain system")
            _check(not caster.hand.has(card.card_uid) and caster.qi_u==before-int(card_check.plan.qi_u),
                "physical card leaves hand exactly once and total Qi is charged once")

    var unmapped=Model.new()
    var denied: Dictionary=unmapped.submit(unmapped.request("MOVE_AND_ATTACK",
        unmapped.state.active_id,{"attack_kind":"BASIC_ATTACK","target_id":1}))
    _check(str(denied.get("error_code",""))=="SPATIAL_UNAVAILABLE",
        "unmapped legacy encounters retain grid-only combat")
    print("APPROACH_ATTACK_PASS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures>0 else 0)

func _initialize() -> void:
    call_deferred("_run")
