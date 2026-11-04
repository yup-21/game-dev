extends SceneTree
## Convention defaults are exact, manual bindings win, and missing art is fatal.
const Binder = preload("res://scripts/content/art_resource_binding.gd")
const Native = preload("res://scripts/content/content_registry.gd")

var failures := 0

func _initialize() -> void:
    call_deferred("_run")


func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        printerr("ART_RESOURCE_BINDING_FAIL: " + message)


func _run() -> void:
    var hero := WuxiaCharacterDefinition.new()
    hero.content_id = "shen_changfeng"
    hero.battle_actor_id = 0
    check(Binder.apply(hero).is_empty(), "canonical character textures must load")
    check(hero.portrait != null and hero.portrait.resource_path == \
            "res://assets/imported/characters/shen_changfeng/portraits/portrait.png",
            "missing portrait resolves by character identity and canonical basename")
    check(hero.sprite_sheet != null and hero.sprite_sheet.resource_path == \
            "res://assets/imported/characters/shen_changfeng/sprites/atlas.png",
            "missing sprite atlas resolves by exact path")
    var chosen := load("res://assets/imported/characters/shen_changfeng/portraits/portrait_alt.png") as Texture2D
    hero.portrait = chosen
    check(Binder.apply(hero).is_empty() and hero.portrait == chosen,
            "manual alternate portrait must not be replaced by canonical default")

    var missing := WuxiaCharacterDefinition.new()
    missing.content_id = "test_missing_actor_art"
    missing.battle_actor_id = 2
    var error := Binder.apply(missing)
    check(error.contains("Missing required imported art") and error.contains("test_missing_actor_art"),
            "missing required portrait reports precise expected location")

    var map := WuxiaMapDefinition.new()
    map.content_id = "rainy_bridge"
    map.scene_art = WuxiaSceneArtProfile.new()
    check(Binder.apply(map).is_empty(), "default layered map resolves")
    check(map.background != null and map.background.resource_path == \
            "res://assets/imported/scenes/rainy_bridge/background.png",
            "map background canonical path")
    check(map.scene_art.ground != null and map.scene_art.ground.resource_path == \
            "res://assets/imported/scenes/rainy_bridge/ground.png",
            "scene ground canonical path")
    check(map.scene_art.story_preview != null and \
            map.scene_art.story_preview.resource_path == \
            "res://assets/imported/scenes/rainy_bridge/story_preview.png",
            "optional scene story preview canonical path")
    check(map.scene_art.valid_for(Vector2i(1600, 1000)),
            "automatically bound scene respects layer dimension contract")

    var vfx := WuxiaAssetDefinition.new()
    vfx.content_id = "martial-forms"
    vfx.asset_kind = "vfx"
    vfx.owner_character_id = "shen_changfeng"
    check(Binder.apply(vfx).is_empty() and vfx.resource != null and \
            vfx.resource.resource_path == \
            "res://assets/imported/vfx/shen_changfeng/martial-forms/atlas.svg",
            "VFX owner + skill ID selects exact atlas")
    var manual_vfx := load("res://assets/imported/vfx/shared/tile_0082.png") as Texture2D
    vfx.resource = manual_vfx
    check(Binder.apply(vfx).is_empty() and vfx.resource == manual_vfx,
            "manually chosen VFX overrides naming convention")

    var native := Native.new()
    check(native.load_error.is_empty(), "complete native registry still validates: " + native.load_error)
    if failures > 0:
        quit(1)
        return
    print("ART_RESOURCE_BINDING_OK")
    quit(0)
