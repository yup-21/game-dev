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
    # These values are intentionally independent of the same manifest's lookup.
    var chapters_expected: Dictionary = {
        "rain_escort_prologue": {
            "story":"rain_escort_prologue_story", "encounter":"escort_ambush",
            "next":"river_watch", "npc":"escort_elder"
        },
        "river_watch": {
            "story":"river_watch_story", "encounter":"river_watch_ambush",
            "next":"", "npc":"river_messenger"
        }
    }
    for id in chapters_expected:
        var wanted: Dictionary = chapters_expected[id]
        var chapter: Dictionary = native.entries("chapter").get(id, {})
        check(chapter.get("story_id") == wanted.story
            and chapter.get("encounter_id") == wanted.encounter
            and chapter.get("next_chapter_id") == wanted.next,
            "fixed chapter story, battle and progression: " + str(id))
        check(chapter.get("scene", {}).get("npc_character_id") == wanted.npc,
            "fixed chapter NPC: " + str(id))
    for id in {"escort_ambush":2026, "river_watch_ambush":2031}:
        var encounter: Dictionary = native.entries("encounter").get(id, {})
        check(encounter.get("seed") == {"escort_ambush":2026, "river_watch_ambush":2031}[id]
            and encounter.get("combatants", []).size() == 6
            and encounter.get("map_id") == "rainy_bridge",
            "fixed six-actor encounter, seed and map: " + str(id))
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
    check(schools.load_error.is_empty() and schools.forms.size() == 20
        and schools.combos.size() == 7,
        "ten-school card definitions and combo rules registered")
    var tingfeng: Dictionary = native.entries("rule_catalog").get(
        "r37_tingfeng_cards", {}).get("data", {})
    check(tingfeng.get("cards", []).size() == 6
        and tingfeng.get("combos", []).size() == 3
        and tingfeng.get("deck", {}).get("cards", []).size() == 4,
        "Tingfeng cards, combos and initial deck preserved")
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
