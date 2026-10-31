extends SceneTree
## Cross-module contract: authored buffs, martial effects and equipment compose.
const SchoolCatalog = preload("res://scripts/school_catalog.gd")
const ItemCatalog = preload("res://scripts/item_catalog.gd")
const Runtime = preload("res://scripts/character_runtime.gd")
const Registry = preload("res://scripts/character_registry.gd")
const Model = preload("res://scripts/battle_model.gd")
var failures: int = 0

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("R15 CONTENT FAIL: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    # New martial effects may reference an independent BuffCatalog entry.
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/school_forms.json"))
    var expanded: Dictionary = raw.duplicate(true)
    expanded.cards[0].usages[0].effects.append({
        "type":"apply_status","status_id":"iron_body","stacks":1,"target":"self"
    })
    var fixture: String = "user://r15-martial-buff-link.json"
    var file := FileAccess.open(fixture,FileAccess.WRITE)
    check(file != null,"temporary content fixture writable")
    if file == null:
        quit(1)
        return
    file.store_string(JSON.stringify(expanded))
    file.close()
    var martial = SchoolCatalog.new(fixture)
    check(martial.load_error.is_empty(),"martial forms may reference standalone buffs: "+martial.load_error)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture))
    var items = ItemCatalog.new()
    check(items.load_error.is_empty(),"equipment catalog still valid")
    var role = Runtime.new("shen_changfeng")
    check(role.inventory.add("river_sword"),"equip new weapon definition")
    var sword_uid: String = str(role.inventory.last_added_uids[0])
    check(role.inventory.equip(sword_uid),"equip weapon UID")
    check(role.inventory.add("padded_armor"),"equip new armor definition")
    check(role.inventory.equip(str(role.inventory.last_added_uids[0])),"equip armor UID")
    var ids: Dictionary = {71:"shen_changfeng",72:"pursuer_captain"}
    var roster: Array = [
        {"id":71,"name":"hero","team_id":0,"controller":"PLAYER","cell":[6,4]},
        {"id":72,"name":"foe","team_id":1,"controller":"AI","cell":[8,4]}
    ]
    var registry = Registry.new()
    var options: Dictionary = registry.battle_options(roster,ids,{
        "shen_changfeng":role.battle_build()
    })
    check(not options.is_empty(),"character build injects without actor-id coupling")
    var battle = Model.new()
    battle.reset(2026,-1,"tingfeng",options)
    var actor = battle.state.get_actor(71)
    check(battle.state.outcome == "playing" and actor != null,"battle runs with content-modular actor")
    if actor != null:
        var original_con: int = int(registry.get_profile("shen_changfeng").attributes.CON)
        check(actor.attributes.CON == original_con + 1,"armor modifier applied")
        check(battle.statuses.add(71,"iron_body"),"author-created buff applies")
        check(actor.attributes.CON == original_con + 3,"Buff plus armor modify same base deterministically")
        battle.statuses.remove(71,"iron_body")
        check(actor.attributes.CON == original_con + 1,"removing buff preserves armor")
        var snap: Dictionary = battle.snapshot(71)
        check(snap.actors[0].get("equipment",{}).get("weapon","") == "river_sword","snapshot retains equipment without exposing mutable catalog")
    print("R15_INTEGRATION_PASS failures=",failures)
    quit(0 if failures == 0 else 1)
