extends RefCounted
## A validated registry of chapter content, scenes and encounter routing.
const Story = preload("res://scripts/opening_story.gd")
const ScenarioDirector = preload("res://scripts/scenario_director.gd")
const CharacterRegistry = preload("res://scripts/character_registry.gd")
const Events = preload("res://scripts/story_event_executor.gd")
const Native = preload("res://scripts/content/content_registry.gd")
var chapters: Dictionary = {}
var chapter_order: Array = []
var load_error: String = ""

func _init(manifest_path: String = Native.DEFAULT_MANIFEST) -> void:
    var director = ScenarioDirector.new()
    var characters = CharacterRegistry.new()
    if not director.load_error.is_empty() or not characters.load_error.is_empty():
        load_error = "Chapter prerequisites are invalid"
        return
    var native = Native.new(manifest_path)
    if not native.load_error.is_empty():
        load_error = native.load_error
        return
    for chapter in native.entries("chapter").values():
        var chapter_id: String = str(chapter.get("id", ""))
        if not _valid(chapter, director, characters) or chapters.has(chapter_id):
            load_error = "Invalid or duplicate native chapter: " + chapter_id
            return
        chapters[chapter_id] = chapter.duplicate(true)
        chapter_order.append(chapter_id)
    chapter_order.sort_custom(func(a, b):
        var left: int = int(chapters[a].get("order", 100))
        var right: int = int(chapters[b].get("order", 100))
        return str(a) < str(b) if left == right else left < right)
    if chapter_order.is_empty():
        load_error = "No chapters registered"
        return
    for id in chapter_order:
        var next_id: String = str(chapters[id].get("next_chapter_id", ""))
        if not next_id.is_empty() and (next_id == id or not chapters.has(next_id)):
            load_error = "Unknown or self-referencing next chapter: " + id
            return

func _point(value: Variant) -> bool:
    return value is Array and value.size() == 2 and _coordinate(value[0]) and _coordinate(value[1])

func _coordinate(value: Variant) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= 1600.0

func _valid(data: Variant, director, characters) -> bool:
    if not data is Dictionary or data.get("schema_version") != 1:
        return false
    if not data.get("id") is String or not str(data.id).is_valid_identifier():
        return false
    if not data.get("story_path") is String or not str(data.story_path).begins_with("res://data/") or ".." in str(data.story_path):
        return false
    var story = Story.new(str(data.story_path))
    if not story.load_error.is_empty() or str(story.data.get("id","")) != str(data.get("story_id",data.id)):
        return false
    if not data.get("encounter_id") is String or director.encounter(str(data.encounter_id)).is_empty():
        return false
    if not data.get("next_chapter_id","") is String or not data.get("scene") is Dictionary:
        return false
    var scene: Dictionary = data.scene
    if not scene.get("background") is String or not str(scene.background).begins_with("res://assets/") or ".." in str(scene.background) or not ResourceLoader.exists(str(scene.background)):
        return false
    if not scene.get("npc_character_id") is String or characters.get_profile(str(scene.npc_character_id)).is_empty():
        return false
    var npcs: Variant = scene.get("npcs",[])
    if not npcs is Array or npcs.size() > 16:
        return false
    var seen_npcs: Dictionary = {}
    for npc in npcs:
        if not npc is Dictionary or not npc.get("character_id") is String or \
                characters.get_profile(str(npc.character_id)).is_empty() or \
                not _point(npc.get("position")) or not npc.get("talk_label") is String:
            return false
        if seen_npcs.has(str(npc.character_id)):
            return false
        seen_npcs[str(npc.character_id)] = true
    for key in ["title","place","prompt","talk_label","complete_title","complete_text","battle_label"]:
        if not scene.get(key) is String:
            return false
    if not _point(scene.get("npc_position")) or not _point(scene.get("player_position")):
        return false
    var bounds: Variant = scene.get("player_bounds")
    if not bounds is Array or bounds.size()!=4:
        return false
    for number in bounds:
        if not _coordinate(number):
            return false
    if float(bounds[0]) >= float(bounds[2]) or float(bounds[1]) >= float(bounds[3]):
        return false
    var requirements: Variant = data.get("requirements",[])
    if not requirements is Array:
        return false
    for req in requirements:
        if not req is Dictionary or not req.get("flag") is String or not req.get("equals") is bool:
            return false
    for key in ["victory_events","defeat_events"]:
        var effects: Variant = data.get(key,[])
        if not effects is Array:
            return false
        for effect in effects:
            if not Events.valid_event(effect):
                return false
    return true

func first_chapter_id() -> String:
    return str(chapter_order[0]) if not chapter_order.is_empty() else ""

func get_chapter(id: String) -> Dictionary:
    return chapters.get(id,{}).duplicate(true)
