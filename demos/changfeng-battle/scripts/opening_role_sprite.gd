extends Node2D
## An in-world character, not a drawing command or generated SVG.
## Stable character_id selects art from CharacterRegistry/ArtCatalog.
## Base node position is the actual feet point in the painted temple.
const Registry = preload("res://scripts/character_registry.gd")
const Art = preload("res://scripts/hd2d_art_catalog.gd")
const SpriteClips = preload("res://scripts/battle_native_sprite_clips.gd")
const Timeline = preload("res://scripts/battle_action_timeline.gd")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")
const CombatScale = preload("res://scripts/combat_scale.gd")
const ANIMATION_COLUMNS := 6
const ANIMATION_ROWS := 4
const WALK_FPS := 9.0

var character_id: String = ""
var role: Dictionary = {}
var body: Sprite2D
var foot_shadow: Polygon2D
var animation_player: AnimationPlayer
var animation_profile: WuxiaActorAnimationProfile
var walking: bool = false
var is_sheet: bool = false
var has_real_sprite: bool = false
var load_error: String = ""

func configure(id: String) -> bool:
    character_id = id
    role = Registry.new().get_profile(character_id)
    if role.is_empty():
        load_error = "Unknown story character: " + character_id
        push_error(load_error)
        return false
    # Authored instance paths are part of the editor contract; do not rename
    # StoryRole and invalidate child paths inside StoryNPC/workbench scenes.
    if name not in ["StoryRole", "StoryNPC"]:
        name = "Role_" + character_id
    is_sheet = Art.uses_supplied_sheet_for_character(character_id)
    animation_profile = Art.animation_profile_for_character(character_id) if is_sheet else null
    var texture: Texture2D
    if is_sheet:
        if animation_profile != null:
            texture = animation_profile.idle_atlas()
        # Story-only NPCs have no battle actor ID. Read the live native card;
        # battle actors retain the verified animation profile.
        if texture == null and int(role.battle_actor_id) < 0:
            var card: WuxiaCharacterDefinition = Registry.new().definition_for(character_id)
            texture = card.sprite_sheet if card != null else null
            if texture == null:
                texture = Art.sheet_for_character(character_id)
        elif texture == null:
            texture = Art.sheet_for_actor(int(role.battle_actor_id),false)
    else:
        # A genuine artist-authored transparent SVG character, NOT the old
        # runtime SVG generator or the rectangular dialogue portrait.
        # It is intentionally static because the elder has no animation yet.
        texture = Art.story_pose_for_character(character_id)
    if texture == null:
        load_error = "No imported fallback available: " + character_id
        push_error(load_error)
        return false
    body = get_node_or_null("BodySprite") as Sprite2D
    if body == null:
        body = Sprite2D.new()
        body.name = "BodySprite"
        add_child(body)
    body.texture = texture
    body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    if is_sheet:
        body.set_meta("faces_left_unflipped", animation_profile.faces_left_unflipped if animation_profile != null
            else Art.sheet_faces_left_for_character(character_id))
        body.flip_h = bool(body.get_meta("faces_left_unflipped")) # Initial look east
    body.centered = true
    if is_sheet:
        body.hframes = animation_profile.idle_columns() if animation_profile != null else ANIMATION_COLUMNS
        body.vframes = animation_profile.idle_rows() if animation_profile != null else ANIMATION_ROWS
        body.offset = animation_profile.feet_offset if animation_profile != null else Vector2(0,-128)
        body.scale = animation_profile.actor_scale if animation_profile != null else Vector2(120.0/256.0,130.0/256.0)
    else:
        # The art is already a full-alpha static injured pose. Preserve its
        # edges and proportions instead of masking a rectangular portrait.
        var image_size: Vector2 = texture.get_size()
        body.offset = Vector2(0,-image_size.y*0.5)
        body.scale = Vector2.ONE * (CombatScale.actor_height_pixels() / image_size.y)
    var idle_frame: int = 0
    if animation_profile != null:
        var idle_clip: WuxiaActorAnimationClip = animation_profile.clip_for("idle")
        if idle_clip != null and not idle_clip.frames.is_empty():
            idle_frame = int(idle_clip.frames[0])
    VisualScale.fit(body, body.scale, CombatScale.actor_height_pixels(),
        animation_profile.feet_adjust if animation_profile != null else Vector2.ZERO,
        idle_frame, animation_profile.auto_fit_height if animation_profile != null else true)
    foot_shadow = get_node_or_null("FootShadow") as Polygon2D
    if foot_shadow == null:
        foot_shadow = Polygon2D.new()
        foot_shadow.name = "FootShadow"
        add_child(foot_shadow)
    foot_shadow.color = Color(0.015,0.060,0.065,0.22)
    if foot_shadow.polygon.is_empty():
        var polygon := PackedVector2Array()
        for i in range(24):
            var theta := TAU * float(i)/24.0
            polygon.append(Vector2(cos(theta)*CombatScale.footprint_radius_pixels(),sin(theta)*CombatScale.footprint_radius_pixels()*0.42))
        foot_shadow.polygon = polygon
    if is_sheet:
        animation_player = SpriteClips.attach(body, Timeline.new(), animation_profile)
        var native: AnimatedSprite2D = body.get_node_or_null("NativeFrames") as AnimatedSprite2D
        if native != null and animation_profile != null and \
                animation_profile.native_frames != null and native.sprite_frames != null:
            native.flip_h = body.flip_h
            native.play("idle")
    has_real_sprite = true
    return true

func set_motion(motion: Vector2, delta: float) -> void:
    if not has_real_sprite or not is_sheet or animation_player == null:
        return
    walking = motion.length_squared() > 0.0001
    if walking and absf(motion.x) > 0.05:
        var source_faces_left: bool = bool(body.get_meta("faces_left_unflipped", false))
        body.flip_h = motion.x > 0.0 if source_faces_left else motion.x < 0.0
    var native: AnimatedSprite2D = body.get_node_or_null("NativeFrames") as AnimatedSprite2D
    var native_active := native != null and animation_profile != null and \
        animation_profile.native_frames != null and native.sprite_frames != null
    var state: String = "move" if walking else "idle"
    if native_active:
        state = "walk" if walking and native.sprite_frames.has_animation("walk") else "idle"
        if native.animation != state or not native.is_playing():
            native.play(state)
        native.flip_h = body.flip_h
    if animation_player.current_animation != state:
        animation_player.play(state)
    # AnimationPlayer is the sole owner of the frame and pose tracks.
    animation_player.advance(maxf(delta,0.0))

func feet() -> Vector2:
    return position
