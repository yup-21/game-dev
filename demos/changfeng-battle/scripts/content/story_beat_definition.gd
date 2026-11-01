@tool
class_name WuxiaStoryBeatDefinition
extends Resource
@export var caption: String = ""
@export_multiline var text: String = ""
@export_range(0.5, 60.0, 0.1) var duration: float = 2.5

func to_record() -> Dictionary:
    return {"caption":caption,"text":text,"duration":duration}
