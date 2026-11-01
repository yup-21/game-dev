extends SceneTree
const StoryFixture = preload("res://checks/story_test_helper.gd")
## Two real BattleModel encounters exchange only validated consumable snapshots.
## Equipment, UID, affixes and chapter rewards remain in CharacterRuntime.
const Session = preload("res://scripts/game_session.gd")
const Model = preload("res://scripts/battle_model.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("TWO_ENCOUNTERS: " + label)

func _battle_inventories(model) -> Dictionary:
    var result: Dictionary = {}
    for actor in model.state.actors:
        if actor.team_id == 0:
            result[int(actor.id)] = model.inventory_snapshot(int(actor.id))
    return result

func _start_model(session):
    var model = Model.new()
    model.reset(session.encounter_seed(),0,"tingfeng",session.encounter_options())
    check(model.state.outcome=="playing" and model.state.actors.size()==6,
        "chapter encounter enters the authoritative six-actor model")
    return model

func _use(model, id: String) -> void:
    # CTB owns the initiative: the preferred actor is only a tie-breaker.
    # Exercise real END_ACTION commands until the hero is allowed to act.
    for _step in range(24):
        if model.state.active_id == 0 and model.state.mode == "ACTION":
            break
        var current_id: int = int(model.state.active_id)
        if current_id < 0 or model.state.mode != "ACTION":
            break
        var advance: Dictionary = model.submit(model.request("END_ACTION",current_id))
        if not bool(advance.get("success",false)):
            break
        if model.state.animation_pending:
            model.acknowledge_animation(model.state.animation_ticket)
    check(model.state.active_id == 0 and model.state.mode == "ACTION",
        "CTB advances to the hero using authoritative commands")
    var actor = model.state.get_actor(0)
    if actor == null or model.state.active_id != 0:
        return
    if id == "healing_powder":
        actor.hp_u = actor.max_hp_u - 80000
    else:
        actor.qi_u = 0
    var sent: Dictionary = model.submit(model.request("USE_ITEM",0,{"item_id":id}))
    check(bool(sent.get("success",false)),
        "consume %s with versioned battle command: %s" % [id,str(sent.get("error_code",""))])
    if model.state.animation_pending:
        check(bool(model.acknowledge_animation(model.state.animation_ticket).get("success",false)),
            "presentation ticket acknowledged independently of inventory")

func _run() -> void:
    var session = Session.new()
    root.add_child(session)
    session.start_new_game()
    var hero = session.character("shen_changfeng")
    check(hero != null,"party character exists outside BattleModel")
    var uid: String = str(hero.inventory.equipped.get("weapon",""))
    check(not uid.is_empty() and hero.inventory.instances.get(uid,{}).get("affixes",[])==["keen_edge"],
        "opening equipment instance retains an affix")
    check(hero.inventory.stacks.get("healing_powder",0)==2
        and hero.inventory.stacks.get("breath_pill",0)==1,
        "starting party inventory is defined once")
    StoryFixture.finish_prologue(session)
    check(session.begin_encounter(),"first encounter gates on narrative clue")
    var first = _start_model(session)
    check(first.snapshot(0).get("inventory",{}).get("stacks",{}).get("healing_powder",0)==2,
        "battle owns a copy of the party inventory")
    _use(first,"healing_powder")
    check(hero.inventory.stacks.get("healing_powder",0)==2,
        "using a battle item does not prematurely mutate the party inventory")
    var snapshots: Dictionary = _battle_inventories(first)
    var forged: Dictionary = snapshots.duplicate(true)
    forged[0]["equipped"] = {}
    check(not session.report_battle("victory",0,forged)
        and session.phase=="battle" and hero.inventory.stacks.get("healing_powder",0)==2,
        "tampered equipment snapshot rolls back the entire battle result")
    check(session.report_battle("victory",0,snapshots),
        "authoritative first battle snapshot commits")
    hero = session.character("shen_changfeng")
    check(hero.inventory.stacks.get("healing_powder",0)==2,
        "spent one powder and gained one first-clear chapter reward")
    check(hero.inventory.equipped.get("weapon","")==uid
        and hero.inventory.instances[uid].affixes==["keen_edge"],
        "equipment UID and affixes survive the first battle")
    check(session.can_advance_chapter() and session.advance_chapter(),
        "party moves to chapter two without resetting runtime characters")
    check(session.apply_story_events([{"type":"set_flag","flag":"met_messenger","value":true},
        {"type":"grant_item","character_id":"shen_changfeng","item_id":"breath_pill","count":1}]),
        "second NPC's typed reward mutates the persistent inventory")
    check(session.begin_encounter(),"second encounter unlocked")
    var second = _start_model(session)
    check(second.snapshot(0).inventory.stacks.get("healing_powder",0)==2
        and second.snapshot(0).inventory.stacks.get("breath_pill",0)==2,
        "second real battle loads the post-reward party inventory")
    check(second.state.get_actor(0).equipment_affixes.has("weapon"),
        "equipment and affix modifier sources enter the new encounter")
    _use(second,"breath_pill")
    check(session.report_battle("victory",0,_battle_inventories(second)),
        "second battle inventory commits after consuming qi pill")
    hero = session.character("shen_changfeng")
    check(hero.inventory.stacks.get("healing_powder",0)==2
        and hero.inventory.stacks.get("breath_pill",0)==2,
        "two battles, NPC reward and second clear reward reconcile exactly")
    check(hero.inventory.equipped.get("weapon","")==uid
        and hero.inventory.instances[uid].affixes==["keen_edge"],
        "equipment UID remains stable for the complete two-battle demo")
    print("TWO_ENCOUNTERS_PASS failures=",failures)
    session.free()
    quit(0 if failures==0 else 1)
