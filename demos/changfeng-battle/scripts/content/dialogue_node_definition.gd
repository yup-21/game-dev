@tool
class_name WuxiaDialogueNodeDefinition
extends Resource
@export var node_id: String = ""
@export var speaker: String = ""
@export_multiline var text: String = ""
@export var next_node: String = ""
@export var events: Array[Resource] = []
@export var choices: Array[Resource] = []

func to_record() -> Dictionary:
    if node_id.is_empty() or speaker.is_empty():
        return {}
    var normalized_events: Array = []
    for event in events:
        if not event is WuxiaStoryEventDefinition: return {}
        var entry: Dictionary = event.to_record()
        if entry.is_empty(): return {}
        normalized_events.append(entry)
    var normalized_choices: Array = []
    for choice in choices:
        if not choice is WuxiaDialogueChoiceDefinition: return {}
        var entry: Dictionary = choice.to_record()
        if entry.is_empty(): return {}
        normalized_choices.append(entry)
    var result: Dictionary = {"id":node_id,"speaker":speaker,"text":text,
        "next":next_node,"events":normalized_events,"choices":normalized_choices}
    return result
