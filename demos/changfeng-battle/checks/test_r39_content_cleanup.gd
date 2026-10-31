extends SceneTree
## R39: registry has no opaque content; all old authored concepts are native.
const Native = preload("res://scripts/content/content_registry.gd")
const Schools = preload("res://scripts/school_catalog.gd")
const Techniques = preload("res://scripts/technique_runtime.gd")
const Scenarios = preload("res://scripts/scenario_director.gd")
const MapBake = preload("res://scripts/map_bake.gd")
const Timeline = preload("res://scripts/battle_action_timeline.gd")
var failures: int = 0

func check(ok: bool, description: String) -> void:
    if not ok:
        failures += 1
        printerr("R39 CONTENT FAIL: " + description)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var registry = Native.new()
    check(registry.load_error.is_empty(), "manifest imports with typed resources")
    check(not FileAccess.file_exists("res://scripts/content/data_document.gd"),
        "old generic WuxiaDataDocument class removed")
    for old_id in ["school_forms", "tingfeng_cards", "legacy_id_map",
            "techniques", "demo_scenario", "action_timelines", "rainy_bridge"]:
        check(not ResourceLoader.exists("res://data/native/documents/" + old_id + ".tres"),
            "obsolete production document absent: " + old_id)
    var schools: Dictionary = registry.entries("rule_catalog").get("r36_school_forms",{}).get("data",{})
    var tingfeng: Dictionary = registry.entries("rule_catalog").get("r37_tingfeng_cards",{}).get("data",{})
    check(schools.get("schools",[]).size() == 10 and
        schools.get("cards",[]).size() == 20 and
        schools.get("combos",[]).size() == 7,
        "10 schools, 20 core cards and 7 combos retained")
    check(tingfeng.get("cards",[]).size() == 6 and
        tingfeng.get("combos",[]).size() == 3 and
        tingfeng.get("deck",{}).get("cards",[]).size() == 4,
        "Tingfeng six definitions and four physical deck entries retained")
    check(registry.entries("action_timeline").has("r32_default_action_timeline") and
        registry.entries("technique").has("tf_change_stage"),
        "typed adapters, animation timeline and stage graph registered")
    check(Schools.new().load_error.is_empty(), "martial catalogs retain existing validation")
    check(Techniques.new().load_error.is_empty(), "technique runtime accepts typed stages")
    var encounters = Scenarios.new()
    check(encounters.load_error.is_empty() and encounters.encounter("escort_ambush").get("combatants",[]).size() == 6
        and encounters.encounter("river_watch_ambush").get("combatants",[]).size() == 6,
        "both original six-person encounters unchanged")
    var map = MapBake.new()
    check(map.error.is_empty() and map.width == 15 and map.height == 10 and map.id == "rainy_bridge",
        "GRID terrain remains correctly calibrated")
    var timeline = Timeline.new()
    check(timeline.load_error.is_empty() and timeline.profiles.size() == 9
        and timeline.event_animations.size() == 13,
        "all animation timings and events still exist")
    print("R39_NATIVE_CONTENT_PASS failures=", failures)
    quit(1 if failures else 0)
