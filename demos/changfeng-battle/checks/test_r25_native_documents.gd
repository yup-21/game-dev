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
        ["techniques","techniques.json"],
        ["demo_scenario","demo_scenario.json"],
        ["action_timelines","action_timelines.json"],
        ["rainy_bridge","maps/rainy_bridge.json"],
        ["opening_story","opening_story.json"],
        ["river_watch_story","river_watch_story.json"],
        ["rain_escort_prologue","chapters/rain_escort_prologue.json"],
        ["river_watch","chapters/river_watch.json"]
    ]
    for pair in pairs:
        var id: String = "r25_" + str(pair[0])
        var original: Variant = JSON.parse_string(
            FileAccess.get_file_as_string("res://data/" + str(pair[1])))
        var replacement: Dictionary = native.document(id)
        check(original is Dictionary and not replacement.is_empty()
            and _same(original,replacement), "native document parity " + id)
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
    check(story.load_error.is_empty() and story.data.get("id","") == "rain_escort_prologue",
        "default story consumes Resource")
    check(map.error.is_empty() and map.id == "rainy_bridge",
        "default grid map consumes Resource")
    check(timeline.load_error.is_empty() and not timeline.profiles.is_empty(),
        "default action timeline consumes Resource")
    print("R25_NATIVE_DOCUMENTS_PASS failures=",failures)
    quit(0 if failures == 0 else 1)
