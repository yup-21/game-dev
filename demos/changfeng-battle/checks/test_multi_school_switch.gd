extends SceneTree
## Real BattleModel authority for multi-school learning and 1-action switching.
const Registry = preload("res://scripts/character_registry.gd")
const Model = preload("res://scripts/battle_model.gd")
const Scenario = preload("res://scripts/scenario_director.gd")
var checks: int = 0
var errors: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        errors += 1
        push_error("MULTI_SCHOOL: " + message)

func _has(legal: Array, kind: String, school_id: String) -> bool:
    for option in legal:
        if str(option.get("kind",""))==kind and str(option.get("school_id",""))==school_id:
            return true
    return false

func _all_zone_ids(actor) -> Array:
    return actor.hand + actor.draw_pile + actor.discard_pile + actor.resolving + actor.exile_pile

func _run() -> void:
    var registry = Registry.new()
    _check(registry.load_error.is_empty(), "registry and learned school catalog load")
    var protagonist: Dictionary = registry.for_actor(0)
    _check(protagonist.learned_schools.size() == 3
        and protagonist.learned_schools.has("wind_sword")
        and protagonist.learned_schools.has("tingfeng"),
        "profile owns more than one school, default is separate")
    var mutated: Dictionary = protagonist.duplicate(true)
    mutated.learned_schools.append("needle")
    _check(not registry.for_actor(0).learned_schools.has("needle"),
        "static learned roster is immutable to caller")
    var cfg: Dictionary = registry.battle_options([],
        {0:"shen_changfeng",1:"pursuer_captain"})
    _check(cfg.learned_schools[0].size() == 3 and cfg.schools[0] == "wind_sword",
        "battle options carry learned set and equipped school independently")
    var m = Model.new()
    m.reset(2026,-1,"tingfeng",cfg)
    _check(m.state.outcome == "playing" and m.state.mode == "ACTION",
        "real 1v1 school switching fixture starts")
    var a = m.state.get_actor(0)
    var enemy = m.state.get_actor(1)
    _check(a.learned_schools.size() == 3 and a.school_id == "wind_sword",
        "actor has learned choices but starts with own equipped school")
    _check(m.cards.definitions.has("tf_probe") and m.cards.definitions.has("wind_slash"),
        "learned schools are registered before a switch")
    var legal: Array = m.legal_actions(0)
    _check(_has(legal,"SWITCH_SCHOOL","tingfeng") and _has(legal,"SWITCH_SCHOOL","step"),
        "legal actions expose two switches for the active character")
    _check(not _has(legal,"SWITCH_SCHOOL","needle")
        and not _has(legal,"SWITCH_SCHOOL","wind_sword"),
        "unlearned and already-equipped schools are not actions")
    _check(not _has(m.legal_actions(1),"SWITCH_SCHOOL","ember"),
        "inactive enemy cannot switch")
    var revision: int = m.state.revision
    var bad: Dictionary = m.submit(m.request("SWITCH_SCHOOL",0,{"school_id":"needle"}))
    _check(not bad.success and bad.error_code=="ILLEGAL_ACTION" and m.state.revision == revision,
        "unlearned school is rejected without state mutation")
    bad=m.submit(m.request("SWITCH_SCHOOL",0,{"school_id":2}))
    _check(not bad.success and bad.error_code=="MALFORMED_REQUEST",
        "school ID request type validated")
    a.qi_u = 20000
    var previous_hp: int = a.hp_u
    var previous_qi: int = a.qi_u
    var before_tick: int = m.state.global_tick
    var old_cards: Array = _all_zone_ids(a).duplicate()
    var attack_uid: String = str(a.hand[0])
    var generated: String = m.cards.create_instance(a,"tf_follow","hand",attack_uid)
    old_cards.append(generated)
    _check(not generated.is_empty() and a.hand.has(generated),
        "pre-switch generated child exists in hand")
    var req: Dictionary = m.request("SWITCH_SCHOOL",0,{"school_id":"tingfeng"})
    var res: Dictionary = m.submit(req)
    _check(bool(res.get("success",false)),"switch submitted via BattleModel")
    var switched_event := false
    for event in res.get("events",[]):
        if str(event.get("type",""))=="SCHOOL_SWITCHED":
            switched_event = true
    _check(switched_event,"switch emits authoritative semantic event")
    _check(a.school_id=="tingfeng" and a.learned_schools.size()==3,
        "equipped school changes but learned roster is untouched")
    _check(a.hp_u==previous_hp and a.qi_u==previous_qi
        and m.state.global_tick>=before_tick,
        "switch does not grant HP/Qi or reset global time")
    _check(a.hand.size()==5 and a.draw_pile.size()==7,
        "replacement school produces 12 starter cards and five drawn")
    var fresh: Array = _all_zone_ids(a)
    var all_new := true
    for uid in fresh:
        if old_cards.has(uid):
            all_new=false
        if str(m.cards.canonical_definition(str(uid)).get("id","")).begins_with("wind_"):
            all_new=false
    _check(all_new,"old cards, source instances and generated child cannot leak into new deck")
    var removed := true
    for uid in old_cards:
        if m.cards.instances.has(uid):
            removed=false
    _check(removed,"old instances are removed rather than hidden or re-dealt")
    _check(a.attack_history.is_empty() and a.combo_used.is_empty()
        and a.card_uses.is_empty(), "old style combo, card usage and response history cleared")
    _check(m.state.active_id != 0 and m.state.action_no >= 2,
        "switch consumes current CTB action instead of granting extra play")
    _check(not m.submit(req).success,"duplicate/stale switch request cannot execute twice")
    _check(m.state.animation_pending,"switch animation ticket is propagated")
    m.acknowledge_animation(m.state.animation_ticket)
    _check(not _has(m.legal_actions(0),"SWITCH_SCHOOL","step"),
        "switching outside own ACTION is prohibited")
    # Profiled 3v3: all allies/enemies still use their independent schools,
    # and every actor has at least one additional learned discipline.
    var director = Scenario.new()
    var party = Model.new()
    party.reset(2026,-1,"tingfeng",director.battle_options("escort_ambush"))
    _check(party.state.outcome=="playing" and party.state.actors.size()==6,
        "3v3 scene consumes learned multi-school character profiles")
    for actor in party.state.actors:
        _check(actor.learned_schools.size()>=2
            and actor.learned_schools.has(actor.school_id),
            "party character knows active school plus backup: " + str(actor.id))
    # UI request goes through the battle bridge and MUST close the overlay.
    var scene = load("res://battle_hd2d.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var ui: Control = scene.get("character_card") as Control
    _check(ui!=null,"role card exists in official HD-2D scene")
    if ui!=null:
        _check(bool(ui.call("open_actor",scene.get("model"),0)),
            "role card opens the player's learned schools")
        var list: VBoxContainer = ui.get("schools_column") as VBoxContainer
        _check(list!=null and list.get_child_count() == 3,
            "character card lists all three learned schools")
        var option: Button = list.get_node_or_null("School_tingfeng") as Button
        _check(option!=null and not option.disabled,
            "learned un-equipped school offers an enabled switch button")
        var old_revision: int = scene.get("model").state.revision
        if option!=null and not option.disabled:
            option.pressed.emit()
            _check(scene.get("model").state.get_actor(0).school_id=="tingfeng"
                and scene.get("model").state.revision==old_revision+1,
                "real UI button issues a versioned school switch")
            _check(not ui.visible,"role card closes on switch")
    print("MULTI_SCHOOL_PASS checks=%d failures=%d" % [checks,errors])
    scene.queue_free()
    await process_frame
    quit(1 if errors>0 else 0)
