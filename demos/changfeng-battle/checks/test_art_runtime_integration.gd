extends SceneTree
## Runtime binding smoke test for the 2026-11-01 candidate art batch.
## This is a technical check; it does not grant visual or commercial approval.
const Art = preload("res://scripts/hd2d_art_catalog.gd")
const MapBake = preload("res://scripts/map_bake.gd")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")
const NativeClips = preload("res://scripts/battle_native_sprite_clips.gd")
const Timeline = preload("res://scripts/battle_action_timeline.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("ART_RUNTIME: " + message)
    quit(1)

func _run() -> void:
    # The native card must beat an explicitly stale historical portrait.
    var old_id := "r22_shen_portrait"
    var old_record: Dictionary = Art._asset_registry.record(old_id)
    if old_record.is_empty():
        _fail("legacy portrait fixture missing")
        return
    var stale_record: Dictionary = old_record.duplicate(true)
    stale_record["path"] = "res://assets/imported/characters/escort_elder/portraits/portrait.png"
    Art._asset_registry.definitions[old_id] = stale_record
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
            _fail("native character portrait was not used: " + id)
            return
        # Simulate an out-of-date AssetRegistry card left behind by a prior import.
        var record: Dictionary = Art._asset_registry.record_for_character(id, "portrait")
        if not record.is_empty():
            var asset_id: String = str(record["id"])
            var stale: Dictionary = record.duplicate(true)
            stale["path"] = "res://assets/imported/placeholders/portraits/default.svg"
            Art._asset_registry.definitions[asset_id] = stale
            if Art.portrait_for_character(id) != role.portrait:
                _fail("legacy asset card masked the imported portrait: " + id)
                return
            Art._asset_registry.definitions[asset_id] = record
        for action in WuxiaActorAnimationProfile.REQUIRED_ACTIONS:
            if profile.clip_for(action) == null:
                _fail("missing runtime action %s for %s" % [action, id])
                return

    # Native 0 is a front-view portrait pose; 1 is the battle side-view.
    # Idle must keep the same side-facing silhouette throughout playback.
    for id in ["shen_changfeng", "gu_qingshuang", "green_wanderer",
            "black_blade", "night_assassin", "pursuer_captain"]:
        var pose: WuxiaActorAnimationProfile = Art.animation_profile_for_character(id)
        if pose == null or pose.clip_for("idle") == null or pose.clip_for("idle").frames != PackedInt32Array([1]):
            _fail("standing animation still alternates authored viewpoints: " + id)
            return
        var sprite := Sprite2D.new()
        sprite.texture = pose.atlas
        sprite.hframes = pose.columns
        sprite.vframes = pose.rows
        var fitted: bool = VisualScale.fit(sprite, pose.actor_scale,
            VisualScale.TARGET_HEIGHT, pose.feet_adjust, 1)
        if not fitted:
            _fail("unable to find opaque idle silhouette for " + id)
            return
        var ink: Rect2i = VisualScale._opaque_bounds(sprite.texture,sprite.hframes,sprite.vframes, 1)
        var frame_h: float = float(sprite.texture.get_height()) / float(sprite.vframes)
        var visible_foot: float = (float(ink.end.y) - frame_h*0.5
            + sprite.offset.y) * sprite.scale.y
        if absf(visible_foot - pose.feet_adjust.y) > 1.1:
            _fail("native actor feet do not coincide with node origin: " + id)
            return
        root.add_child(sprite)
        var player: AnimationPlayer = NativeClips.attach(sprite,Timeline.new(),pose)
        player.advance(1.25)
        var native: AnimatedSprite2D = sprite.get_node_or_null("NativeFrames")
        if native == null or native.sprite_frames != pose.native_frames or \
                native.animation != "idle" or native.frame != 0 or absf(sprite.rotation) > 0.001:
            _fail("idle reintroduces a turn/sway: " + id)
            return
        sprite.queue_free()

    var map: WuxiaMapDefinition = load("res://data/maps/rainy_bridge.tres")
    var baked = MapBake.new("res://data/maps/rainy_bridge.tres")
    if map == null or map.scene_art == null or not map.scene_art.valid_for(map.viewport_size):
        _fail("four-layer bridge is not bound to native map")
        return
    if map.background != map.scene_art.background or map.scene_art.story_preview == null:
        _fail("native background or story preview still points at old artwork")
        return
    var old_scenery: Dictionary = Art._asset_registry.record("r27_scenery_rainy_bridge")
    if not old_scenery.is_empty():
        var stale_scenery: Dictionary = old_scenery.duplicate(true)
        stale_scenery["path"] = "res://assets/imported/placeholders/scenes/default.svg"
        Art._asset_registry.definitions["r27_scenery_rainy_bridge"] = stale_scenery
        if Art.scenery("rainy_bridge") != map.scene_art.story_preview:
            _fail("legacy scene registration masked imported story artwork")
            return
        Art._asset_registry.definitions["r27_scenery_rainy_bridge"] = old_scenery
    if not baked.error.is_empty() or baked.scene_art != map.scene_art:
        _fail("map projection did not load the four-layer art: " + baked.error)
        return
    if not baked.polygon_mode or baked.walkable_outline.is_empty() or baked.image_scale != 1.0 or baked.image_rotation_degrees != 0.0 or baked.tiles.size() != 150:
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
        if painted.scene_root.get_node_or_null("ArtCalibration/" + layer_name) == null:
            _fail("live battle lacks scene layer: " + layer_name)
            return
    for pair in [[0, "shen_changfeng"], [1, "pursuer_captain"]]:
        var sprite: Sprite2D = painted.actors[pair[0]].get_node_or_null("ActionSprite")
        var profile: WuxiaActorAnimationProfile = Art.animation_profile_for_character(pair[1])
        if sprite == null or sprite.scale.x <= 0.0 or not is_equal_approx(sprite.scale.x,sprite.scale.y):
            _fail("live battle sprite scale is invalid: " + pair[1])
            return
        var native_sprite: AnimatedSprite2D = sprite.get_node_or_null("NativeFrames")
        if native_sprite == null or native_sprite.sprite_frames != profile.native_frames or \
                native_sprite.sprite_frames.get_frame_count("idle") != 1:
            _fail("live battle did not display the authored side-facing idle: " + pair[1])
            return
    painted.set_weather_enabled(false)
    if painted.scene_root.get_node("ArtCalibration/WeatherOverlay").visible:
        _fail("weather must be independently switchable")
        return
    battle.queue_free()
    await process_frame
    print("ART_RUNTIME_INTEGRATION_OK: two live SpriteFrames profiles, two portraits, four scene layers")
    quit(0)
