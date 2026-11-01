extends SceneTree
## Template integration: only typed Resources, existing catalogs and normal gameplay rules.
const Native = preload("res://scripts/content/content_registry.gd")
const Schools = preload("res://scripts/school_catalog.gd")
const Cards = preload("res://scripts/card_system.gd")
const State = preload("res://scripts/battle_state.gd")
const Characters = preload("res://scripts/character_registry.gd")
const Factory = preload("res://scripts/character_factory.gd")
const Items = preload("res://scripts/item_catalog.gd")
const Chapters = preload("res://scripts/chapter_catalog.gd")
const Scenarios = preload("res://scripts/scenario_director.gd")
const Story = preload("res://scripts/opening_story.gd")
const TEMPLATE_MANIFEST := "res://data/templates/template_manifest.tres"
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("TEMPLATE_CONTENT FAIL: " + label)

func _run() -> void:
    var fixture = Native.new(TEMPLATE_MANIFEST)
    check(fixture.load_error.is_empty(), "template manifest imports: " + fixture.load_error)
    check(fixture.entries("character").has("template_wanderer")
        and fixture.entries("item").has("template_medicine")
        and fixture.entries("school").has("template_school")
        and fixture.entries("chapter").has("template_chapter")
        and fixture.entries("encounter").has("template_encounter"),
        "all four content types and optional encounter are native definitions")

    var schools = Schools.new(TEMPLATE_MANIFEST)
    var core: Dictionary = schools.get_school("template_school")
    var deck: Array = schools.deck_for("template_school", [])
    var total := 0
    for entry in deck:
        total += int(entry.count)
    check(schools.load_error.is_empty() and core.get("core_forms", []).size() == 2
        and deck.size() == 2 and total == 12,
        "two independent core skills create a valid 12-card martial deck")

    var battle_cards = Cards.new(State.new(100), TEMPLATE_MANIFEST,
        {0:"template_school"}, {0:["template_school"]})
    check(battle_cards.load_error.is_empty()
        and battle_cards.definitions.has("template_form_a")
        and battle_cards.definitions.has("template_form_b"),
        "unmodified CardSystem registers copied martial form definitions")

    var registry = Characters.new(TEMPLATE_MANIFEST)
    check(registry.load_error.is_empty()
        and registry.get_profile("template_wanderer").get("school_id") == "wind_sword",
        "sample character passes the production character schema")
    var factory = Factory.new(registry)
    var wanderer = factory.create_runtime("template_wanderer")
    check(wanderer != null and factory.load_error.is_empty()
        and (wanderer == null or wanderer.inventory.stacks.get("healing_powder", 0) == 1),
        "CharacterFactory creates the template character and starting inventory")

    var items = Items.new(TEMPLATE_MANIFEST)
    var medicine: Dictionary = items.get_item("template_medicine")
    check(items.load_error.is_empty() and medicine.get("kind") == "consumable"
        and medicine.get("effects", []) == [{"type":"gain_qi", "amount":2}],
        "ItemCatalog reads a functional typed consumable")

    var director = Scenarios.new(TEMPLATE_MANIFEST)
    var options: Dictionary = director.battle_options("template_encounter")
    check(director.load_error.is_empty() and options.get("combatants", []).size() == 2
        and options.get("map_definition_path", "") == "res://data/maps/rainy_bridge.tres",
        "encounter template resolves valid actors and native map")

    var story = Story.new("res://data/templates/story.tres")
    var chapters = Chapters.new(TEMPLATE_MANIFEST)
    var chapter: Dictionary = chapters.get_chapter("template_chapter")
    check(story.load_error.is_empty() and chapters.load_error.is_empty()
        and chapter.get("story_id") == "template_story"
        and chapter.get("encounter_id") == "r40_quick_duel"
        and chapter.get("scene", {}).get("npc_character_id") == "river_messenger"
        and chapter.get("requirements", []).size() == 1,
        "chapter template validates story, NPC, battle gate and existing duel")

    var production = Native.new()
    check(production.load_error.is_empty()
        and not production.entries("character").has("template_wanderer")
        and not production.entries("school").has("template_school")
        and not production.entries("chapter").has("template_chapter")
        and not production.entries("item").has("template_medicine"),
        "example resources are isolated from the production content manifest")
    print("CONTENT_TEMPLATE_PASS failures=", failures)
    quit(1 if failures else 0)
