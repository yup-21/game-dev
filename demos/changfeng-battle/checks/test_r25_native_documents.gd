extends SceneTree
## All historical production catalog files have an equivalent native Resource.
const Native = preload("res://scripts/content/content_registry.gd")
const Schools = preload("res://scripts/school_catalog.gd")
const Techniques = preload("res://scripts/technique_runtime.gd")
const Scenarios = preload("res://scripts/scenario_director.gd")
const Chapters = preload("res://scripts/chapter_catalog.gd")
const Story = preload("res://scripts/opening_story.gd")
const Map = preload("res://scripts/map_bake.gd")
const Timeline = preload("res://scripts/battle_action_timeline.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("R25 DOCUMENT FAIL: " + label)

func _same(a: Variant, b: Variant) -> bool:
    if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
        return float(a) == float(b)
    if a is Dictionary and b is Dictionary:
        if a.size() != b.size(): return false
        for key in a:
            if not b.has(key) or not _same(a[key],b[key]): return false
        return true
    if a is Array and b is Array:
        if a.size() != b.size(): return false
        for i in range(a.size()):
            if not _same(a[i],b[i]): return false
        return true
    return a == b

func _run() -> void:
    var native = Native.new()
    check(native.load_error.is_empty(), "manifest: " + native.load_error)
    var pairs: Array = [
        ["school_forms","school_forms.json"],
        ["tingfeng_cards","tingfeng_cards.json"],
        ["legacy_id_map","legacy_id_map.json"],
        ["demo_scenario","demo_scenario.json"],
        ["rainy_bridge","maps/rainy_bridge.json"]
    ]
    for pair in pairs:
        var id: String = "r25_" + str(pair[0])
        var original: Variant = JSON.parse_string(
            FileAccess.get_file_as_string("res://data/" + str(pair[1])))
        var replacement: Dictionary = native.document(id)
        check(original is Dictionary and not replacement.is_empty()
            and _same(original,replacement), "native document parity " + id)

    # The two playable chapters no longer use opaque WuxiaDataDocument blobs.
    for name in ["rain_escort_prologue","river_watch"]:
        var chapter: Dictionary = native.entries("chapter").get(name,{})
        var historical: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
            "res://data/chapters/" + name + ".json"))
        check(not chapter.is_empty() and chapter.get("encounter_id") == historical.get("encounter_id")
            and chapter.get("next_chapter_id") == historical.get("next_chapter_id")
            and chapter.get("scene",{}).get("background") == historical.get("scene",{}).get("background")
            and _same(chapter.get("victory_events",[]),historical.get("victory_events",[])),
            "typed chapter preserves gameplay fields " + name)
        check(native.document("r25_" + name).is_empty(),
            "obsolete chapter blob removed from production manifest " + name)
    for pair in [["rain_escort_prologue_story","opening_story.json"],
            ["river_watch_story","river_watch_story.json"]]:
        var authored: Dictionary = native.entries("story").get(str(pair[0]),{})
        var historical: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
            "res://data/" + str(pair[1])))
        check(not authored.is_empty() and _same(authored.get("cinematic",[]),
            historical.get("cinematic",[])) and authored.get("entry_node") == historical.get("entry_node")
            and authored.get("dialogues",[]).size() == historical.get("dialogues",[]).size(),
            "typed story preserves pacing and dialogue count " + str(pair[0]))
    var legacy_techniques: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/techniques.json"))
    var typed_technique: Dictionary = native.entries("technique").get("tf_change_stage", {})
    check(not typed_technique.is_empty() and _same(typed_technique.get("nodes", []), legacy_techniques.techniques[0].nodes)
        and typed_technique.get("name") == legacy_techniques.techniques[0].name
        and typed_technique.get("auto_equip") == true
        and typed_technique.get("hold_own_actions") == 1
        and _same(typed_technique.get("trigger", {}), legacy_techniques.techniques[0].trigger),
        "typed technique preserves all original four stages and trigger")
    check(native.document("r25_techniques").is_empty(), "opaque technique document removed")
    var schools = Schools.new()
    var techniques = Techniques.new()
    var encounters = Scenarios.new()
    var chapters = Chapters.new()
    var story = Story.new()
    var map = Map.new()
    var timeline = Timeline.new()
    check(schools.load_error.is_empty() and not schools.get_school("tingfeng").is_empty(),
        "default martial schools consume Resource")
    check(techniques.load_error.is_empty() and techniques.definitions.size() >= 1,
        "default techniques consume Resource")
    check(encounters.load_error.is_empty() and not encounters.encounter("escort_ambush").is_empty(),
        "default encounter consumes Resource")
    check(chapters.load_error.is_empty() and chapters.get_chapter("river_watch").has("scene"),
        "default chapter consumes Resource")
    check(story.load_error.is_empty() and story.data.get("id","") == "rain_escort_prologue_story",
        "default story consumes Resource")
    check(map.error.is_empty() and map.id == "rainy_bridge",
        "default grid map consumes Resource")
    check(timeline.load_error.is_empty() and not timeline.profiles.is_empty()
        and native.document("r25_action_timelines").is_empty()
        and native.entries("action_timeline").has("r32_default_action_timeline"),
        "default action timeline uses typed Resource, not the old document")
    print("R25_NATIVE_DOCUMENTS_PASS failures=",failures)
    quit(0 if failures == 0 else 1)
