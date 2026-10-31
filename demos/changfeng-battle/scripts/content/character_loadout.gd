extends RefCounted
## Validate and stage starting inventory atomically; never seed an active battle.
const Inventory = preload("res://scripts/inventory_runtime.gd")
const Modifiers = preload("res://scripts/stat_modifier_system.gd")

static func apply(entries: Variant, inventory) -> bool:
    if not entries is Array:
        return false
    var staged = Inventory.new(inventory.catalog)
    if not staged.restore(inventory.snapshot()):
        return false
    var equipped_slots: Dictionary = {}
    for entry in entries:
        if not entry is Dictionary:
            return false
        for key in entry:
            if key not in ["item_id", "count", "equip", "affixes"]:
                return false
        var id: Variant = entry.get("item_id")
        var count: Variant = entry.get("count")
        var should_equip: Variant = entry.get("equip", false)
        var affixes: Variant = entry.get("affixes", [])
        if not id is String or str(id).is_empty() or not Modifiers._whole(count, 1, 99):
            return false
        if not should_equip is bool or not affixes is Array:
            return false
        var item: Dictionary = staged.catalog.get_item(str(id))
        if item.is_empty():
            return false
        if item.kind == "consumable":
            if should_equip or not affixes.is_empty():
                return false
        else:
            # Each equipment entry is a single, stable UID, possibly equipped.
            if count != 1 or (should_equip and equipped_slots.has(str(item.slot))):
                return false
            if should_equip:
                equipped_slots[str(item.slot)] = true
        if not staged.add(str(id), int(count)):
            return false
        if item.kind == "equipment":
            var uid: String = str(staged.last_added_uids[0])
            if not affixes.is_empty() and not staged.set_affixes(uid, affixes):
                return false
            if should_equip and not staged.equip(uid):
                return false
    # Any failure above leaves the original inventory unchanged.
    return inventory.restore(staged.snapshot())
