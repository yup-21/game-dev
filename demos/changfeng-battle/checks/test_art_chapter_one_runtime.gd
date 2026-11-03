extends SceneTree
## Review-only runtime integration of chapter one cast and optional layered story.
const Art = preload("res://scripts/hd2d_art_catalog.gd")
const Assets = preload("res://scripts/asset_registry.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("ART_CHAPTER_ONE: " + message)
    quit(1)

func _run() -> void:
    var assets = Assets.new()
    if not assets.load_error.is_empty():
        _fail("native registry failed: " + assets.load_error)
        return
    for id in ["gu_qingshuang", "green_wanderer", "black_blade", "night_assassin"]:
        var role: WuxiaCharacterDefinition = load("res://data/native/characters/%s.tres" % id)
        var profile: WuxiaActorAnimationProfile = Art.animation_profile_for_character(id)
        if role == null or profile == null or not profile.valid_profile():
            _fail("missing nine-action native animation: " + id)
            return
        if role.animation_profile != profile or role.sprite_sheet != profile.atlas:
            _fail("character card still reads old atlas: " + id)
            return
        if profile.columns != 6 or profile.rows != 4 or profile.atlas.get_size() != Vector2(1536,1024):
            _fail("normalized atlas dimensions: " + id)
            return
        if role.portrait == null or role.portrait.get_size() != Vector2(1024,1536):
            _fail("fullbody portrait binding: " + id)
            return
        if Art.portrait_for_character(id) != role.portrait:
            _fail("asset registry still overrides new portrait: " + id)
            return
        if not role.sprite_sheet.resource_path.contains("/assets/imported/in-use/characters/"):
            _fail("role still reads legacy art: " + id)
            return
        for action in WuxiaActorAnimationProfile.REQUIRED_ACTIONS:
            if profile.clip_for(action) == null:
                _fail("missing clip " + action + " for " + id)
                return

    var elder: WuxiaCharacterDefinition = load("res://data/native/characters/escort_elder.tres")
    if elder == null or elder.portrait == null or elder.static_pose == null:
        _fail("wounded escort elder art is absent")
        return
    if Art.portrait_for_character("escort_elder") != elder.portrait:
        _fail("elder portrait registry still points to old art")
        return

    var art: WuxiaSceneArtProfile = load("res://data/native/scene_art/ruined_temple.tres")
    if art == null or not art.valid_for(Vector2i(1600,1000)):
        _fail("independent story scene layers did not import")
        return
    var chapter: WuxiaChapterDefinition = load("res://data/native/chapters/rain_escort_prologue.tres")
    var native_scene: WuxiaChapterSceneDefinition = chapter.scene if chapter != null else null
    if native_scene == null or native_scene.scene_art != art:
        _fail("first-act chapter did not select the layered scene Resource")
        return
    var record: Dictionary = native_scene.to_record()
    if record.is_empty() or str(record.get("scene_art", "")) != art.resource_path:
        _fail("chapter record did not preserve the native scene art Resource path")
        return

    var opening: Node = load("res://opening.tscn").instantiate()
    root.add_child(opening)
    await process_frame
    opening.call("_enter_new_game")
    await process_frame
    for name in ["FirstActPaintedBackground", "GroundArt",
                 "ForegroundOcclusionClip", "WeatherOverlayClip"]:
        if opening.get_node_or_null(name) == null:
            _fail("opening scene does not contain new layered node: " + name)
            return
    var scene_background: TextureRect = opening.get("temple_picture") as TextureRect
    if scene_background == null or scene_background.texture != art.background:
        _fail("opening still draws old full scene as the active background")
        return
    var scene_story = opening.get("story")
    scene_story.begin()
    scene_story.skip_cinematic()
    await process_frame
    if not opening.get_node("ForegroundOcclusionClip").visible:
        _fail("foreground should occlude actors in exploration")
        return
    opening.call("set_story_weather_enabled", false)
    if opening.get_node("WeatherOverlayClip").visible:
        _fail("story weather not independently disableable")
        return
    opening.queue_free()
    await process_frame
    print("ART_CHAPTER_ONE_RUNTIME_OK: 4 actors, elder, native 4-layer temple, live story")
    quit(0)
