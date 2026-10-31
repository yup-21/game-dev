extends SceneTree
## Native character cards must provide identity, stats and runtime bindings.
const Native = preload("res://scripts/content/content_registry.gd")
const Registry = preload("res://scripts/character_registry.gd")
const Factory = preload("res://scripts/character_factory.gd")
var failures := 0
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("R25_ROSTER: " + label)
func _run() -> void:
    var native = Native.new()
    var registry = Registry.new()
    check(native.load_error.is_empty() and registry.load_error.is_empty(),
        "production Resource registry validates")
    check(native.entries("character").size() >= 9 and registry.profiles.size() >= 9,
        "original roster and recruit remain authored")
    for id in native.entries("character"):
        var expected: Dictionary = native.entries("character")[id]
        var actual: Dictionary = registry.get_profile(str(id))
        check(actual == expected, "identity, skills, attributes and art: " + str(id))
        if int(expected.get("battle_actor_id",-1)) >= 0:
            check(registry.for_actor(int(expected.battle_actor_id)).get("id") == id,
                "actor binding: " + str(id))
    var factory = Factory.new()
    for id in ["shen_changfeng", "gu_qingshuang", "pursuer_captain", "r24_lan_chen"]:
        check(factory.create_runtime(id) != null, "native card instantiates: " + id)
    print("R25_NATIVE_ROSTER_PASS failures=", failures)
    quit(1 if failures else 0)
