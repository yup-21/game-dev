@tool
class_name WuxiaDialogueChoiceDefinition
extends Resource
@export var text: String = ""
@export var next_node: String = ""
@export var events: Array[Resource] = []
@export var requires: Array[Resource] = []

func to_record() -> Dictionary:
    if text.is_empty() or next_node.is_empty():
        return {}
    var result: Dictionary = {"text":text,"next":next_node}
    var normalized_events: Array = []
    for event in events:
        if not event is WuxiaStoryEventDefinition: return {}
        var entry: Dictionary = event.to_record()
        if entry.is_empty(): return {}
        normalized_events.append(entry)
    var requirements: Array = []
    for requirement in requires:
        if not requirement is WuxiaFlagRequirementDefinition: return {}
        var gate: Dictionary = requirement.to_record()
        if gate.is_empty(): return {}
        requirements.append(gate)
    result["events"] = normalized_events
    result["requires"] = requirements
    return result
