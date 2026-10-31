extends RefCounted
## Runtime bridge for the supplied artwork. BattleModel never depends on this layer.
## The 6x4 sheets contain 256x256 pose cells; clean only edge-connected pale matte
## so white clothing inside a silhouette is not blindly keyed out.
const IllustratedFallback = preload("res://scripts/hd2d_illustrated_factory.gd")
const Registry = preload("res://scripts/character_registry.gd")
const Assets = preload("res://scripts/asset_registry.gd")
const FRAME_SIZE := 256
const COLS := 6
const ROWS := 4
## Literal preloads make the supplied images dependencies of exported Godot builds.
# Preload every used image for Godot exports, but resolve their *identity*
# via CharacterRegistry instead of duplicating actor numeric IDs.
const SHEETS_BY_PATH := {
    "res://assets/concepts/2026-10-30/characters/gu_qingshuang_24_pose.png": preload("res://assets/concepts/2026-10-30/characters/gu_qingshuang_24_pose.png"),
    "res://assets/concepts/2026-10-30/characters/green_robed_wanderer_24_pose.png": preload("res://assets/concepts/2026-10-30/characters/green_robed_wanderer_24_pose.png"),
    "res://assets/concepts/2026-10-30/characters/black_blade_fighter_24_pose.png": preload("res://assets/concepts/2026-10-30/characters/black_blade_fighter_24_pose.png"),
    "res://assets/concepts/2026-10-30/characters/violet_dual_blade_assassin_24_pose.png": preload("res://assets/concepts/2026-10-30/characters/violet_dual_blade_assassin_24_pose.png"),
    "res://assets/concepts/2026-10-30/character_style/blue_swordfighter_pixel_study.jpg": preload("res://assets/concepts/2026-10-30/character_style/blue_swordfighter_pixel_study.jpg"),
    "res://assets/concepts/2026-10-30/character_style/red_thread_fighter_pixel_study.jpg": preload("res://assets/concepts/2026-10-30/character_style/red_thread_fighter_pixel_study.jpg")
}
const PORTRAITS_BY_PATH := {
    "res://assets/characters/concepts/shen_changfeng_portrait.png": preload("res://assets/characters/concepts/shen_changfeng_portrait.png"),
    "res://assets/characters/concepts/escort_captain_portrait.png": preload("res://assets/characters/concepts/escort_captain_portrait.png"),
    "res://assets/characters/concepts/gu_qingshuang_portrait_v1.png": preload("res://assets/characters/concepts/gu_qingshuang_portrait_v1.png")
}
## Static authored character art is kept separate from animated Sprite Sheets.
## Preloading ensures Godot exports the real transparent SVG pose.
const STORY_POSES_BY_PATH := {
    "res://assets/characters/concepts/escort_elder_injured.svg":
        preload("res://assets/characters/concepts/escort_elder_injured.svg")
}
const SCENES := {
    "mountain": preload("res://assets/concepts/2026-10-30/scenes/mountain_herbal_workshop_day.jpg"),
    "snow": preload("res://assets/concepts/2026-10-30/scenes/snowy_sword_sect_courtyard.jpg"),
    "rainy_bridge": preload("res://assets/concepts/2026-10-30/scenes/rainy_broken_bridge_battle_v1.jpg")
}
static var _registry = Registry.new()
static var _asset_registry = Assets.new()
static var _sheets: Dictionary = {}

## Resolve new assets from character data; preserve known preloads for exports.
static func _asset_texture(path: String, known: Dictionary) -> Texture2D:
    if known.has(path): return known[path] as Texture2D
    if not path.begins_with("res://assets/") or ".." in path: return null
    if not ResourceLoader.exists(path, "Texture2D"): return null
    return load(path) as Texture2D

static func portrait_for_character(character_id: String) -> Texture2D:
    var native: Texture2D = _asset_registry.texture_for_character(character_id,"portrait")
    if native != null: return native
    var profile: Dictionary = _registry.get_profile(character_id)
    var path: String = str(profile.get("art",{}).get("portrait",""))
    return _asset_texture(path,PORTRAITS_BY_PATH)

static func story_pose_for_character(character_id: String) -> Texture2D:
    var native: Texture2D = _asset_registry.texture_for_character(character_id,"static_pose")
    if native != null: return native
    var definition: Dictionary = _registry.get_profile(character_id)
    var source: String = str(definition.get("art",{}).get("static_pose",""))
    return STORY_POSES_BY_PATH.get(source,null) as Texture2D

static func portrait(speaker: String) -> Texture2D:
    var profile: Dictionary = _registry.for_name(speaker)
    return portrait_for_character(str(profile.get("id","")))

static func scenery(name: String) -> Texture2D:
    return SCENES.get(name, null) as Texture2D

static func _pale_matte(color: Color) -> bool:
    if color.a < 0.04:
        return true
    var low := minf(color.r, minf(color.g, color.b))
    var high := maxf(color.r, maxf(color.g, color.b))
    return color.a > 0.96 and low > 0.90 and high - low < 0.075

static func _clear_edge_matte(frame: Image) -> void:
    # Flood fill per cell: a global white color key would punch holes in robes.
    var visited := PackedByteArray()
    visited.resize(FRAME_SIZE * FRAME_SIZE)
    var queue := PackedInt32Array()
    for x in range(FRAME_SIZE):
        for y in [0, FRAME_SIZE - 1]:
            var index: int = int(y) * FRAME_SIZE + int(x)
            if visited[index] == 0 and _pale_matte(frame.get_pixel(x, y)):
                visited[index] = 1
                queue.append(index)
    for y in range(1, FRAME_SIZE - 1):
        for x in [0, FRAME_SIZE - 1]:
            var index: int = int(y) * FRAME_SIZE + int(x)
            if visited[index] == 0 and _pale_matte(frame.get_pixel(x, y)):
                visited[index] = 1
                queue.append(index)
    var cursor := 0
    while cursor < queue.size():
        var index: int = queue[cursor]
        cursor += 1
        var x: int = index % FRAME_SIZE
        var y: int = index / FRAME_SIZE
        var color := frame.get_pixel(x, y)
        color.a = 0.0
        frame.set_pixel(x, y, color)
        if x > 0 and visited[index - 1] == 0 and _pale_matte(frame.get_pixel(x - 1, y)):
            visited[index - 1] = 1
            queue.append(index - 1)
        if x + 1 < FRAME_SIZE and visited[index + 1] == 0 and _pale_matte(frame.get_pixel(x + 1, y)):
            visited[index + 1] = 1
            queue.append(index + 1)
        if y > 0 and visited[index - FRAME_SIZE] == 0 and _pale_matte(frame.get_pixel(x, y - 1)):
            visited[index - FRAME_SIZE] = 1
            queue.append(index - FRAME_SIZE)
        if y + 1 < FRAME_SIZE and visited[index + FRAME_SIZE] == 0 and _pale_matte(frame.get_pixel(x, y + 1)):
            visited[index + FRAME_SIZE] = 1
            queue.append(index + FRAME_SIZE)

static func sheet_for_actor(actor_id: int, enemy: bool = false) -> Texture2D:
    var profile: Dictionary = _registry.for_actor(actor_id)
    return sheet_for_character(str(profile.get("id","")),enemy)

static func sheet_for_character(character_id: String, enemy: bool = false) -> Texture2D:
    var profile: Dictionary = _registry.get_profile(character_id)
    var binding: Dictionary = _asset_registry.record_for_character(character_id,"pose_sheet")
    var path: String = str(binding.get("path",profile.get("art",{}).get("sprite_sheet","")))
    if _asset_texture(path,SHEETS_BY_PATH) == null:
        return IllustratedFallback.make_sheet(enemy)
    if _sheets.has(path):
        return _sheets[path]
    var uses_concept_cells: bool = path.ends_with(".jpg")
    var source_texture: Texture2D = _asset_texture(path,SHEETS_BY_PATH)
    var source: Image = source_texture.get_image() if source_texture != null else null
    if source == null or source.is_empty():
        push_warning("Invalid 6x4 artwork for character %s" % character_id)
        return IllustratedFallback.make_sheet(enemy)
    if not uses_concept_cells and source.get_size() != Vector2i(FRAME_SIZE * COLS, FRAME_SIZE * ROWS):
        push_warning("Invalid 6x4 artwork for character %s" % character_id)
        return IllustratedFallback.make_sheet(enemy)
    source.convert(Image.FORMAT_RGBA8)
    var atlas := Image.create(FRAME_SIZE * COLS, FRAME_SIZE * ROWS, false, Image.FORMAT_RGBA8)
    atlas.fill(Color.TRANSPARENT)
    for row in range(ROWS):
        for column in range(COLS):
            var origin := Vector2i(column * FRAME_SIZE, row * FRAME_SIZE)
            var frame: Image
            if uses_concept_cells:
                var x0: int = floori(float(column) * source.get_width() / COLS)
                var x1: int = floori(float(column + 1) * source.get_width() / COLS)
                var y0: int = floori(float(row) * source.get_height() / ROWS)
                var y1: int = floori(float(row + 1) * source.get_height() / ROWS)
                frame = source.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0))
                frame.resize(FRAME_SIZE, FRAME_SIZE, Image.INTERPOLATE_LANCZOS)
            else:
                frame = source.get_region(Rect2i(origin, Vector2i(FRAME_SIZE, FRAME_SIZE)))
            _clear_edge_matte(frame)
            atlas.blit_rect(frame, Rect2i(Vector2i.ZERO, Vector2i(FRAME_SIZE, FRAME_SIZE)), origin)
    var texture := ImageTexture.create_from_image(atlas)
    _sheets[path] = texture
    return texture

static func avatar_for_character(character_id: String, enemy: bool = false) -> Texture2D:
    var painting := portrait_for_character(character_id)
    if painting != null: return painting
    var atlas := AtlasTexture.new()
    var sheet := sheet_for_character(character_id,enemy)
    atlas.atlas = sheet
    atlas.region = Rect2(Vector2.ZERO,Vector2(sheet.get_width()/6.0,sheet.get_height()/4.0))
    return atlas

static func avatar(actor_id: int, enemy: bool = false) -> Texture2D:
    var profile: Dictionary = _registry.for_actor(actor_id)
    return avatar_for_character(str(profile.get("id","")),enemy)

## Most supplied 6x4 pose sheets are drawn looking screen-left (hair and
## leading foot trail to the right). Generated fallback sheets face screen-right.
## Keep sprite orientation as an ART attribute, independent from battle rules.
## An actor profile may override this with art.faces_left when new sheets vary.
static func sheet_faces_left_for_character(character_id: String) -> bool:
    var profile: Dictionary = _registry.get_profile(character_id)
    var art: Dictionary = profile.get("art", {})
    var path: String = str(art.get("sprite_sheet", ""))
    var binding: Dictionary = _asset_registry.record_for_character(character_id,"pose_sheet")
    if not binding.is_empty(): return bool(binding.get("faces_left",true))
    return bool(art.get("faces_left", SHEETS_BY_PATH.has(path)))

static func sheet_faces_left(actor_id: int) -> bool:
    var profile: Dictionary = _registry.for_actor(actor_id)
    return sheet_faces_left_for_character(str(profile.get("id","")))

static func uses_supplied_sheet_for_character(character_id: String) -> bool:
    var profile: Dictionary = _registry.get_profile(character_id)
    var binding: Dictionary = _asset_registry.record_for_character(character_id,"pose_sheet")
    var path: String = str(binding.get("path",profile.get("art",{}).get("sprite_sheet","")))
    return _asset_texture(path,SHEETS_BY_PATH) != null

static func uses_supplied_sheet(actor_id: int) -> bool:
    var profile: Dictionary = _registry.for_actor(actor_id)
    return uses_supplied_sheet_for_character(str(profile.get("id","")))
