extends SceneTree
## Native manifest extensibility and combo activation limits.
const Catalog = preload("res://scripts/school_catalog.gd")
const Native = preload("res://scripts/content/content_registry.gd")
const Combos = preload("res://scripts/combo_resolver.gd")
const Combatant = preload("res://scripts/combatant_state.gd")
var failures := 0
func _initialize() -> void:
    var native = Native.new()
    var catalog = Catalog.new()
    check(native.load_error.is_empty() and catalog.load_error.is_empty(), "typed catalog validates")
    check(catalog.schools.size() >= 10 and catalog.forms.size() == 20
        and catalog.combos.size() == 7, "ten authored martial schools and combos")
    for school in catalog.schools:
        var deck: Array = catalog.deck_for(str(school.id), [])
        var count := 0
        for entry in deck:
            count += int(entry.count)
        check(count == 12, "native 12-card school deck: " + str(school.id))
    var extra: Dictionary = catalog.combos[0].duplicate(true)
    extra.id = "r41_activation_limit"
    extra.max_activations_per_action = 2
    var actor = Combatant.new()
    actor.attack_history = [{
        "definition_id": extra.sequence[0].card_id,
        "usage_id": extra.sequence[0].usage_id,
        "resolved": true, "interrupted": false, "hit": true
    }]
    var resolver = Combos.new({"combos": [extra]}, null)
    var next_card: String = str(extra.sequence[1].card_id)
    var next_usage: String = str(extra.sequence[1].usage_id)
    check(resolver.declaration(actor, next_card, next_usage).get("id", "") == extra.id,
        "first combo activation")
    actor.combo_used.append(extra.id)
    check(resolver.declaration(actor, next_card, next_usage).get("id", "") == extra.id,
        "second combo activation")
    actor.combo_used.append(extra.id)
    check(resolver.declaration(actor, next_card, next_usage).is_empty(),
        "third combo activation rejected")
    print("R41_CATALOG_EXTENSIBILITY_PASS failures=", failures)
    quit(1 if failures else 0)
func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("R41_CATALOG: " + label)
