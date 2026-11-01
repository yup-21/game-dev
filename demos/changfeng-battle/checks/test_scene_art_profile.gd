extends SceneTree
## Layered art must match the exact map viewport; geometry stays in MapBake.

const SceneProfile = preload("res://scripts/content/scene_art_profile.gd")

func _initialize() -> void:
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
    print("SCENE_ART_PROFILE_OK")
    quit(0)
