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
    _check(cat.load_error.is_empty() and cat.options().size() == 11,
        "ten distinct martial schools plus Tingfeng must remain available")
    var source: Dictionary = JSON.parse_string(
        FileAccess.get_file_as_string("res://data/tingfeng_cards.json"))
    var starters := 0
    for entry in source.deck.cards:
        starters += int(entry.count)
        _check(str(entry.card_id) != "tf_change",
            "Tingfeng initial deck must exclude derivative change form")
    _check(starters == 12, "original starter deck remains twelve cards")
    for school in cat.schools:
        var n := 0
        for entry in cat.deck_for(str(school.id), []):
            n += int(entry.count)
            _check(str(entry.card_id) != "tf_change",
                "school " + str(school.id) + " illegally deals derivative")
        _check(n == 12, "school " + str(school.id) + " has twelve starters")

    var model = Model.new()
    model.reset(901, 0)
    _check(model.state.outcome == "playing", "Tingfeng starter battle loads")
    var player = model.state.get_actor(0)
    var enemy = model.state.get_actor(1)
    _check(_count(player, model, "tf_change") == 0
        and _count(enemy, model, "tf_change") == 0,
        "neither combatant can draw a change card before prerequisite")
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
        if str(model.cards.instance(str(uid)).get("definition_id", "")) == "tf_change":
            child = str(uid)
    _check(not child.is_empty(), "prerequisite creates change into hand immediately")
    if not child.is_empty():
        var state: Dictionary = model.cards.instance(child)
        _check(bool(state.get("generated", false)) and str(state.get("source_uid","")) == first_uid,
            "derivative retains provenance from prerequisite")
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
    var has_derived_response := false
    for option in model.legal_actions(player.id):
        if str(option.get("kind", "")) == "PLAY_CARD" and str(option.get("card_uid","")) == child:
            has_derived_response = true
            break
    _check(has_derived_response,
        "created change can be used as an actual same-clash response")
    var attacker_pass: Dictionary = _first_action(model, player.id, "PASS_REACTION")
    if not attacker_pass.is_empty():
        _check(bool(_submit(model, attacker_pass).get("success",false)),
            "second pass resolves the ordinary attack")
        _ack(model)
    _check(model.state.mode == "ACTION" and _count(player, model, "tf_change") == 1,
        "unused derivative remains only in its creator's hand until refresh")
    if not child.is_empty():
        model.cards.leave_hand(player, child, false)
        _check(player.exile_pile.has(child) and not player.discard_pile.has(child),
            "derivative is exiled, never shuffled back into draw pile")

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
        _check(_count(actor, story, "tf_change") == 0,
            "actor must not start with derived cards: " + str(id))
        var core: Array = cat.get_school(expected[id]).core_forms
        _check(story.cards.definitions.has(str(core[0]))
            and story.cards.definitions.has(str(core[1])),
            "chosen school core forms are registered: " + str(id))
    print("DERIVED_WUXUE_PASS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures > 0 else 0)
