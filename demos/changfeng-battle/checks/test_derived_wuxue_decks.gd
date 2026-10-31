extends SceneTree
## Gameplay contract: dynamic derivatives, distinct 3v3 martial lineages,
## and the established ten-school V3 catalog are all active in actual battles.
const Model = preload("res://scripts/battle_model.gd")
const SchoolCatalog = preload("res://scripts/school_catalog.gd")
const Scenario = preload("res://scripts/scenario_director.gd")
const UNIT := 10000
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, description: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("DERIVED_WUXUE: " + description)

func _ack(m) -> void:
    if m.state.animation_pending:
        m.acknowledge_animation(m.state.animation_ticket)

func _count(actor, m, definition_id: String) -> int:
    var count := 0
    for uid in actor.hand + actor.draw_pile + actor.discard_pile + actor.resolving:
        if str(m.cards.instance(str(uid)).get("definition_id","")) == definition_id:
            count += 1
    return count

func _first_action(m, actor_id: int, kind: String, usage_id: String = "") -> Dictionary:
    _ack(m)
    for action in m.legal_actions(actor_id):
        if str(action.get("kind", "")) != kind:
            continue
        if not usage_id.is_empty() and str(action.get("usage_id", "")) != usage_id:
            continue
        return action
    return {}

func _submit(m, action: Dictionary) -> Dictionary:
    return m.submit(m.request(str(action.kind), int(action.actor_id), action))

func _run() -> void:
    var cat = SchoolCatalog.new()
    _check(cat.load_error.is_empty() and cat.options().size() >= 11,
        "ten distinct martial schools plus Tingfeng must remain available")
    var source: Dictionary = JSON.parse_string(
        FileAccess.get_file_as_string("res://data/tingfeng_cards.json"))
    var starters := 0
    for entry in source.deck.cards:
        starters += int(entry.count)
        _check(str(entry.card_id) != "tf_change" and str(entry.card_id) != "tf_follow",
            "Tingfeng initial deck must exclude both change and follow derivatives")
    _check(starters == 12, "original starter deck remains twelve cards")
    for school in cat.schools:
        var n := 0
        for entry in cat.deck_for(str(school.id), []):
            n += int(entry.count)
            _check(str(entry.card_id) != "tf_change" and str(entry.card_id) != "tf_follow",
                "school " + str(school.id) + " illegally deals a derivative")
        _check(n == 12, "school " + str(school.id) + " has twelve starters")

    var model = Model.new()
    model.reset(901, 0)
    _check(model.state.outcome == "playing", "Tingfeng starter battle loads")
    var player = model.state.get_actor(0)
    var enemy = model.state.get_actor(1)
    _check(_count(player, model, "tf_change") == 0
        and _count(enemy, model, "tf_change") == 0
        and _count(player, model, "tf_follow") == 0,
        "neither change nor follow-up appears in starter draw")
    _check(player.technique_states.has("tf_change_stage")
        and str(player.technique_states.tf_change_stage.node) == "sealed",
        "change is learned as a stage but does not start ready")
    var first_uid: String = model.cards.create_instance(player, "tf_probe", "hand")
    player.cell = Vector2i(7,4)
    enemy.cell = Vector2i(8,4)
    player.qi_u = 6 * UNIT
    var legal: Array = model.legal_actions(player.id)
    var attack: Dictionary = {}
    for choice in legal:
        if (str(choice.get("kind", "")) == "PLAY_CARD"
                and str(choice.get("card_uid", "")) == first_uid
                and str(choice.get("usage_id", "")) == "probe"):
            attack = choice
            break
    _check(not attack.is_empty(), "probe starter has a legal attack")
    if attack.is_empty():
        quit(1)
        return
    var executed: Dictionary = _submit(model, attack)
    _check(bool(executed.get("success",false)) and model.state.mode == "CLASH",
        "attack declares root and opens response priority")
    var child := ""
    for uid in player.hand:
        if str(model.cards.instance(str(uid)).get("definition_id", "")) == "tf_follow":
            child = str(uid)
    _check(not child.is_empty(), "prerequisite generates follow-up token into hand immediately")
    if not child.is_empty():
        var state: Dictionary = model.cards.instance(child)
        _check(bool(state.get("generated", false)) and str(state.get("source_uid","")) == first_uid,
            "follow-up token retains provenance from prerequisite")
        _check(str(state.get("lifecycle", "")) == "exile_on_finish",
            "derivative is temporary and cannot recirculate")
        _check(model.cards.relations(first_uid).get("child_uids", []).has(child),
            "prerequisite references its derived child")
    _ack(model)
    # Defender passes, attacker now holds priority while generated card is
    # still in hand and has valid attack-response timing.
    var defender_pass: Dictionary = _first_action(model, enemy.id, "PASS_REACTION")
    _check(not defender_pass.is_empty(), "defender can give priority back")
    if not defender_pass.is_empty():
        _check(bool(_submit(model, defender_pass).get("success",false)),
            "first priority pass succeeds")
        _ack(model)
    var staged: Dictionary = player.technique_states.get("tf_change_stage",{})
    _check(str(staged.get("node","")) == "ready", "probe arms change stage without creating a change card")
    var has_derived_response := false
    var has_follow_response := false
    for option in model.legal_actions(player.id):
        if (str(option.get("kind", "")) == "USE_ABILITY"
                and str(option.get("technique_id", "")) == "tf_change_stage"):
            has_derived_response = true
        if str(option.get("kind", "")) == "PLAY_CARD" and str(option.get("card_uid","")) == child:
            has_follow_response = true
    _check(has_derived_response and not has_follow_response,
        "optional change stage is available; generated follow cannot answer a clash")
    var stance_action: Dictionary = {}
    for option in model.legal_actions(player.id):
        if (str(option.get("kind","")) == "USE_ABILITY"
                and str(option.get("technique_id","")) == "tf_change_stage"
                and str(option.get("node_id","")) == "change"):
            stance_action = option
            break
    _check(not stance_action.is_empty(), "ready stance has selectable 变锋·追击")
    if not stance_action.is_empty():
        _check(bool(_submit(model, stance_action).get("success",false)),
            "optional stance submits as USE_ABILITY, never a generated card")
        _check(str(player.technique_states.tf_change_stage.node) == "sealed",
            "using one stance choice resets the stage, without consuming follow-up")
        _check(_count(player, model, "tf_change") == 0,
            "choosing a stance never constructs a 变锋 card UID")
        _ack(model)
        var defender_second: Dictionary = _first_action(model, enemy.id, "PASS_REACTION")
        _check(bool(_submit(model, defender_second).get("success",false)),
            "defender can pass after a real stance reaction")
        _ack(model)
    var attacker_pass: Dictionary = _first_action(model, player.id, "PASS_REACTION")
    if not attacker_pass.is_empty():
        _check(bool(_submit(model, attacker_pass).get("success",false)),
            "final pass resolves the original attack and reaction chain")
        _ack(model)
    _check(model.state.mode == "ACTION" and _count(player, model, "tf_follow") == 1,
        "follow-up remains in hand after resolving prerequisite attack")
    var follow_action: Dictionary = {}
    for option in model.legal_actions(player.id):
        if (str(option.get("kind","")) == "PLAY_CARD"
                and str(option.get("card_uid","")) == child
                and str(option.get("usage_id","")) == "follow"):
            follow_action = option
            break
    _check(not follow_action.is_empty(),
        "created 追风 is usable only as its own ACTION attack")
    if not follow_action.is_empty():
        _check(bool(_submit(model, follow_action).get("success",false)),
            "follow-up executes as a real generated card")
        _ack(model)
        var pass1: Dictionary = _first_action(model, enemy.id, "PASS_REACTION")
        _check(bool(_submit(model, pass1).get("success",false)),
            "defender passes the follow-up clash")
        _ack(model)
        var pass2: Dictionary = _first_action(model, player.id, "PASS_REACTION")
        _check(bool(_submit(model, pass2).get("success",false)),
            "attacker finishes the follow-up clash")
        _ack(model)
    var combo_found := false
    for event in model.state.logs:
        if str(event.get("type","")) == "COMBO_TRIGGERED":
            combo_found = true
    _check(combo_found,
        "probe then generated follow-up still triggers 探锋追风 combo")
    if not child.is_empty():
        _check(player.exile_pile.has(child)
            and not player.discard_pile.has(child)
            and not player.draw_pile.has(child),
            "played follow-up is exiled and never reshuffles")

    var configured = Scenario.new()
    var encounter: Dictionary = configured.encounter("escort_ambush")
    var opts: Dictionary = configured.battle_options("escort_ambush")
    var names: Dictionary = {}
    for actor in encounter.combatants:
        names[int(actor.id)] = str(actor.name)
    _check(opts.get("combatants", []).size() == 6,
        "prologue keeps six actors")
    var expected: Dictionary = {
        0:"wind_sword", 2:"tide", 3:"step",
        1:"saber", 4:"ember", 5:"needle"}
    _check(opts.get("schools",{}).size() == 6,
        "every story actor must be bound to a named martial school")
    for id in expected:
        _check(str(opts.get("schools",{}).get(id, "")) == expected[id],
            "unexpected martial lineage for " + str(names.get(id,id)))
    var distinct: Dictionary = {}
    for school_id in opts.get("schools",{}).values():
        distinct[str(school_id)] = true
    _check(distinct.size() == 6,
        "six actors have independent martial-school identities")
    var story = Model.new()
    story.reset(configured.encounter("escort_ambush").seed, -1, "tingfeng", opts)
    _check(story.state.outcome == "playing" and story.state.actors.size() == 6,
        "multiplayer encounter with six schools initializes")
    for id in expected:
        var actor = story.state.get_actor(id)
        _check(actor != null and actor.school_id == expected[id],
            "actor school binding survives BattleModel reset: " + str(id))
        if actor == null:
            continue
        _check(actor.hand.size() == 5 and actor.draw_pile.size() == 7,
            "independent twelve-card school deck for actor " + str(id))
        _check(_count(actor, story, "tf_change") == 0 and _count(actor, story, "tf_follow") == 0,
            "actor must not start with derived cards or stages: " + str(id))
        var core: Array = cat.get_school(expected[id]).core_forms
        _check(story.cards.definitions.has(str(core[0]))
            and story.cards.definitions.has(str(core[1])),
            "chosen school core forms are registered: " + str(id))
    print("DERIVED_WUXUE_PASS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures > 0 else 0)
