extends SceneTree
## R17: independent affix definitions compose with item-instance equipment sources.
const Affixes = preload("res://scripts/equipment_affix_catalog.gd")
const Items = preload("res://scripts/item_catalog.gd")
const Runtime = preload("res://scripts/character_runtime.gd")
const Registry = preload("res://scripts/character_registry.gd")
const Model = preload("res://scripts/battle_model.gd")
var failures: int = 0

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("AFFIX FAIL: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var catalog = Affixes.new()
    check(catalog.load_error.is_empty() and catalog.definitions.size() == 3,"independent affix catalog")
    var items = Items.new()
    check(items.load_error.is_empty() and items.definitions.size() >= 4,"items cross-validate affix pools")
    var role = Runtime.new("shen_changfeng")
    check(role.inventory.add("river_sword",2),"create two independent sword UIDs")
    var first: String = str(role.inventory.last_added_uids[0])
    var second: String = str(role.inventory.last_added_uids[1])
    check(role.inventory.set_affixes(first,["keen_edge"]),"assign allowed affix")
    check(not role.inventory.set_affixes(first,["iron_guard"]),"reject off-slot affix")
    check(not role.inventory.set_affixes(first,["keen_edge","quickstep"]),"enforce per-item affix capacity")
    check(role.inventory.instances[first].affixes == ["keen_edge"]
        and role.inventory.instances[second].affixes.is_empty(),"failed affix operations are atomic per UID")
    check(role.inventory.reroll_affixes(second,2026),"roll affix from declared pool")
    var rolled: Array = role.inventory.instances[second].affixes.duplicate()
    check(role.inventory.reroll_affixes(second,2026)
        and role.inventory.instances[second].affixes == rolled,"seeded affixes reproducible")
    check(role.inventory.equip(first),"equip selected instance")
    var sources: Dictionary = role.inventory.modifier_sources()
    check(sources.has("equipment:weapon") and sources.has("affix:weapon:%s:keen_edge" % first),
        "base gear and UID-affix have isolated modifier tokens")
    var snapshot: Dictionary = role.inventory.snapshot()
    var copy = Runtime.new("shen_changfeng")
    check(copy.inventory.restore(JSON.parse_string(JSON.stringify(snapshot))),
        "instance affixes validate through JSON roundtrip")
    check(copy.inventory.equipment_affixes().weapon.affixes == ["keen_edge"],
        "equipped item exposes exact affix identity")
    var corrupted: Dictionary = snapshot.duplicate(true)
    corrupted.instances[first].affixes = ["iron_guard"]
    check(not copy.inventory.restore(corrupted)
        and copy.inventory.equipment_affixes().weapon.affixes == ["keen_edge"],
        "invalid incoming affixes cannot partially mutate inventory")
    var old: Dictionary = snapshot.duplicate(true)
    old.instances[first].erase("affixes")
    check(copy.inventory.restore(old) and copy.inventory.instances[first].affixes.is_empty(),
        "older equipment instances without affix field remain valid")
    var roster: Array = [
        {"id":71,"name":"hero","team_id":0,"controller":"PLAYER","cell":[6,4]},
        {"id":72,"name":"foe","team_id":1,"controller":"AI","cell":[8,4]}
    ]
    var options: Dictionary = Registry.new().battle_options(roster,
        {71:"shen_changfeng",72:"pursuer_captain"},
        {"shen_changfeng":role.battle_build()})
    check(not options.is_empty(),"affix-bearing character build verified")
    var battle = Model.new()
    battle.reset(2026,71,"tingfeng",options)
    var a = battle.state.get_actor(71)
    check(battle.state.outcome == "playing" and a != null,"affix-bearing battle starts")
    if a != null:
        var plain: int = int(battle.attributes.derive(a.attributes).attack)
        check(int(a.stats.attack) == plain+4,"base sword +2 and keen affix +2 both apply")
        check(battle.snapshot(71).actors[0].equipment_affixes.weapon.affixes == ["keen_edge"],
            "character HUD snapshot includes affix detail")
    check(role.inventory.unequip("weapon")
        and not role.inventory.modifier_sources().has("affix:weapon:%s:keen_edge" % first),
        "unequipping removes only that UID affix source")
    print("EQUIPMENT_AFFIX_PASS failures=",failures)
    quit(0 if failures == 0 else 1)
