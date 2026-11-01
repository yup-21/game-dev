@tool
class_name WuxiaFlagRequirementDefinition
extends Resource
## Shared declarative gate for dialogue, chapters and quest unlocks.
@export var flag_id: String = ""
@export var equals: bool = true

func to_record() -> Dictionary:
    if flag_id.is_empty():
        return {}
    return {"flag":flag_id,"equals":equals}
