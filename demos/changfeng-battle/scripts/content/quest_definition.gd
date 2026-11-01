@tool
class_name WuxiaQuestDefinition
extends WuxiaContentDefinition
@export var title: String = ""
@export_multiline var description: String = ""
@export var requirements: Array[Resource] = []
@export var objectives: Array[Resource] = []

func content_kind() -> String:
    return "quest"

func to_record() -> Dictionary:
    var gates: Array = []
    for req in requirements:
        if not req is WuxiaFlagRequirementDefinition: return {}
        var gate: Dictionary = req.to_record()
        if gate.is_empty(): return {}
        gates.append(gate)
    var goals: Array = []
    var seen: Dictionary = {}
    for objective in objectives:
        if not objective is WuxiaQuestObjectiveDefinition: return {}
        var entry: Dictionary = objective.to_record()
        if entry.is_empty() or seen.has(str(entry.id)): return {}
        seen[str(entry.id)] = true
        goals.append(entry)
    return {"schema_version":schema_version,"id":content_id,
        "title":title,"description":description,
        "requirements":gates,"objectives":goals}
