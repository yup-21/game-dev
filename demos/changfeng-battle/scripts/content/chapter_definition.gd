@tool
class_name WuxiaChapterDefinition
extends WuxiaContentDefinition
## Chapter wires story, NPC triggers, encounter and battle rewards by Resource ID.
@export var story: Resource
@export var encounter_id: String = ""
@export var next_chapter_id: String = ""
@export var scene: Resource
@export var requirements: Array[Resource] = []
@export var victory_events: Array[Resource] = []
@export var defeat_events: Array[Resource] = []

func content_kind() -> String:
    return "chapter"

func _events(source: Array[Resource]) -> Array:
    var result: Array = []
    for item in source:
        if not item is WuxiaStoryEventDefinition: return []
        var entry: Dictionary = item.to_record()
        if entry.is_empty(): return []
        result.append(entry)
    return result

func to_record() -> Dictionary:
    if not story is WuxiaStoryDefinition or story.resource_path.is_empty() or \
            not scene is WuxiaChapterSceneDefinition:
        return {}
    var scene_record: Dictionary = scene.to_record()
    if scene_record.is_empty(): return {}
    var gates: Array = []
    for requirement in requirements:
        if not requirement is WuxiaFlagRequirementDefinition: return {}
        var entry: Dictionary = requirement.to_record()
        if entry.is_empty(): return {}
        gates.append(entry)
    var win: Array = _events(victory_events)
    var lose: Array = _events(defeat_events)
    if win.size() != victory_events.size() or lose.size() != defeat_events.size():
        return {}
    return {"schema_version":schema_version,"id":content_id,
        "story_path":story.resource_path,"story_id":story.content_id,
        "encounter_id":encounter_id,
        "next_chapter_id":next_chapter_id,"scene":scene_record,
        "requirements":gates,"victory_events":win,"defeat_events":lose}
