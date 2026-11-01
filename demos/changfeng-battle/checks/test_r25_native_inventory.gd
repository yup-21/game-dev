extends SceneTree
## Check stable item and status behavior rather than comparing two views of one manifest.
const Items = preload("res://scripts/item_catalog.gd")
const Statuses = preload("res://scripts/status_catalog.gd")
const Affixes = preload("res://scripts/equipment_affix_catalog.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("R25_INVENTORY: " + label)

func _run() -> void:
    var items = Items.new()
    var statuses = Statuses.new()
    var affixes = Affixes.new()
    check(items.load_error.is_empty() and statuses.load_error.is_empty()
        and affixes.load_error.is_empty(), "native item, buff and affix catalogs validate")
    check(items.definitions.size() == 6 and statuses.definitions.size() == 3
        and affixes.definitions.size() == 3, "authored content counts")

    var sword: Dictionary = items.get_item("river_sword")
    check(sword.get("kind") == "equipment" and sword.get("slot") == "weapon"
        and sword.get("modifiers", []) == [{"stat":"attack", "op":"flat", "value":2}]
        and sword.get("affix_pool", []) == ["keen_edge", "quickstep"]
        and sword.get("max_affixes") == 1,
        "river sword equipment and affix rules")
    var medicine: Dictionary = items.get_item("healing_powder")
    check(medicine.get("stack_limit") == 20
        and medicine.get("effects", []) == [{"type":"heal_hp", "amount":5}],
        "medicine restores five HP")
    var pill: Dictionary = items.get_item("breath_pill")
    check(pill.get("stack_limit") == 20
        and pill.get("effects", []) == [{"type":"gain_qi", "amount":2}],
        "breath pill restores two Qi")

    var iron_body: Dictionary = statuses.get_buff("iron_body")
    check(iron_body.get("stack_limit") == 2
        and iron_body.get("expiry", {}) == {"kind":"global_ticks_after_apply", "duration":300}
        and iron_body.get("modifiers", []) == [{"stat":"CON", "op":"flat", "value":2}],
        "iron body stacking, duration and CON bonus")
    var edge: Dictionary = affixes.get_affix("keen_edge")
    check(edge.get("allowed_slots", []) == ["weapon"]
        and edge.get("modifiers", []) == [{"stat":"attack", "op":"flat", "value":2}],
        "keen edge weapon affix bonus")
    var guard: Dictionary = affixes.get_affix("iron_guard")
    check(guard.get("allowed_slots", []) == ["armor", "accessory"]
        and guard.get("modifiers", []) == [{"stat":"defense", "op":"percent_bp", "value":1000}],
        "iron guard defense affix bonus")
    print("R25_NATIVE_INVENTORY_PASS failures=", failures)
    quit(1 if failures else 0)
