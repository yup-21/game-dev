extends SceneTree
## New equipment and consumables are authored without BattleModel rules.
const Registry = preload("res://scripts/character_registry.gd")
const ItemCatalog = preload("res://scripts/item_catalog.gd")
const Runtime = preload("res://scripts/character_runtime.gd")
const Model = preload("res://scripts/battle_model.gd")
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("R14 INVENTORY FAIL: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog = ItemCatalog.new()
	check(catalog.load_error.is_empty() and catalog.definitions.size() == 3,"three independently authored items")
	var role = Runtime.new("shen_changfeng")
	check(role.load_error.is_empty(),"character runtime from profile")
	check(role.inventory.add("river_sword",2),"acquire two item instances")
	var first_uid: String = str(role.inventory.last_added_uids[0])
	var second_uid: String = str(role.inventory.last_added_uids[1])
	check(first_uid != second_uid and role.inventory.instances.size() == 2,"equipment has unique stable UIDs")
	check(role.inventory.equip(first_uid),"equip sword by UID")
	check(role.inventory.add("padded_armor"),"acquire armor")
	var armor_uid: String = str(role.inventory.last_added_uids[0])
	check(role.inventory.equip(armor_uid),"equip armor by UID")
	check(not role.inventory.equip("item:missing"),"invalid equip is rejected")
	check(role.inventory.add("healing_powder",3),"stack three consumables")
	var intent: Dictionary = role.inventory.consume("healing_powder")
	check(bool(intent.ok) and intent.effects[0].type == "heal_hp"
		and int(role.inventory.stacks.healing_powder) == 2,"consume produces declarative effect and decrements stack")
	check(role.set_growth("growth:practice",[{"stat":"STR","op":"flat","value":1}]),"permanent stat source")
	var before: Dictionary = role.snapshot()
	var restored = Runtime.new("shen_changfeng")
	var serialized: Variant = JSON.parse_string(JSON.stringify(before))
	check(restored.restore(serialized),"JSON roundtrip of character/inventory")
	check(restored.inventory.snapshot().instances.size() == 3
		and restored.inventory.equipped.size() == 2,"restore keeps item UID and equipment")
	var invalid: Dictionary = before.duplicate(true)
	invalid.inventory.equipped.weapon = "item:unknown"
	check(not restored.restore(invalid) and restored.inventory.equipped.weapon == first_uid,"invalid save is rejected atomically")
	var registry = Registry.new()
	var pursuer: Dictionary = registry.get_profile("pursuer_captain")
	var roster: Array = [
		{"id":71,"name":"shen","team_id":0,"controller":"PLAYER","cell":[6,4]},
		{"id":72,"name":pursuer.name,"team_id":1,"controller":"AI","cell":[8,4]}
	]
	var options: Dictionary = registry.battle_options(roster,
		{71:"shen_changfeng",72:"pursuer_captain"},
		{"shen_changfeng":restored.battle_build()})
	check(options.get("modifier_sources",{}).has(71),"runtime build delivers equipment and growth modifiers")
	var battle = Model.new()
	battle.reset(2026,-1,"tingfeng",options)
	var actor = battle.state.get_actor(71)
	check(battle.state.outcome == "playing" and actor != null,"battle starts with persisted role")
	if actor != null:
		var profile: Dictionary = registry.get_profile("shen_changfeng")
		check(int(actor.attributes.STR) == int(profile.attributes.STR)+1
			and int(actor.attributes.CON) == int(profile.attributes.CON)+1,"growth and armor apply without core edits")
		check(int(actor.stats.attack) == int(battle.attributes.derive(actor.attributes).attack)+2,"weapon adds damage stat")
		check(actor.equipment.get("weapon") == "river_sword"
			and battle.snapshot(71).actors[0].get("equipment",{}).get("weapon","") == "river_sword","battle snapshot exposes equipped definition")
	print("R14_INVENTORY_PASS failures=",failures)
	quit(0 if failures == 0 else 1)
