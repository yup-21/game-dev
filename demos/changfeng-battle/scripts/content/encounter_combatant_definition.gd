@tool
class_name WuxiaEncounterCombatantDefinition
extends Resource
@export var actor_id: int = 0
@export var character_id: String = ""
@export var display_name: String = ""
@export_range(0, 7, 1) var team_id: int = 0
@export_enum("PLAYER", "AI") var controller: String = "AI"
@export var cell: Vector2i = Vector2i(6,4)

func to_record() -> Dictionary:
    if actor_id < 0 or actor_id > 1023 or character_id.is_empty() or display_name.is_empty():
        return {}
    return {"id":actor_id,"character_id":character_id,"name":display_name,
        "team_id":team_id,"controller":controller,
        "cell":[cell.x,cell.y]}
