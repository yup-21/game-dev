extends RefCounted
## Creates persistent characters and resolves presentation assets by character_id.
## Does not own combat, animation timing or any scene-tree lifecycle.
const Registry = preload("res://scripts/character_registry.gd")
const Runtime = preload("res://scripts/character_runtime.gd")
const ItemCatalog = preload("res://scripts/item_catalog.gd")
const Loadout = preload("res://scripts/content/character_loadout.gd")
const Assets = preload("res://scripts/asset_registry.gd")
const Fallback = preload("res://scripts/fallback_assets.gd")
var registry
var items
var assets = Assets.new()
var load_error: String = ""

func _init(source_registry = null, source_items = null) -> void:
    registry = Registry.new() if source_registry == null else source_registry
    items = ItemCatalog.new() if source_items == null else source_items
    if not registry.load_error.is_empty():
        load_error = registry.load_error
    elif not items.load_error.is_empty():
        load_error = items.load_error
    elif not assets.load_error.is_empty():
        load_error = assets.load_error

func create_runtime(character_id: String):
    if not load_error.is_empty():
        return null
    var profile: Dictionary = registry.get_profile(character_id)
    if profile.is_empty():
        load_error = "Unknown character: " + character_id
        return null
    var character = Runtime.new(character_id, registry, items)
    if not character.load_error.is_empty() or not Loadout.apply(profile.get("starting_loadout", []), character.inventory):
        load_error = "Invalid starting loadout: " + character_id
        return null
    return character

func presentation_assets(character_id: String) -> Dictionary:
    var profile: Dictionary = registry.get_profile(character_id)
    if profile.is_empty():
        return {}
    var output: Dictionary = {}
    var art: Dictionary = profile.get("art", {})
    for key in ["portrait", "sprite_sheet"]:
        var kind: String = "pose_sheet" if key == "sprite_sheet" else key
        var bound: Texture2D = assets.texture_for_character(character_id,kind)
        var path: String = str(art.get(key, ""))
        var authored: Texture2D = bound
        if authored == null and not path.is_empty() and ResourceLoader.exists(path, "Texture2D"):
            authored = ResourceLoader.load(path, "Texture2D") as Texture2D
        output[key] = authored if authored != null else (Fallback.ACTOR_SHEET if kind == "pose_sheet" else Fallback.PORTRAIT)
    var scene_path: String = str(profile.get("presentation", {}).get("battle_scene", ""))
    var scene: PackedScene = assets.scene_for_character(character_id)
    output["battle_scene"] = scene if scene != null else (ResourceLoader.load(scene_path, "PackedScene") if not scene_path.is_empty() else null)
    return output

func instantiate_presentation(character_id: String) -> Node2D:
    # Optional authored actor scene; legacy actors continue using HD2DSpriteFactory.
    var scene: PackedScene = presentation_assets(character_id).get("battle_scene") as PackedScene
    if scene == null:
        return null
    var node: Node = scene.instantiate()
    if not node is Node2D:
        node.free()
        return null
    return node as Node2D
