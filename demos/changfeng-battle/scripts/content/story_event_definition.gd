@tool
class_name WuxiaStoryEventDefinition
extends Resource
## Transactional story events, validated by StoryEventExecutor.
@export_enum("set_flag", "grant_clue", "grant_item", "set_growth") var event_type: String = "set_flag"
@export var flag_id: String = ""
@export var flag_value: bool = true
@export var clue_id: String = ""
@export_range(1, 99, 1) var count: int = 1
@export var character_id: String = ""
@export var item_id: String = ""
@export var growth_source: String = ""
@export var modifiers: Array[Dictionary] = []

func to_record() -> Dictionary:
    match event_type:
        "set_flag":
            if flag_id.is_empty(): return {}
            return {"type":"set_flag","flag":flag_id,"value":flag_value}
        "grant_clue":
            if clue_id.is_empty() or count < 1 or count > 99: return {}
            return {"type":"grant_clue","id":clue_id,"count":count}
        "grant_item":
            if character_id.is_empty() or item_id.is_empty() or count < 1 or count > 99:
                return {}
            return {"type":"grant_item","character_id":character_id,"item_id":item_id,"count":count}
        "set_growth":
            if character_id.is_empty() or not growth_source.begins_with("growth:"):
                return {}
            return {"type":"set_growth","character_id":character_id,
                "source":growth_source,"modifiers":modifiers.duplicate(true)}
    return {}
