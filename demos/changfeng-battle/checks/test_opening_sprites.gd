extends SceneTree
## First-act actor visuals must be real nodes driven by CharacterRegistry,
## never a generated SVG, a painter fallback, or a baked-in background.
const Art = preload("res://scripts/hd2d_art_catalog.gd")
const Registry = preload("res://scripts/character_registry.gd")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")
var checks := 0
var failures := 0

func _check(value: bool, reason: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("OPENING_SPRITES: "+reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://opening.tscn") as PackedScene
    _check(packed!=null,"opening scene loads")
    if packed==null:
        quit(1)
        return
    var opening := packed.instantiate()
    root.add_child(opening)
    await process_frame
    var registry = Registry.new()
    var hero = opening.get("player_sprite")
    var elder = opening.get("escort_sprite")
    var layer = opening.get("characters_layer")
    _check(layer!=null and hero!=null and elder!=null,
        "two independent story actors exist under the scene")
    if hero==null or elder==null:
        quit(1)
        return
    _check(hero is Node2D and elder is Node2D and
        hero.get_node_or_null("BodySprite") is Sprite2D and
        elder.get_node_or_null("BodySprite") is Sprite2D,
        "both NPCs render as real Sprite2D nodes")
    _check(hero.character_id=="shen_changfeng"
        and elder.character_id=="escort_elder"
        and str(registry.get_profile(elder.character_id).name)=="老镖头",
        "both character identities resolve from CharacterRegistry")
    _check(hero.has_real_sprite and hero.is_sheet and hero.body.hframes==6
        and hero.body.vframes==4 and Art.uses_supplied_sheet(0),
        "hero uses existing imported 6x4 martial sprite sheet")
    _check(elder.has_real_sprite and not elder.is_sheet
        and elder.body.texture==Art.story_pose_for_character("escort_elder")
        and elder.body.material==null
        and elder.body.frame_coords==Vector2i.ZERO,
        "injured elder uses dedicated transparent story pose, no generated model")
    var hero_ink := VisualScale._opaque_bounds(hero.body.texture,6,4)
    var elder_ink := VisualScale._opaque_bounds(elder.body.texture,1,1)
    if hero_ink.size.y >= 16 and hero_ink.size.y < 245 and \
            elder_ink.size.y >= 16 and elder_ink.size.y < int(elder.body.texture.get_height()*0.96):
        var hero_height := float(hero_ink.size.y) * hero.body.scale.y
        var elder_height := float(elder_ink.size.y) * elder.body.scale.y
        _check(absf(hero_height - VisualScale.TARGET_HEIGHT) < 5.0
            and absf(elder_height - VisualScale.TARGET_HEIGHT) < 5.0,
            "hero and elder are normalized to the same visible world height")
    else:
        _check(hero.body.scale.x > 0.0 and elder.body.scale.x > 0.0,
            "opaque-matte fallback still has positive character scale")
    _check(not layer.visible,"story role sprites stay hidden during title")
    var registered_pose: String = str(registry.for_name("老镖头").art.static_pose)
    _check(registered_pose.contains("/imported/candidates/2026-11-01/escort_elder/pose_escort_elder_injured_v01.png"),
        "new injured PNG is registered on the character dossier")
    opening.call("_enter_new_game")
    await process_frame
    _check(not layer.visible,"cinematic still portraits do not clash with scene sprites")
    opening.story.skip_cinematic()
    await process_frame
    _check(opening.story.phase=="explore" and layer.visible,
        "exploration automatically enables character sprites")
    var start: Vector2=Vector2(350,705)
    _check(hero.position==start and elder.position==Vector2(1050,570),
        "player and NPC keep precise world feet anchors")
    var tex = hero.body.texture
    var authored: WuxiaActorAnimationProfile = Art.animation_profile_for_character("shen_changfeng")
    var expected_east_flip: bool = authored.faces_left_unflipped if authored != null else true
    hero.set_motion(Vector2.RIGHT,0.15)
    _check(hero.animation_player is AnimationPlayer
        and hero.animation_player.current_animation == "move"
        and hero.walking and (authored == null or authored.clip_for("move").frames.has(hero.body.frame))
        and hero.body.flip_h == expected_east_flip and hero.body.texture==tex,
        "eastward walking follows the authored profile direction and move frames")
    hero.set_motion(Vector2.LEFT,0.14)
    _check(hero.body.flip_h != expected_east_flip,"westward walking mirrors the authored facing")
    elder.set_motion(Vector2.RIGHT,1.2)
    _check(elder.animation_player == null and not elder.walking
        and elder.body.frame_coords==Vector2i.ZERO,
        "wounded elder remains a deliberate static pose")
    hero.set_motion(Vector2.ZERO,0.10)
    _check(not hero.walking and hero.animation_player.current_animation == "idle"
        and hero.body.frame_coords==Vector2i.ZERO,
        "idle restores stance and never invents new frames")
    opening.player_pos=Vector2(1040,580)
    opening.call("_sync_story_sprites",Vector2.ZERO,0.0)
    _check(hero.feet()==Vector2(1040,580),"sprite moves with authoritative explore position")
    opening.call("_start_dialogue")
    await process_frame
    _check(opening.story.phase=="dialogue" and not layer.visible
        and Art.portrait("老镖头")!=null,
        "dialogue uses painted portraits, no actor drawn above dialogue UI")
    opening.queue_free()
    await process_frame
    print("OPENING_SPRITES_PASS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures>0 else 0)
