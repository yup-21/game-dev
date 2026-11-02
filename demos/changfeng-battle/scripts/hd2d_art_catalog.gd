extends RefCounted
## Runtime bridge for the supplied artwork. BattleModel never depends on this layer.
## The 6x4 sheets contain 256x256 pose cells; clean only edge-connected pale matte
## so white clothing inside a silhouette is not blindly keyed out.
const Fallback = preload("res://scripts/fallback_assets.gd")
const Registry = preload("res://scripts/character_registry.gd")
const Assets = preload("res://scripts/asset_registry.gd")
const Native = preload("res://scripts/content/content_registry.gd")
const FRAME_SIZE := 256
const COLS := 6
const ROWS := 4
static var _native = Native.new()
static var _registry = Registry.new()
static var _asset_registry = Assets.new()

## Native character and map cards are the authoritative presentation sources.
## The historical AssetRegistry must not override an imported character portrait
## or a map's scene art, even if an older asset record still exists.
static func _character_card(character_id: String) -> WuxiaCharacterDefinition:
    return _native.resource_for("character", character_id) as WuxiaCharacterDefinition


static func animation_profile_for_character(character_id: String) -> WuxiaActorAnimationProfile:
    var card := _character_card(character_id)
    if card == null or card.animation_profile == null:
        return null
    if card.animation_profile.valid_profile():
        return card.animation_profile
    push_warning("Invalid actor animation profile for " + character_id)
    return null


static func portrait_for_character(character_id: String) -> Texture2D:
    var card := _character_card(character_id)
    return card.portrait if card != null and card.portrait != null else Fallback.PORTRAIT


static func story_pose_for_character(character_id: String) -> Texture2D:
    var card := _character_card(character_id)
    return card.static_pose if card != null and card.static_pose != null else Fallback.STORY_POSE


static func portrait(speaker: String) -> Texture2D:
    var profile: Dictionary = _registry.for_name(speaker)
    return portrait_for_character(str(profile.get("id", "")))


static func scenery(name: String) -> Texture2D:
    var map_card: Resource = _native.resource_for("map", name)
    if map_card is WuxiaMapDefinition or map_card is WuxiaGridMapDefinition:
        var layers := map_card.get("scene_art") as WuxiaSceneArtProfile
        if layers != null and layers.valid_for(map_card.get("viewport_size")):
            return layers.story_preview if layers.story_preview != null else layers.background
        return map_card.get("background") as Texture2D
    var scenery_ids := {"mountain": "r27_scenery_mountain", "snow": "r27_scenery_snow"}
    var texture: Texture2D = _asset_registry.texture(str(scenery_ids.get(name, "")))
    return texture if texture != null else Fallback.SCENE


static func sheet_for_actor(actor_id: int, enemy: bool = false) -> Texture2D:
    var profile: Dictionary = _registry.for_actor(actor_id)
    return sheet_for_character(str(profile.get("id","")),enemy)

static func sheet_for_character(character_id: String, enemy: bool = false) -> Texture2D:
    var profile: WuxiaActorAnimationProfile = animation_profile_for_character(character_id)
    if profile != null:
        return profile.atlas
    var card := _character_card(character_id)
    return card.sprite_sheet if card != null and card.sprite_sheet != null else Fallback.ACTOR_SHEET


static func avatar_for_character(character_id: String, enemy: bool = false) -> Texture2D:
    var painting := portrait_for_character(character_id)
    if painting != null: return painting
    var atlas := AtlasTexture.new()
    var sheet := sheet_for_character(character_id,enemy)
    atlas.atlas = sheet
    var authored_profile: WuxiaActorAnimationProfile = animation_profile_for_character(character_id)
    var columns: int = authored_profile.columns if authored_profile != null else COLS
    var rows: int = authored_profile.rows if authored_profile != null else ROWS
    atlas.region = Rect2(Vector2.ZERO, Vector2(sheet.get_width()/float(columns), sheet.get_height()/float(rows)))
    return atlas

static func avatar(actor_id: int, enemy: bool = false) -> Texture2D:
    var profile: Dictionary = _registry.for_actor(actor_id)
    return avatar_for_character(str(profile.get("id","")),enemy)

## Facing direction is an authored animation-profile field, never a filename whitelist.
static func sheet_faces_left_for_character(character_id: String) -> bool:
    var animation := animation_profile_for_character(character_id)
    return animation.faces_left_unflipped if animation != null else false


static func sheet_faces_left(actor_id: int) -> bool:
    var profile: Dictionary = _registry.for_actor(actor_id)
    return sheet_faces_left_for_character(str(profile.get("id", "")))


static func uses_supplied_sheet_for_character(character_id: String) -> bool:
    var card := _character_card(character_id)
    return card != null and card.sprite_sheet != null


static func uses_supplied_sheet(actor_id: int) -> bool:
    var profile: Dictionary = _registry.for_actor(actor_id)
    return uses_supplied_sheet_for_character(str(profile.get("id","")))
