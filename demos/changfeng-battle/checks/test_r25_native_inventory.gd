extends SceneTree
## Canonical content comes from .tres, while legacy JSON remains a read-only parity fixture.
const Native = preload("res://scripts/content/content_registry.gd")
const Items = preload("res://scripts/item_catalog.gd")
const Statuses = preload("res://scripts/status_catalog.gd")
const Affixes = preload("res://scripts/equipment_affix_catalog.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("R25 INVENTORY FAIL: " + label)

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

func _check_legacy(kind: String, id: String, actual: Dictionary) -> void:
    var path: String = "res://data/" + kind + "/" + id + ".json"
    var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    check(source is Dictionary, "legacy fixture parses " + path)
    if not source is Dictionary: return
    var shared: Dictionary = {}
    for key in source:
        shared[key] = actual.get(key)
    check(_same(source,shared), "native Resource preserves gameplay fields " + id)

func _run() -> void:
    var native = Native.new()
    var items = Items.new()
    var statuses = Statuses.new()
    var affixes = Affixes.new()
    check(native.load_error.is_empty(), "manifest: " + native.load_error)
    check(items.load_error.is_empty() and items.definitions.size() == 6,
        "four legacy items plus two new items load natively: " + items.load_error)
    check(statuses.load_error.is_empty() and statuses.definitions.size() == 3,
        "legacy buff and new buffs load natively: " + statuses.load_error)
    check(affixes.load_error.is_empty() and affixes.definitions.size() == 3,
        "all original affixes load natively: " + affixes.load_error)
    for id in ["river_sword","padded_armor","healing_powder","breath_pill"]:
        check(native.entries("item").has(id), "native item registered " + id)
        _check_legacy("items",id,items.get_item(id))
    _check_legacy("buffs","iron_body",statuses.get_buff("iron_body"))
    for id in ["keen_edge","quickstep","iron_guard"]:
        check(native.entries("affix").has(id), "native affix registered " + id)
        _check_legacy("affixes",id,affixes.get_affix(id))
    check(items.get_item("river_sword").get("affix_pool",[]).has("keen_edge")
        and affixes.get_affix("iron_guard").get("allowed_slots",[]).has("armor"),
        "native affix references validate through ItemCatalog")
    print("R25_NATIVE_INVENTORY_PASS failures=",failures)
    quit(0 if failures == 0 else 1)
