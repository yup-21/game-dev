extends RefCounted
## Convention-based defaults for native art Resources. Explicit Inspector bindings
## always win; no version guessing, date ordering or implicit placeholders.

const IMPORT_ROOT := "res://assets/imported/"
const TEXTURE_EXTENSIONS := ["png", "webp", "svg", "jpg", "jpeg"]


static func _resolve_texture(stem: String, required: bool) -> Dictionary:
    var matches: Array[String] = []
    for ext in TEXTURE_EXTENSIONS:
        var path: String = stem + "." + str(ext)
        if ResourceLoader.exists(path, "Texture2D"):
            matches.append(path)
    if matches.size() > 1:
        return {"error": "Ambiguous imported art (multiple formats): " + stem}
    if matches.is_empty():
        return {"error": "Missing required imported art: " + stem + ".{png,webp,svg,jpg,jpeg}"} if required else {"error": "", "texture": null}
    var texture: Texture2D = ResourceLoader.load(matches[0], "Texture2D") as Texture2D
    if texture == null:
        return {"error": "Invalid imported texture: " + matches[0]}
    return {"error": "", "texture": texture}


static func _bind(owner: Resource, property_name: String, stem: String,
        required: bool = false) -> String:
    if owner.get(property_name) != null:
        return ""
    var result: Dictionary = _resolve_texture(stem, required)
    var problem: String = str(result.get("error", ""))
    if not problem.is_empty():
        return problem
    if result.get("texture") != null:
        owner.set(property_name, result["texture"])
    return ""


static func _layers(scene_art: WuxiaSceneArtProfile, scene_id: String) -> String:
    if scene_art == null:
        return ""
    var root: String = IMPORT_ROOT + "scenes/" + scene_id + "/"
    for layer in ["background", "ground", "foreground", "weather", "story_preview"]:
        var required: bool = layer in ["background", "ground"]
        var problem: String = _bind(scene_art, layer, root + layer, required)
        if not problem.is_empty():
            return problem
    return ""


## Called once when importing ContentManifest, before to_record() and validation.
## This only fills null Resource slots; manual Texture2D fields remain authoritative.
static func apply(definition: Resource) -> String:
    if definition is WuxiaCharacterDefinition:
        var root: String = IMPORT_ROOT + "characters/" + definition.content_id + "/"
        var problem: String = _bind(definition, "portrait", root + "portraits/portrait",
                definition.battle_actor_id >= 0)
        if not problem.is_empty():
            return problem
        problem = _bind(definition, "sprite_sheet", root + "sprites/atlas")
        if not problem.is_empty():
            return problem
        problem = _bind(definition, "static_pose", root + "story-poses/default")
        if not problem.is_empty():
            return problem
        if definition.animation_profile != null and definition.animation_profile.native_frames == null:
            problem = _bind(definition.animation_profile, "atlas", root + "sprites/atlas", true)
            if not problem.is_empty():
                return problem
    elif definition is WuxiaMapDefinition or definition is WuxiaGridMapDefinition:
        var root: String = IMPORT_ROOT + "scenes/" + definition.content_id + "/"
        var problem: String = _bind(definition, "background", root + "background", true)
        if not problem.is_empty():
            return problem
        return _layers(definition.scene_art, definition.content_id)
    elif definition is WuxiaChapterDefinition and definition.scene is WuxiaChapterSceneDefinition:
        var root: String = IMPORT_ROOT + "scenes/" + definition.content_id + "/"
        var problem: String = _bind(definition.scene, "background", root + "background", true)
        if not problem.is_empty():
            return problem
        return _layers(definition.scene.scene_art, definition.content_id)
    elif definition is WuxiaAssetDefinition and definition.resource == null:
        var stem: String = ""
        if definition.asset_kind == "vfx" and not definition.owner_character_id.is_empty():
            stem = IMPORT_ROOT + "vfx/" + definition.owner_character_id + "/" + definition.content_id + "/atlas"
        elif definition.asset_kind == "ui_atlas":
            stem = IMPORT_ROOT + "ui/" + definition.content_id + "/atlas"
        if not stem.is_empty():
            var result: Dictionary = _resolve_texture(stem, true)
            if not str(result.get("error", "")).is_empty():
                return str(result["error"])
            definition.resource = result["texture"]
    return ""
