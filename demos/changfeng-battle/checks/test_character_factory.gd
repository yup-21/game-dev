extends SceneTree
## R19: native hero card -> CharacterFactory -> inventory/equipment -> battle build.
const NativeContent = preload("res://scripts/content/content_registry.gd")
const Registry = preload("res://scripts/character_registry.gd")
const Factory = preload("res://scripts/character_factory.gd")
const Loadout = preload("res://scripts/content/character_loadout.gd")
const Inventory = preload("res://scripts/inventory_runtime.gd")
const Session = preload("res://scripts/game_session.gd")

var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("R19 CHARACTER FACTORY FAIL: " + label)

func _run() -> void:
    var native = NativeContent.new()
    check(native.load_error.is_empty() and native.entries("character").has("shen_changfeng"),
        "canonical protagonist comes from native manifest")
    var registry = Registry.new()
    check(registry.load_error.is_empty() and registry.profiles.size() >= 8 and registry.actor_ids().size() == 6,
        "migration keeps original eight identities and six battle actors")
    var hero_definition: Dictionary = registry.get_profile("shen_changfeng")
    check(hero_definition.get("name") == "沈长风" and hero_definition.get("school_id") == "wind_sword",
        "migrated native identity and martial bindings are preserved")
    check(hero_definition.get("starting_loadout", []).size() == 3,
        "all three starting equipment/consumable entries are authored")

    var factory = Factory.new(registry)
    var hero = factory.create_runtime("shen_changfeng")
    check(hero != null and factory.load_error.is_empty(), "factory creates the persistent hero: " + factory.load_error)
    if hero != null:
        var snapshot: Dictionary = hero.inventory.snapshot()
        var uid: String = str(hero.inventory.equipped.get("weapon", ""))
        check(int(hero.inventory.stacks.get("healing_powder", 0)) == 2 and
            int(hero.inventory.stacks.get("breath_pill", 0)) == 1,
            "loadout seeds two powders and one qi pill")
        check(snapshot.instances.size() == 1 and not uid.is_empty() and
            snapshot.instances.get(uid, {}).get("definition_id") == "river_sword",
            "loadout creates and equips exactly one stable equipment UID")
        check(snapshot.instances.get(uid, {}).get("affixes", []) == ["keen_edge"],
            "authored equipment affix is present")
        check(hero.battle_build().get("equipment", {}).get("weapon") == "river_sword",
            "new factory output preserves battle options contract")
        hero.set_attribute("STR", 37)
        check(int(registry.get_profile("shen_changfeng").attributes.STR) == 12,
            "mutable runtime changes do not modify authored Resource")
    var textures: Dictionary = factory.presentation_assets("shen_changfeng")
    check(textures.get("portrait") is Texture2D and textures.get("sprite_sheet") is Texture2D,
        "portrait and sprite sheet are reachable by native resource dependencies")

    # An optional PackedScene can be instantiated without touching BattleModel.
    var fixture = Registry.new("res://data/native_examples.tres")
    var fixture_factory = Factory.new(fixture)
    var view = fixture_factory.instantiate_presentation("r18_guest_swordsman")
    check(view is Node2D and view.get_node_or_null("Portrait") is Sprite2D,
        "optional presentation scene is bound to the character card")
    if view != null:
        view.free()

    # An invalid loadout must not partially mutate a live inventory.
    var inventory = Inventory.new()
    var before: Dictionary = inventory.snapshot()
    check(not Loadout.apply([
        {"item_id":"healing_powder","count":2,"equip":false,"affixes":[]},
        {"item_id":"does_not_exist","count":1,"equip":false,"affixes":[]}
    ], inventory) and inventory.snapshot() == before,
        "broken cross-reference rolls back all staged inventory")
    check(not Loadout.apply([
        {"item_id":"river_sword","count":1,"equip":true,"affixes":["keen_edge"]},
        {"item_id":"river_sword","count":1,"equip":true,"affixes":["keen_edge"]}
    ], inventory) and inventory.snapshot() == before,
        "duplicate equipped slot is rejected without committing UIDs")

    var numeric_inventory = Inventory.new()
    check(Loadout.apply([
        {"item_id":"healing_powder","count":2.0,"equip":false,"affixes":[]}
    ], numeric_inventory) and numeric_inventory.stacks.get("healing_powder", 0) == 2,
        "integer-valued numeric fields remain accepted")

    var session = Session.new()
    root.add_child(session)
    session.start_new_game()
    var party_hero = session.character("shen_changfeng")
    check(party_hero != null and party_hero.inventory.stacks.get("healing_powder", 0) == 2 and
        party_hero.inventory.equipped.has("weapon"), "GameSession uses authored loadout")
    session.free()
    print("R19_CHARACTER_FACTORY_PASS failures=", failures)
    quit(0 if failures == 0 else 1)
