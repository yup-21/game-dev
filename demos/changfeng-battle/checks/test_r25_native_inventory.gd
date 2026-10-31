extends SceneTree
## Validate typed equipment, consumables, buffs and affix contracts.
const Native = preload("res://scripts/content/content_registry.gd")
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
    var native = Native.new()
    var items = Items.new()
    var statuses = Statuses.new()
    var affixes = Affixes.new()
    check(native.load_error.is_empty() and items.load_error.is_empty()
        and statuses.load_error.is_empty() and affixes.load_error.is_empty(),
        "native manifests and gameplay catalog validation")
    check(items.definitions.size() == 6 and statuses.definitions.size() == 3
        and affixes.definitions.size() == 3, "all resource entries are registered")
    for id in native.entries("item"):
        check(items.get_item(str(id)) == native.entries("item")[id], "item records: " + str(id))
    for id in native.entries("buff"):
        check(statuses.get_buff(str(id)) == native.entries("buff")[id], "buff records: " + str(id))
    for id in native.entries("affix"):
        check(affixes.get_affix(str(id)) == native.entries("affix")[id], "affix records: " + str(id))
    check(items.get_item("river_sword").get("affix_pool", []).has("keen_edge")
        and affixes.get_affix("iron_guard").get("allowed_slots", []).has("armor"),
        "cross-Resource equipment rules resolve")
    print("R25_NATIVE_INVENTORY_PASS failures=", failures)
    quit(1 if failures else 0)
