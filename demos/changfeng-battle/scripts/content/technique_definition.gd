@tool
class_name WuxiaTechniqueDefinition
extends WuxiaContentDefinition
## Independent capability/stage graph; never injected as a physical card.

@export var entry_node: String = ""
@export var nodes: Array[Resource] = []
@export var trigger: Dictionary = {}

func content_kind() -> String:
    return "technique"

func to_record() -> Dictionary:
    var converted: Array = []
    for node in nodes:
        if not node is WuxiaTechniqueNodeDefinition:
            return {}
        var record: Dictionary = node.to_record()
        if record.is_empty():
            return {}
        converted.append(record)
    return {
        "schema_version": schema_version, "id": content_id,
        "entry": entry_node, "nodes": converted,
        "trigger": trigger.duplicate(true)
    }
