@tool
class_name WuxiaRuleTargetDefinition
extends Resource
@export var kind: String = "self"
@export var has_min_distance: bool = false
@export var min_distance: int = 1
@export var has_max_distance: bool = false
@export var max_distance: int = 1
@export var has_line_of_sight: bool = false
@export var line_of_sight: bool = false
@export var distance: String = ""
@export var source_selector: String = ""

func to_record() -> Dictionary:
    if kind.is_empty(): return {}
    var d: Dictionary = {"kind": kind}
    if has_min_distance: d["min_distance"] = min_distance
    if has_max_distance: d["max_distance"] = max_distance
    if has_line_of_sight: d["line_of_sight"] = line_of_sight
    if not distance.is_empty(): d["distance"] = distance
    if not source_selector.is_empty(): d["from"] = source_selector
    return d
