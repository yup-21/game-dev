extends SceneTree
## Runtime binding smoke test for the 2026-11-01 candidate art batch.
## This is a technical check; it does not grant visual or commercial approval.
const Art = preload("res://scripts/hd2d_art_catalog.gd")
const MapBake = preload("res://scripts/map_bake.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("ART_RUNTIME: " + message)
    quit(1)

func _run() -> void:
    # A stale AssetRegistry entry must never override the native character card.
    var old_id := "r22_shen_portrait"
    var old_record: Dictionary = Art._asset_registry.record(old_id)
    if old_record.is_empty():
        _fail("legacy portrait fixture missing")
        return
    Art._asset_registry.definitions[old_id]["path"] = "res://assets/characters/concepts/escort_captain_portrait.png"
    var shen_card: WuxiaCharacterDefinition = load("res://data/native/characters/shen_changfeng.tres")
    var canonical_wins: bool = Art.portrait_for_character("shen_changfeng") == shen_card.portrait
    Art._asset_registry.definitions[old_id] = old_record
    if not canonical_wins:
        _fail("historical portrait registration overrode the native character card")
        return
    for id in ["shen_changfeng", "pursuer_captain"]:
        var role: WuxiaCharacterDefinition = load("res://data/native/characters/%s.tres" % id)
        var profile: WuxiaActorAnimationProfile = Art.animation_profile_for_character(id)
        if role == null or profile == null or not profile.valid_profile():
            _fail("missing live native character/profile: " + id)
            return
        if role.animation_profile != profile or role.sprite_sheet != profile.atlas:
            _fail("character atlas is not bound to its nine-action profile: " + id)
            return
        if role.portrait == null or role.portrait.get_size() != Vector2(1024, 1536):
            _fail("fullbody portrait is not bound: " + id)
            return
        if profile.atlas.get_size() != Vector2(1536, 1024) or profile.columns != 6 or profile.rows != 4:
            _fail("normalized 24-frame atlas is not bound: " + id)
            return
        if Art.portrait_for_character(id) != role.portrait:
            _fail("native portrait registration still overrides the new character art: " + id)
            return
        for action in WuxiaActorAnimationProfile.REQUIRED_ACTIONS:
            if profile.clip_for(action) == null:
                _fail("missing runtime action %s for %s" % [action, id])
                return

    var map: WuxiaGridMapDefinition = load("res://data/maps/rainy_bridge.tres")
    var baked = MapBake.new("res://data/maps/rainy_bridge.tres")
    if map == null or map.scene_art == null or not map.scene_art.valid_for(map.viewport_size):
        _fail("four-layer bridge is not bound to native map")
        return
    if not baked.error.is_empty() or baked.scene_art != map.scene_art:
        _fail("map projection did not load the four-layer art: " + baked.error)
        return
    if map.background != map.scene_art.background or Art.scenery("rainy_bridge") != map.scene_art.background:
        _fail("story scene or map background still points to historical art")
        return
    if baked.image_scale != 1.0 or baked.image_rotation_degrees != 0.0 or baked.tiles.size() != 150:
        _fail("candidate canvas must be pixel-aligned without replacing gameplay terrain")
        return

    var battle: Node = load("res://battle_hd2d.tscn").instantiate()
    root.add_child(battle)
    await process_frame
    var painted = battle.get("illustrated_map")
    if painted == null or painted.picture.texture != map.scene_art.background:
        _fail("live battle does not render the new bridge background")
        return
    for layer_name in ["GroundArt", "ForegroundOcclusion", "WeatherOverlay"]:
        if painted.scene_root.get_node_or_null(layer_name) == null:
            _fail("live battle lacks scene layer: " + layer_name)
            return
    for pair in [[0, "shen_changfeng"], [1, "pursuer_captain"]]:
        var sprite: Sprite2D = painted.actors[pair[0]].get_node_or_null("ActionSprite")
        var profile: WuxiaActorAnimationProfile = Art.animation_profile_for_character(pair[1])
        if sprite == null or sprite.texture != profile.atlas or sprite.offset != profile.feet_offset:
            _fail("live battle sprite is not using candidate atlas: " + pair[1])
            return
    painted.set_weather_enabled(false)
    if painted.scene_root.get_node("WeatherOverlay").visible:
        _fail("weather must be independently switchable")
        return
    battle.queue_free()
    await process_frame
    print("ART_RUNTIME_INTEGRATION_OK: two live atlas profiles, two portraits, four scene layers")
    quit(0)
