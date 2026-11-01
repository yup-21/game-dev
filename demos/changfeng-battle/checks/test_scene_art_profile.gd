extends SceneTree
## Layered art must match the exact map viewport; geometry stays in MapBake.

const SceneProfile = preload("res://scripts/content/scene_art_profile.gd")

func _initialize() -> void:
    var template: WuxiaSceneArtProfile = load("res://data/templates/scene_art_profile.tres") as WuxiaSceneArtProfile
    if template == null or template.reference_size != Vector2i(1600, 1000):
        push_error("Layered scene authoring template is missing")
        quit(1)
        return
    var size := Vector2i(12, 8)
    var painting := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
    painting.fill(Color(0.4, 0.3, 0.2, 1.0))
    var texture := ImageTexture.create_from_image(painting)
    var profile = SceneProfile.new()
    profile.reference_size = size
    profile.background = texture
    profile.ground = texture
    if not profile.valid_for(size):
        push_error("Valid, aligned scene layers were rejected")
        quit(1)
        return
    if profile.valid_for(Vector2i(16, 9)):
        push_error("Misaligned map viewport was accepted")
        quit(1)
        return
    profile.ground = null
    if profile.valid_for(size):
        push_error("Missing walkable ground artwork was accepted")
        quit(1)
        return
    var chapter := load("res://data/native/chapters/rain_escort_prologue.tres") as WuxiaChapterDefinition
    if chapter == null or not chapter.scene is WuxiaChapterSceneDefinition:
        push_error("Chapter scene Resource missing")
        quit(1)
        return
    var chapter_scene := chapter.scene as WuxiaChapterSceneDefinition
    if chapter_scene.scene_art != null or chapter.to_record().is_empty():
        push_error("Legacy chapter fallback was broken")
        quit(1)
        return
    chapter_scene.scene_art = profile
    if not chapter.to_record().is_empty():
        push_error("An invalid chapter art profile bypassed validation")
        quit(1)
        return
    chapter_scene.scene_art = null
    if chapter.to_record().is_empty():
        push_error("Legacy chapter failed to recover after invalid profile")
        quit(1)
        return
    print("SCENE_ART_PROFILE_OK")
    quit(0)
