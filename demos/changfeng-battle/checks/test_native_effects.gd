extends SceneTree
## R20: authored .tres cards, derived card, staged ability and registered handler.
const Native = preload("res://scripts/content/content_registry.gd")
const Effects = preload("res://scripts/effects/effect_registry.gd")
const Registry = preload("res://scripts/character_registry.gd")
const Model = preload("res://scripts/battle_model.gd")
const Techniques = preload("res://scripts/technique_runtime.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("R20 EFFECTS FAIL: " + label)

func _run() -> void:
    var native = Native.new()
    check(native.load_error.is_empty() and native.entries("skill").size() == 2,
        "native skill definitions load from .tres")
    check(native.entries("technique").has("r20_guard_stage"),
        "independent staged ability loads as Resource")
    var effects = Effects.new()
    check(effects.load_error.is_empty() and effects.supports("r20_qi_by_status"),
        "custom effect handler registered without resolver match branch")
    check(not effects.valid_custom({"type":"r20_qi_by_status","amount":1}),
        "custom effect rejects missing status")
    var abilities = Techniques.new()
    check(abilities.load_error.is_empty() and abilities.definitions.has("r20_guard_stage"),
        "technique runtime sees native stage")

    var roster: Array = [
        {"id":0,"name":"沈长风","team_id":0,"controller":"PLAYER","cell":[6,4]},
        {"id":1,"name":"追兵","team_id":1,"controller":"AI","cell":[8,4]}
    ]
    var options: Dictionary = Registry.new().battle_options(roster,
        {0:"shen_changfeng",1:"pursuer_captain"})
    check(not options.is_empty(), "character profiles build a 1v1 scenario")
    if options.is_empty():
        quit(1)
        return
    options.techniques[0]["r20_guard_stage"] = 1
    var battle = Model.new()
    battle.reset(2026, 0, "tingfeng", options)
    check(battle.state.outcome == "playing" and battle.cards.load_error.is_empty(),
        "native skills and stage pass actual BattleModel registration")
    if battle.state.outcome != "playing":
        quit(1)
        return
    check(battle.cards.definitions.has("r20_probe") and battle.cards.definitions.has("r20_follow"),
        "new cards enter canonical CardSystem definitions")
    check(battle.cards.valid_effect({
        "type":"r20_qi_by_status","status_id":"iron_body","amount":1.0
    }), "custom primitive recognized by canonical validator")
    check(not battle.cards.valid_effect({
        "type":"r20_qi_by_status","status_id":"invalid","amount":1.0
    }), "unknown status references rejected before execution")

    # Only the test supplies a source card; runtime derives the follow card.
    var hero = battle.state.get_actor(0)
    var uid: String = battle.cards.create_instance(hero,"r20_probe","hand")
    check(not uid.is_empty(), "native source card can be instantiated")
    # CTB initiative remains authoritative even for imported content.
    for _turn in range(24):
        if battle.state.active_id == 0 and battle.state.mode == "ACTION":
            break
        var active: int = int(battle.state.active_id)
        if active < 0 or battle.state.mode != "ACTION":
            break
        var advanced: Dictionary = battle.submit(battle.request("END_ACTION",active))
        if not bool(advanced.get("success",false)):
            break
        if battle.state.animation_pending:
            battle.acknowledge_animation(battle.state.animation_ticket)
    check(battle.state.active_id == 0 and battle.state.mode == "ACTION",
        "native skill uses an actual CTB action window")
    var qi_before: int = hero.qi_u
    var request: Dictionary = battle.request("PLAY_CARD",0,{
        "card_uid":uid,"usage_id":"probe"
    })
    var result: Dictionary = battle.submit(request)
    check(bool(result.get("success",false)), "native probe is accepted by battle commands")
    check(hero.statuses.has("iron_body"), "native apply_status component executed")
    check(hero.qi_u > qi_before, "new scripted effect gained Qi per active status stack")
    var generated: Array = []
    for card_uid in hero.hand:
        if battle.cards.instance(str(card_uid)).get("definition_id","") == "r20_follow":
            generated.append(card_uid)
    check(generated.size() == 1, "native grant_card generates the follow-up once")
    if not generated.is_empty():
        check(battle.cards.instance(str(generated[0])).get("generated",false),
            "derived card is a physical child with a stable UID")
    if battle.state.animation_pending:
        battle.acknowledge_animation(battle.state.animation_ticket)
    var shield_before: int = hero.shield_u
    var stage_result: Dictionary = battle.submit(battle.request("USE_ABILITY",0,{
        "technique_id":"r20_guard_stage","node_id":"guard"
    }))
    check(bool(stage_result.get("success",false)),
        "native stage ability executes separately from deck")
    check(hero.shield_u > shield_before, "extracted shield handler applies effect")

    print("R20_NATIVE_EFFECTS_PASS failures=",failures)
    quit(0 if failures == 0 else 1)
