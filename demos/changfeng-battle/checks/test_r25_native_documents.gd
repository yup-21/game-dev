extends SceneTree
## Native content contracts, not snapshots of deleted JSON documents.
const Native = preload("res://scripts/content/content_registry.gd")
const Schools = preload("res://scripts/school_catalog.gd")
const Techniques = preload("res://scripts/technique_runtime.gd")
const Scenarios = preload("res://scripts/scenario_director.gd")
const Chapters = preload("res://scripts/chapter_catalog.gd")
const Story = preload("res://scripts/opening_story.gd")
const Map = preload("res://scripts/map_bake.gd")
const Timeline = preload("res://scripts/battle_action_timeline.gd")
var failures := 0
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("R25_DOCUMENTS: " + label)
func _run() -> void:
    var native = Native.new()
    check(native.load_error.is_empty(), "manifest validates: " + native.load_error)
    check(native.entries("rule_catalog").size() == 2
        and native.entries("technique").has("tf_change_stage"), "typed rulebooks and stage graphs")
    for id in ["rain_escort_prologue", "river_watch"]:
        var chapter: Dictionary = native.entries("chapter").get(id, {})
        check(not chapter.is_empty() and native.entries("encounter").has(str(chapter.get("encounter_id", ""))),
            "chapter encounter binding " + id)
        check(native.entries("story").has(str(chapter.get("story_id", ""))),
            "chapter story binding " + id)
    for id in ["escort_ambush", "river_watch_ambush"]:
        var encounter: Dictionary = native.entries("encounter").get(id, {})
        check(encounter.get("combatants", []).size() == 6
            and native.entries("map").has(str(encounter.get("map_id", ""))),
            "six-person encounter and registered map: " + id)
    var map_record: Dictionary = native.entries("map").get("rainy_bridge", {})
    check(map_record.get("grid", {}).get("columns") == 15
        and map_record.get("grid", {}).get("rows") == 10
        and map_record.get("rows", []).size() == 10,
        "painted map retains 15x10 collision geometry")
    var schools = Schools.new()
    var techniques = Techniques.new()
    var encounters = Scenarios.new()
    var chapters = Chapters.new()
    var story = Story.new()
    var map = Map.new()
    var timeline = Timeline.new()
    check(schools.load_error.is_empty() and schools.forms.size() == 20,
        "original martial card semantics registered")
    check(techniques.load_error.is_empty() and techniques.definitions.has("tf_change_stage"),
        "stage graph resolves")
    check(encounters.load_error.is_empty() and not encounters.battle_options("escort_ambush").is_empty(),
        "native encounter builds battle options")
    check(chapters.load_error.is_empty() and chapters.get_chapter("river_watch").has("scene"),
        "native chapter resolves")
    check(story.load_error.is_empty() and story.data.get("id", "") == "rain_escort_prologue_story",
        "story Resource resolves")
    check(map.error.is_empty() and map.id == "rainy_bridge", "native map resolves")
    check(timeline.load_error.is_empty() and timeline.profiles.size() == 9,
        "native action timeline resolves")
    print("R25_NATIVE_DOCUMENTS_PASS failures=", failures)
    quit(1 if failures else 0)
