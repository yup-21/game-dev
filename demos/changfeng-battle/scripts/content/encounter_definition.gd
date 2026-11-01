@tool
class_name WuxiaEncounterDefinition
extends WuxiaContentDefinition
@export var seed: int = 2026
@export var title: String = ""
@export var map_id: String = ""
@export var combatants: Array[Resource] = []
@export var map_resource: Resource

func content_kind() -> String:
    return "encounter"

func to_record() -> Dictionary:
    var actors: Array = []
    var seen: Dictionary = {}
    for combatant in combatants:
        if not combatant is WuxiaEncounterCombatantDefinition: return {}
        var entry: Dictionary = combatant.to_record()
        if entry.is_empty() or seen.has(int(entry.id)): return {}
        seen[int(entry.id)] = true
        actors.append(entry)
    var result: Dictionary = {"schema_version":schema_version,"id":content_id,
        "seed":seed,"schools":{},"combatants":actors}
    if not title.is_empty(): result["title"] = title
    if not map_id.is_empty():
        if not map_id.is_valid_identifier() or map_resource != null: return {}
        result["map_id"] = map_id
    if map_resource != null:
        if not map_resource.resource_path.begins_with("res://data/maps/"):
            return {}
        result["map_definition_path"] = map_resource.resource_path
    return result
