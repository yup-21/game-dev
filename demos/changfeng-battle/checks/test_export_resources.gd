extends SceneTree
## Exported .pck boots with native Resources and NO historical JSON.
const Native = preload("res://scripts/content/content_registry.gd")
const Director = preload("res://scripts/scenario_director.gd")
const REQUIRED_FIXTURES := [
    "res://data/demo_scenario.json",
    "res://data/chapters/index.json",
    "res://data/chapters/rain_escort_prologue.json",
    "res://data/chapters/river_watch.json",
    "res://data/river_watch_story.json",
    "res://data/characters/river_messenger.json",
    "res://data/characters/index.json",
    "res://data/items/index.json",
    "res://data/affixes/index.json",
    "res://data/buffs/index.json",
    "res://data/school_forms.json",
    "res://assets/production_manifest.json"
]
const REQUIRED_SCENES := [
    "res://opening.tscn",
    "res://battle_hd2d.tscn",
    "res://demo_result.tscn"
]
const REQUIRED_ART := [
    "res://assets/scenes/battle/rainy_bridge_battle.webp",
    "res://assets/scenes/story/ruined_temple_story.webp",
    "res://assets/ui/technique_art_atlas_v1.png"
]

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var failures: int = 0
    for path in REQUIRED_FIXTURES:
        if FileAccess.file_exists(path):
            failures += 1
            push_error("EXPORT_LEGACY_FIXTURE_LEAK " + path)
    var registry = Native.new()
    if not registry.load_error.is_empty():
        failures += 1
        push_error("EXPORT_NATIVE_MANIFEST_INVALID " + registry.load_error)
    for kind in ["character","story","chapter","encounter","map",
            "rule_catalog","technique","action_timeline"]:
        if registry.entries(kind).is_empty():
            failures += 1
            push_error("EXPORT_NATIVE_CATALOG_MISSING " + kind)
    var director = Director.new()
    if not director.load_error.is_empty():
        failures += 1
        push_error("EXPORT_ENCOUNTERS_INVALID " + director.load_error)
    else:
        for encounter_id in ["r40_quick_duel","escort_ambush","river_watch_ambush"]:
            var options: Dictionary = director.battle_options(encounter_id)
            if options.is_empty() or not str(options.get("map_definition_path","")).ends_with(".tres"):
                failures += 1
                push_error("EXPORT_NATIVE_ENCOUNTER_UNRESOLVED " + encounter_id)
    for path in REQUIRED_SCENES:
        if not ResourceLoader.exists(path, "PackedScene"):
            failures += 1
            push_error("EXPORT_MISSING_SCENE " + path)
    for path in REQUIRED_ART:
        if not ResourceLoader.exists(path, "Texture2D"):
            failures += 1
            push_error("EXPORT_MISSING_ART " + path)
    print("EXPORT_RESOURCE_PASS failures=", failures)
    quit(1 if failures else 0)
