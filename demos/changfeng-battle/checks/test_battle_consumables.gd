extends SceneTree
## R16: item use is one validated/revisioned atomic combat action.
const Runtime = preload("res://scripts/character_runtime.gd")
const Registry = preload("res://scripts/character_registry.gd")
const Model = preload("res://scripts/battle_model.gd")
const Dispatcher = preload("res://scripts/battle_command_dispatcher.gd")
var failures: int = 0

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("BATTLE ITEM FAIL: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var role = Runtime.new("shen_changfeng")
    check(role.inventory.add("healing_powder",2),"give two healing powders")
    check(role.inventory.add("breath_pill"),"give data-authored qi pill")
    var roster: Array = [
        {"id":71,"name":"hero","team_id":0,"controller":"PLAYER","cell":[6,4]},
        {"id":72,"name":"foe","team_id":1,"controller":"AI","cell":[8,4]}
    ]
    var options: Dictionary = Registry.new().battle_options(roster,
        {71:"shen_changfeng",72:"pursuer_captain"},
        {"shen_changfeng":role.battle_build()})
    check(not options.is_empty() and options.inventories.has(71),"inventory passed to battle by value")
    var model = Model.new()
    model.reset(2026,71,"tingfeng",options)
    var actor = model.state.get_actor(71)
    check(model.state.outcome == "playing" and model.state.active_id == 71,
        "battle begins on the chosen player's action")
    if actor == null:
        quit(1)
        return
    actor.hp_u = actor.max_hp_u-80000
    var original_revision: int = model.state.revision
    var invalid: Dictionary = model.submit(model.request("USE_ITEM",71,{"item_id":"unknown_item"}))
    check(not invalid.success and model.state.revision == original_revision
        and actor.hp_u == actor.max_hp_u-80000,"forged item ID rejected without spending or revision")
    var legal_ids: Array = []
    for action in model.legal_actions(71):
        if str(action.kind) == "USE_ITEM": legal_ids.append(str(action.item_id))
    check(legal_ids.has("healing_powder") and legal_ids.has("breath_pill"),
        "only stocked consumables are enumerated")
    check(model.snapshot(71).consumables.size() == 2
        and model.snapshot(72).consumables.is_empty(),"inventory is observer-private")
    var request: Dictionary = model.request("USE_ITEM",71,{"item_id":"healing_powder"})
    var outcome: Dictionary = model.submit(request)
    check(outcome.success and model.state.revision == original_revision+1,
        "healing powder commits through versioned submit")
    check(actor.hp_u == actor.max_hp_u-30000 and actor.item_used,
        "healing applies once and per-action item limit is set")
    check(model.inventory_snapshot(71).stacks.healing_powder == 1
        and role.inventory.stacks.healing_powder == 2,
        "battle stock deducted once; overworld inventory remains separate")
    var events: Array = outcome.get("events",[])
    var use_count: int = 0
    for event in events:
        if str(event.get("kind","")) == "ITEM_USED": use_count += 1
    check(use_count == 1,"semantic item event published exactly once")
    check(not model.submit(request).success
        and model.inventory_snapshot(71).stacks.healing_powder == 1,"replay cannot consume twice")
    check(model.acknowledge_animation(model.state.animation_ticket).success,
        "item ticket is acknowledged through normal presentation protocol")
    var has_item: bool = false
    for action in model.legal_actions(71):
        if str(action.kind) == "USE_ITEM": has_item = true
    check(not has_item,"second item cannot be used in the same CTB action")
    var second = Model.new()
    second.reset(2026,71,"tingfeng",options)
    var a2 = second.state.get_actor(71)
    if a2 != null:
        a2.qi_u = 0
        var dispatched: Dictionary = Dispatcher.dispatch(second,71,"USE_ITEM",{"item_id":"breath_pill"})
        check(bool(dispatched.get("dispatched",false)) and bool(dispatched.result.get("success",false)),
            "HUD adapter dispatches an enumerated item command")
        check(a2.qi_u == 20000 and not second.inventory_snapshot(71).stacks.has("breath_pill"),
            "qi effect and last-stack consumption are atomic")
    print("BATTLE_CONSUMABLE_PASS failures=",failures)
    quit(0 if failures == 0 else 1)
