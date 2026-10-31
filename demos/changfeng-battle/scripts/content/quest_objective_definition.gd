@tool
class_name WuxiaQuestObjectiveDefinition
extends Resource
## Progress is derived from immutable session facts; no counter duplication.
@export var objective_id: String = ""
@export var label: String = ""
@export_enum("flag", "clue", "encounter") var objective_type: String = "flag"
@export var reference_id: String = ""
@export var equals: bool = true
@export_range(1, 999, 1) var required_count: int = 1

func to_record() -> Dictionary:
    if objective_id.is_empty() or reference_id.is_empty() or required_count < 1:
        return {}
    return {"id":objective_id,"label":label,"type":objective_type,
        "ref":reference_id,"equals":equals,"required":required_count}
