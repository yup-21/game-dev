extends SceneTree
## R25: canonical roster must load from native Resources, with exact old profile semantics.
const Native = preload("res://scripts/content/content_registry.gd")
const Registry = preload("res://scripts/character_registry.gd")
const Factory = preload("res://scripts/character_factory.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("R25 ROSTER FAIL: " + label)

func _run() -> void:
    var n = Native.new()
    var r = Registry.new()
    check(n.load_error.is_empty() and r.load_error.is_empty(),
        "canonical native manifest and registry load")
    var expected: Array[String] = ["gu_qingshuang","green_wanderer",
        "pursuer_captain","black_blade","night_assassin","escort_elder","river_messenger"]
    check(n.entries("character").size() >= 9,
        "all eight original characters plus the R24 recruit are native")
    for id in expected:
        var source_path: String = "res://data/characters/" + id + ".json"
        var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_path))
        var actual: Dictionary = r.get_profile(id)
        check(n.entries("character").has(id) and not actual.is_empty(),
            "native replacement exists for " + id)
        if not source is Dictionary or actual.is_empty(): continue
        for key in ["id","battle_actor_id","name","title","role","faction",
                "team_hint","weapon","personality","biography","school_id",
                "attributes","passives","techniques","learned_schools","art"]:
            check(source.get(key) == actual.get(key),
                "field parity " + id + "." + key)
    check(r.for_actor(0).get("id") == "shen_changfeng" and
        r.for_actor(5).get("id") == "night_assassin",
        "actor 0..5 bindings preserved")
    var factory = Factory.new()
    check(factory.create_runtime("gu_qingshuang") != null and
        factory.create_runtime("pursuer_captain") != null,
        "migrated allies and enemies still construct through CharacterFactory")
    check(r.get_profile("r24_lan_chen").get("id") == "r24_lan_chen",
        "new native recruit remains registered")
    print("R25_NATIVE_ROSTER_PASS failures=",failures)
    quit(0 if failures == 0 else 1)
