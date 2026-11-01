@tool
class_name WuxiaStoryDefinition
extends WuxiaContentDefinition
## Standalone cinematic + dialogue graph, referenced by chapter Resource.
@export var title: String = ""
@export var subtitle: String = ""
@export var entry_node: String = ""
@export var cinematic_beats: Array[Resource] = []
@export var dialogue_nodes: Array[Resource] = []
@export var return_to_explore: bool = false
@export var completion_requirements: Array[Resource] = []

func content_kind() -> String:
    return "story"

func to_record() -> Dictionary:
    var beats: Array = []
    for beat in cinematic_beats:
        if not beat is WuxiaStoryBeatDefinition: return {}
        beats.append(beat.to_record())
    var nodes: Array = []
    for node in dialogue_nodes:
        if not node is WuxiaDialogueNodeDefinition: return {}
        var entry: Dictionary = node.to_record()
        if entry.is_empty(): return {}
        nodes.append(entry)
    var requirements: Array = []
    for item in completion_requirements:
        if not item is WuxiaFlagRequirementDefinition: return {}
        var entry: Dictionary = item.to_record()
        if entry.is_empty(): return {}
        requirements.append(entry)
    if return_to_explore and requirements.is_empty(): return {}
    return {"schema_version":schema_version,"id":content_id,
        "title":title,"subtitle":subtitle,"entry_node":entry_node,
        "resource_path":resource_path,
        "cinematic":beats,"dialogues":nodes,
        "return_to_explore":return_to_explore,
        "completion_requirements":requirements}
