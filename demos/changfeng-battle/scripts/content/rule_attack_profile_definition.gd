@tool
class_name WuxiaRuleAttackProfileDefinition
extends Resource
@export var route: String = "thrust"
@export var break_bonus: int = 0
@export var has_range: bool = false
@export var range_cells: int = 1
@export var has_base_damage: bool = false
@export var base_damage: int = 0
@export var footprint: String = ""
@export var has_target_count: bool = false
@export var target_count: int = 1

func to_record() -> Dictionary:
    var d: Dictionary = {"route":route,"break_bonus":break_bonus}
    if has_range: d["range"] = range_cells
    if has_base_damage: d["base_damage"] = base_damage
    if not footprint.is_empty(): d["footprint"] = footprint
    if has_target_count: d["target_count"] = target_count
    return d
