@tool
class_name WuxiaChapterSceneDefinition
extends Resource
## Rendering hints and trigger placements are data; the Node2D template stays shared.
@export var background: Texture2D
@export var scene_art: WuxiaSceneArtProfile
@export var primary_npc: Resource
@export var npcs: Array[Resource] = []
@export var player_position: Vector2 = Vector2(350,705)
@export var player_bounds: Rect2 = Rect2(155,345,1260,410)
@export var title: String = ""
@export var place: String = ""
@export var prompt: String = ""
@export var talk_label: String = ""
@export var complete_title: String = ""
@export var complete_text: String = ""
@export var battle_label: String = ""
@export var reward_label: String = ""
@export var complete_caption: String = ""
@export var complete_subtitle: String = ""

func to_record() -> Dictionary:
    if background == null or background.resource_path.is_empty() or \
            not primary_npc is WuxiaChapterNpcDefinition:
        return {}
    var first: Dictionary = primary_npc.to_record()
    if first.is_empty(): return {}
    var extras: Array = [first]
    var seen: Dictionary = {str(first.character_id):true}
    for npc in npcs:
        if not npc is WuxiaChapterNpcDefinition: return {}
        var entry: Dictionary = npc.to_record()
        if entry.is_empty() or seen.has(str(entry.character_id)): return {}
        seen[str(entry.character_id)] = true
        extras.append(entry)
    var authored: Dictionary = {"background":background.resource_path,
        "npc_character_id":first.character_id,"npc_position":first.position,
        "npcs":extras,
        "player_position":[player_position.x,player_position.y],
        "player_bounds":[player_bounds.position.x,player_bounds.position.y,
            player_bounds.end.x,player_bounds.end.y],
        "title":title,"place":place,"prompt":prompt,
        "talk_label":talk_label,"complete_title":complete_title,
        "complete_text":complete_text,"battle_label":battle_label,
        "reward_label":reward_label,"complete_caption":complete_caption,
        "complete_subtitle":complete_subtitle}
    if scene_art != null:
        if not scene_art.valid_for(Vector2i(1600, 1000)):
            return {}
        var paths: Dictionary = {}
        for name in ["background", "ground", "foreground", "weather"]:
            var layer: Texture2D = scene_art.get(name) as Texture2D
            if layer != null:
                if layer.resource_path.is_empty(): return {}
                paths[name] = layer.resource_path
        authored["scene_art"] = paths
    return authored
