@tool
class_name WuxiaStoryEventDefinition
extends Resource
## Transactional story events, validated by StoryEventExecutor.
@export_enum("set_flag", "grant_clue", "grant_item", "set_growth", "recruit_character", "learn_school", "switch_school", "set_attribute") var event_type: String = "set_flag"
@export var flag_id: String = ""
@export var flag_value: bool = true
@export var clue_id: String = ""
@export_range(1, 99, 1) var count: int = 1
@export var character_id: String = ""
@export var item_id: String = ""
@export var growth_source: String = ""
@export var school_id: String = ""
@export_enum("STR", "AGI", "CON", "MND") var attribute_stat: String = "STR"
@export_range(1, 100, 1) var attribute_value: int = 1
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
        "recruit_character":
            if character_id.is_empty(): return {}
            return {"type":"recruit_character","character_id":character_id}
        "learn_school", "switch_school":
            if character_id.is_empty() or school_id.is_empty(): return {}
            return {"type":event_type,"character_id":character_id,"school_id":school_id}
        "set_attribute":
            if character_id.is_empty() or attribute_stat not in ["STR","AGI","CON","MND"] or attribute_value < 1 or attribute_value > 100: return {}
            return {"type":"set_attribute","character_id":character_id,
                "stat":attribute_stat,"value":attribute_value}
        "set_growth":
            if character_id.is_empty() or not growth_source.begins_with("growth:"):
                return {}
            return {"type":"set_growth","character_id":character_id,
                "source":growth_source,"modifiers":modifiers.duplicate(true)}
    return {}
