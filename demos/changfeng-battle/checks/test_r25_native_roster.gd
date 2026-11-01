extends SceneTree
## Stable, independent expectations for important authored character cards.
const Registry = preload("res://scripts/character_registry.gd")
const Factory = preload("res://scripts/character_factory.gd")
const EXPECTED: Dictionary = {
    "shen_changfeng": {"name":"沈长风", "actor":0, "school":"wind_sword", "STR":12, "AGI":12},
    "gu_qingshuang": {"name":"顾清霜", "actor":2, "school":"tide", "STR":9, "AGI":12},
    "pursuer_captain": {"name":"追镖首领", "actor":1, "school":"saber", "STR":13, "AGI":9},
    "river_messenger": {"name":"河渡信使", "actor":-1, "school":"", "STR":8, "AGI":13}
}
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("R25_ROSTER: " + label)

func _run() -> void:
    var registry = Registry.new()
    check(registry.load_error.is_empty() and registry.profiles.size() >= 9
        and registry.actor_ids().size() == 6, "native roster and six battle actors load")
    for id in EXPECTED:
        var wanted: Dictionary = EXPECTED[id]
        var profile: Dictionary = registry.get_profile(str(id))
        check(profile.get("name", "") == wanted.name
            and profile.get("school_id", "") == wanted.school
            and int(profile.get("battle_actor_id", -99)) == wanted.actor,
            "fixed character identity and school: " + str(id))
        var attributes: Dictionary = profile.get("attributes", {})
        check(attributes.get("STR") == wanted.STR and attributes.get("AGI") == wanted.AGI,
            "fixed starting attributes: " + str(id))
        if wanted.actor >= 0:
            check(registry.for_actor(wanted.actor).get("id", "") == id,
                "battle slot resolves character: " + str(id))
        else:
            check(profile.get("learned_schools", []) == [],
                "noncombatant has no learned combat school")
    check(registry.get_profile("r24_lan_chen").get("id", "") == "r24_lan_chen",
        "authored recruit remains available")
    var factory = Factory.new(registry)
    for id in ["shen_changfeng", "gu_qingshuang", "pursuer_captain", "r24_lan_chen"]:
        check(factory.create_runtime(id) != null, "character instantiates: " + id)
    print("R25_NATIVE_ROSTER_PASS failures=", failures)
    quit(1 if failures else 0)
