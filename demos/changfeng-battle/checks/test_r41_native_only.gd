extends SceneTree
## R41: obsolete content formats cannot silently re-enter production loaders.
const Native = preload("res://scripts/content/content_registry.gd")
const Scenario = preload("res://scripts/scenario_director.gd")
const Schools = preload("res://scripts/school_catalog.gd")
const CharacterRegistry = preload("res://scripts/character_registry.gd")
const MapBake = preload("res://scripts/map_bake.gd")
const Manifest = preload("res://scripts/content/content_manifest.gd")
const CharacterDefinition = preload("res://scripts/content/character_definition.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("R41_NATIVE_ONLY: " + label)

func _run() -> void:
    var native = Native.new()
    check(native.load_error.is_empty() and not native.definitions.has("legacy_mapping"),
        "native registry has no legacy ID domain")
    for path in [
        "res://data/school_forms.json", "res://data/tingfeng_cards.json",
        "res://data/legacy_id_map.json", "res://data/demo_scenario.json",
        "res://data/techniques.json", "res://data/action_timelines.json",
        "res://data/characters/index.json", "res://data/items/index.json",
        "res://data/buffs/index.json", "res://data/affixes/index.json",
        "res://data/chapters/index.json", "res://data/maps/rainy_bridge.json",
        "res://scripts/legacy_skill_adapter.gd",
        "res://scripts/content/legacy_mapping_definition.gd",
        "res://scripts/content/legacy_mapping_entry_definition.gd",
        "res://data/native/legacy/legacy_skill_ids.tres"
    ]:
        check(not FileAccess.file_exists(path), "obsolete source removed: " + path)
    for script_path in [
        "school_catalog.gd", "card_system.gd", "scenario_director.gd",
        "chapter_catalog.gd", "character_registry.gd", "item_catalog.gd",
        "equipment_affix_catalog.gd", "status_catalog.gd",
        "technique_runtime.gd", "opening_story.gd", "map_bake.gd",
        "content/content_registry.gd", "content/content_manifest.gd"
    ]:
        var text: String = FileAccess.get_file_as_string("res://scripts/" + script_path)
        check(not text.is_empty() and not text.contains("JSON.parse")
            and not text.contains("JSON.new") and not text.contains(".json")
            and not text.contains("legacy_skill_adapter")
            and not text.contains("legacy_mapping"),
            "native-only production catalog: " + script_path)
    var broken = Manifest.new()
    var misplaced = CharacterDefinition.new()
    misplaced.content_id = "r41_misplaced"
    broken.buffs.append(misplaced)
    check(not native.import_manifest(broken) and native.entries("buff").is_empty(),
        "invalid typed manifest rejects foreign resource and leaves no partial data")
    check(Native.new().entries("character").has("shen_changfeng"),
        "failed import never mutates committed manifest")
    check(not Scenario.new().encounter("escort_ambush").is_empty()
        and Schools.new().get_school("tingfeng").get("name","") != ""
        and CharacterRegistry.new().get_profile("shen_changfeng").get("name","") != "",
        "encounter, skills and character resolve from native cards")
    check(MapBake.new().error.is_empty(),
        "native map loads")
    check(not MapBake.new("res://data/maps/rainy_bridge.json").error.is_empty()
        and not CharacterRegistry.new("res://data/characters/index.json").load_error.is_empty(),
        "deleted JSON paths cannot be loaded by custom arguments")
    print("R41_NATIVE_ONLY_PASS failures=", failures)
    quit(1 if failures else 0)
