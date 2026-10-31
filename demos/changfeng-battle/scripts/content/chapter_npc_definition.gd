@tool
class_name WuxiaChapterNpcDefinition
extends Resource
@export var character_id: String = ""
@export var position: Vector2 = Vector2(1050, 560)
@export var talk_label: String = "交谈"
@export var trigger_id: String = ""

func to_record() -> Dictionary:
    if character_id.is_empty(): return {}
    return {"character_id":character_id,
        "position":[position.x,position.y],"talk_label":talk_label,
        "trigger_id":trigger_id}
