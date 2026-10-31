extends SceneTree
## P1 closeout: six actors, authored cancel priority, posture-conditional combo,
## FREE AI, and HUD display must agree without consulting wall-clock animation.
const Model = preload("res://scripts/battle_model.gd")
const AI = preload("res://scripts/enemy_ai.gd")
const MapBake = preload("res://scripts/map_bake.gd")
const VFX = preload("res://scripts/battle_vfx_2d.gd")
const UNIT: int = 10000
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("P1_CLOSEOUT: " + label)

func _roster() -> Array:
    return [
        {"id":0,"name":"队长","team_id":0,"controller":"PLAYER","cell":[6,4]},
        {"id":2,"name":"队友甲","team_id":0,"controller":"AI","cell":[5,3]},
        {"id":3,"name":"队友乙","team_id":0,"controller":"AI","cell":[5,5]},
        {"id":1,"name":"追兵","team_id":1,"controller":"AI","cell":[7,4]},
        {"id":4,"name":"敌人甲","team_id":1,"controller":"AI","cell":[8,3]},
        {"id":5,"name":"敌人乙","team_id":1,"controller":"AI","cell":[8,5]}
    ]

func _free_roster() -> Array:
    # Real painted bridge permits row 4, columns 2–4 and 8–10.
    return [
        {"id":0,"name":"队长","team_id":0,"controller":"AI","cell":[2,4]},
        {"id":2,"name":"队友甲","team_id":0,"controller":"AI","cell":[3,4]},
        {"id":3,"name":"队友乙","team_id":0,"controller":"AI","cell":[4,4]},
        {"id":1,"name":"追兵","team_id":1,"controller":"AI","cell":[8,4]},
        {"id":4,"name":"敌人甲","team_id":1,"controller":"AI","cell":[9,4]},
        {"id":5,"name":"敌人乙","team_id":1,"controller":"AI","cell":[10,4]}
    ]

func _model():
    var model = Model.new()
    model.reset(2026,0,"tingfeng",{"combatants":_roster()})
    return model

func _send(model, kind: String, who: int, params: Dictionary = {}) -> Dictionary:
    var result: Dictionary = model.submit(model.request(kind,who,params))
    if bool(result.get("success",false)) and model.state.animation_pending:
        model.acknowledge_animation(model.state.animation_ticket)
    return result

func _pass(model) -> void:
    var count: int = 0
    while model.state.mode == "CLASH" and count < 6:
        var actor_id: int = int(model.state.clash.priority_actor_id)
        var result: Dictionary = _send(model,"PASS_REACTION",actor_id)
        _check(bool(result.get("success",false)), "valid response pass")
        if not bool(result.get("success",false)):
            break
        count += 1
    _check(model.state.mode != "CLASH", "LIFO finishes within six steps")

func _card(model, actor_id: int, card_id: String) -> String:
    return model.cards.create_instance(model.state.get_actor(actor_id),card_id,"hand")

func _events(model, kind: String, id: String = "") -> int:
    var count: int = 0
    for e in model.state.events:
        if str(e.get("type","")) == kind and (
            id.is_empty() or str(e.get("combo_id",""))==id):
            count += 1
    return count

func _heavy(model) -> void:
    model.state.get_actor(0).qi_u=6*UNIT
    var uid: String=_card(model,0,"tf_sunder")
    var result: Dictionary=_send(model,"PLAY_CARD",0,
        {"card_uid":uid,"usage_id":"heavy","target_id":1})
    _check(bool(result.get("success",false)), "heavy root is valid")
    if bool(result.get("success",false)):
        _pass(model)

func _run() -> void:
    var combo = _model()
    _check(combo.state.actors.size()==6 and combo.state.active_id==0,
        "six-actor scripted bridge scenario is active")
    var defender = combo.state.get_actor(1)
    var has_pressure_combo: bool=false
    for entry in combo.cards.combos:
        if str(entry.get("id",""))=="heavy_pressure":
            has_pressure_combo=true
    _check(combo.cards.combos.size()==3 and has_pressure_combo,
        "authored pressure combo loads without adding a start-deck card")
    var invalid: Dictionary={
        "id":"bad","name":"bad","mode":"on_qualified_hit",
        "attack_card_id":"tf_sunder","attack_usage_id":"heavy",
        "target_posture_at_least":0,"effects":[{"type":"modify_pending_damage","flat_delta":1}]
    }
    _check(not combo.cards.valid_combo(invalid)
        and not combo.cards.valid_combo(invalid.merged({"target_posture_at_least":8.5},true)),
        "invalid posture thresholds are rejected at catalog load")
    _heavy(combo)
    _heavy(combo)
    _check(defender.posture==8 and defender.hp_u==10*UNIT,
        "first two heavy strikes accumulate pressure without bonus")
    var before: int=defender.hp_u
    _heavy(combo)
    _check(defender.hp_u==before-6*UNIT and defender.posture==0,
        "third heavy gets one pressure-conditioned combo damage and breaks stance")
    _check(combo.statuses.has(1,"opening")
        and _events(combo,"COMBO_TRIGGERED","heavy_pressure")==1
        and _events(combo,"POSTURE_BROKEN")==1,
        "pressure combo and break-to-opening happen exactly once")
    combo.state.get_actor(0).qi_u=6*UNIT
    var expose_uid: String=_card(combo,0,"tf_sunder")
    var expose: Dictionary=_send(combo,"PLAY_CARD",0,
        {"card_uid":expose_uid,"usage_id":"expose","target_id":1})
    _check(bool(expose.get("success",false)), "expose follows posture break")
    if bool(expose.get("success",false)):
        _pass(combo)
    _check(_events(combo,"COMBO_TRIGGERED","opening_to_expose")==1
        and not combo.statuses.has(1,"opening"),
        "posture break enables existing conditional combo and consumes opening")

    var cancel = _model()
    var source = cancel.state.get_actor(0)
    var target = cancel.state.get_actor(1)
    source.qi_u=6*UNIT
    target.qi_u=6*UNIT
    var root_uid: String=_card(cancel,0,"tf_probe")
    var guard_uid: String=_card(cancel,1,"tf_guard")
    _check(bool(_send(cancel,"PLAY_CARD",0,
        {"card_uid":root_uid,"usage_id":"probe","target_id":1}).get("success",false)),
        "probe declares and arms change-stage response")
    _check(cancel.state.mode=="CLASH" and
        bool(_send(cancel,"PLAY_CARD",1,
        {"card_uid":guard_uid,"usage_id":"yield"}).get("success",false)),
        "defender declares L1 damage reduction")
    var link_id: int=int(cancel.state.clash.stack[0].id)
    var bad_revision: int=cancel.state.revision
    var qi_before: int=source.qi_u
    var spoof: Dictionary=_send(cancel,"USE_ABILITY",0,
        {"technique_id":"tf_change_stage","node_id":"attack_counter","link_id":99})
    _check(not bool(spoof.get("success",false)) and
        cancel.state.revision==bad_revision and source.qi_u==qi_before,
        "invalid cancel target has no revision or resource side effects")
    _check(cancel.reactions.can_cancel_link(0,link_id)
        and not cancel.reactions.can_cancel_link(1,link_id)
        and not cancel.reactions.can_cancel_link(0,-1),
        "only opposing unresolved responses are cancellable; root excluded")
    _check(not cancel.reactions.cancel_link(0,link_id)
        and not bool(cancel.state.clash.stack[0].canceled),
        "direct mutation outside LIFO resolver is forbidden")
    var counter: Dictionary=_send(cancel,"USE_ABILITY",0,
        {"technique_id":"tf_change_stage","node_id":"attack_counter","link_id":link_id})
    _check(bool(counter.get("success",false)) and source.qi_u==qi_before-UNIT,
        "validated cancel link costs exactly one qi")
    if bool(counter.get("success",false)):
        _pass(cancel)
    _check(_events(cancel,"CHAIN_LINK_CANCELED")==1
        and _events(cancel,"CHAIN_LINK_SKIPPED")==1
        and target.hp_u==18*UNIT,
        "LIFO cancel skips only L1 while root attack still hits")
    _check(cancel.state.global_tick==0 and
        cancel.state.get_actor(0).posture==0,
        "priority responses do not advance CTB or apply unrelated posture")

    var free = Model.new()
    free.reset(2026,0,"tingfeng",{
        "map_definition_path":MapBake.DEFAULT_PATH,
        "spatial_mode":"FREE","combatants":_free_roster()})
    _check(free.state.outcome=="playing" and free.state.actors.size()==6,
        "same 3v3 roster loads in continuous space")
    var ai=AI.new()
    var steps: int=0
    for i in range(24):
        if free.state.outcome!="playing":
            break
        var who: int=free.rules.responder_id() if free.state.mode=="CLASH" else free.state.active_id
        var context: Dictionary=free.decision_context(who)
        var action: Dictionary=ai.choose_action(context)
        if action.is_empty():
            break
        var result: Dictionary=free.submit(action)
        if not bool(result.get("success",false)):
            break
        free.acknowledge_animation(int(result.ticket))
        steps+=1
        for actor in free.state.actors:
            _check(actor.posture>=0 and actor.posture<=int(actor.stats.max_posture),
                "3v3 posture is bounded on decision %d" % i)
    _check(steps>=16, "six-unit FREE battle makes progress without input deadlock")

    # Inspect the actual player HUD, not only a direct test of the pure data.
    var scene: Node2D=load("res://battle_hd2d.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var live=scene.get("model")
    var hud=scene.get("hud_view")
    var bars: Dictionary=hud.controls.get("roster_bars",{})
    _check(bars.has(0) and bars[0].has("posture"),
        "canonical battle builds a dedicated posture meter")
    live.state.get_actor(0).posture=7
    var snap: Dictionary=live.snapshot(0)
    var own: Dictionary={}
    for a in snap.get("actors",[]):
        if int(a.id)==0:
            own=a
    hud.show_status(snap,0,own,false,false,str(live.state.spatial_mode),
        live.state.spatial!=null,true,-1)
    _check(bars.has(0) and int(bars[0].posture.value)==7
        and int(bars[0].posture.max_value)==10,
        "HUD reads posture snapshot without writing battle authority")
    # Presentation consumes semantic events, never updates CombatantState.
    var vfx_host: Node2D=Node2D.new()
    root.add_child(vfx_host)
    var standin: Node2D=Node2D.new()
    standin.position=Vector2(50,75)
    vfx_host.add_child(standin)
    var effects=VFX.new(vfx_host)
    var posture_before: int=live.state.get_actor(0).posture
    effects.handle_events([
        {"type":"POSTURE_BROKEN","actor_id":0},
        {"type":"CHAIN_LINK_CANCELED","actor_id":0}
    ],{0:standin})
    _check(effects.bursts.size()==2 and
        str(effects.bursts[0].node.name)=="WuxiaVFX2D_shatter" and
        str(effects.bursts[1].node.name)=="WuxiaVFX2D_guard",
        "posture break and reaction cancel each emit an independent VFX cue")
    effects.update(0.8)
    _check(effects.bursts.is_empty() and
        live.state.get_actor(0).posture==posture_before,
        "transient VFX expires without mutating battle state")

    print("P1_CLOSEOUT_PASS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
