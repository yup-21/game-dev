@tool
class_name WuxiaTechniqueDefinition
extends WuxiaContentDefinition
## Independent capability/stage graph; never injected as a physical card.

@export var entry_node: String = ""
@export var nodes: Array[Resource] = []
@export var trigger: Dictionary = {} # Legacy/editor fixtures only
@export var display_name: String = ""
@export var auto_equip: bool = false
@export var hold_own_actions: int = 2
@export var trigger_definition: WuxiaTechniqueTriggerDefinition

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
    var trigger_record: Dictionary = trigger.duplicate(true)
    if trigger_definition != null:
        trigger_record = trigger_definition.to_record()
        if trigger_record.is_empty(): return {}
    var result: Dictionary = {
        "schema_version": schema_version, "id": content_id,
        "entry": entry_node, "nodes": converted,
        "trigger": trigger_record
    }
    if not display_name.is_empty(): result["name"] = display_name
    if auto_equip: result["auto_equip"] = true
    if hold_own_actions != 2: result["hold_own_actions"] = hold_own_actions
    return result
