extends SceneTree
## Old CC0 sample pack is archived; verify only its still-registered VFX tile.
const ArtRegistry = preload("res://scripts/asset_registry.gd")
var errors := 0

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var assets = ArtRegistry.new()
    if not assets.load_error.is_empty():
        errors += 1
        push_error(assets.load_error)
    var texture: Texture2D = assets.texture("r22_vfx_probe")
    if texture == null or texture.get_width() < 1 or texture.get_height() < 1:
        errors += 1
        push_error("ASSET_IMPORT_FAILED registered CC0 VFX")
    for scene in ["res://opening.tscn", "res://battle_hd2d.tscn"]:
        if load(scene) == null:
            errors += 1
            push_error("SCENE_IMPORT_FAILED " + scene)
    print("KENNEY_CC0_ASSETS: native registered tile loaded, failures=", errors)
    quit(1 if errors > 0 else 0)
