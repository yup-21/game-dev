@tool
class_name WuxiaChapterSceneDefinition
extends Resource
## Rendering hints and trigger placements are data; the Node2D template stays shared.
@export var background: Texture2D
@export var scene_art: WuxiaSceneArtProfile
## Real 2D painting/world extent, not the fixed game UI window.
## 1600x2400 supports a north/south scrolling street without scaling actors.
@export var world_size: Vector2i = Vector2i(1600, 1000)
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
            not primary_npc is WuxiaChapterNpcDefinition or \
            world_size.x < 1600 or world_size.y < 1000 or \
            world_size.x > 8192 or world_size.y > 8192:
        return {}
    if world_size != Vector2i(1600, 1000) and \
            Vector2i(background.get_size()) != world_size:
        return {}
    if scene_art != null and (scene_art.resource_path.is_empty() or \
            not scene_art.valid_for(world_size)):
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
    var record: Dictionary = {"background":background.resource_path,
        "world_size":[world_size.x,world_size.y],
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
        record["scene_art"] = scene_art.resource_path
    return record
