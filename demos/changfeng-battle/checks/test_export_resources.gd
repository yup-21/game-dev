extends SceneTree
## Run against an exported PCK from outside the source checkout.
## Dynamic JSON references need an explicit export include_filter.
const REQUIRED_JSON := [
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
    for path in REQUIRED_JSON:
        if not FileAccess.file_exists(path):
            failures += 1
            push_error("EXPORT_MISSING_JSON " + path)
            continue
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        if parsed == null:
            failures += 1
            push_error("EXPORT_INVALID_JSON " + path)
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
