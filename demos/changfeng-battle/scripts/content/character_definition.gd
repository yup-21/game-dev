@tool
class_name WuxiaCharacterDefinition
extends WuxiaContentDefinition
## Native character card; referenced textures are tracked by Godot's importer.

@export_group("Identity")
@export var display_name: String = ""
@export var title: String = ""
@export var role: String = ""
@export var faction: String = ""
@export var weapon: String = ""
@export var personality: String = ""
@export_multiline var biography: String = ""
@export var team_hint: String = "ally"
@export var battle_actor_id: int = -1

@export_group("Battle")
@export var school_id: String = ""
@export var learned_schools: Array[String] = []
@export var attributes: Dictionary = {"STR": 10, "AGI": 10, "CON": 10, "MND": 10}
@export var passives: Dictionary = {"insight": 0, "conceal": 0}
@export var techniques: Dictionary = {}
@export_group("Starting Loadout")
@export var starting_items: Array[Resource] = []

@export_group("Presentation")
@export var portrait: Texture2D
@export var sprite_sheet: Texture2D
@export var portrait_quality: String = "approved"
@export var sheet_quality: String = "approved"
@export var battle_scene: PackedScene

func content_kind() -> String:
    return "character"

func to_record() -> Dictionary:
    # Adapt to existing CharacterRegistry consumers without leaking mutable Resources.
    # Presentation resources and starting equipment are authored, never runtime state.
    var record: Dictionary = {
        "schema_version": schema_version,
        "id": content_id,
        "battle_actor_id": battle_actor_id,
        "name": display_name,
        "title": title,
        "role": role,
        "faction": faction,
        "weapon": weapon,
        "personality": personality,
        "biography": biography,
        "team_hint": team_hint,
        "school_id": school_id,
        "learned_schools": learned_schools.duplicate(),
        "attributes": attributes.duplicate(true),
        "passives": passives.duplicate(true),
        "techniques": techniques.duplicate(true),
        "art": {
            "portrait": portrait.resource_path if portrait != null else "",
            "sprite_sheet": sprite_sheet.resource_path if sprite_sheet != null else "",
            "portrait_quality": portrait_quality,
            "sheet_quality": sheet_quality
        }
    }
    if not starting_items.is_empty():
        var loadout: Array = []
        for entry in starting_items:
            loadout.append(entry.to_record() if entry is WuxiaStartingItemDefinition else {})
        record["starting_loadout"] = loadout
    if battle_scene != null:
        record["presentation"] = {"battle_scene": battle_scene.resource_path}
    return record
