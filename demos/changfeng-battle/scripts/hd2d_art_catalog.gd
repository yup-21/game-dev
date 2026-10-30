extends RefCounted
## Runtime bridge for the supplied artwork. BattleModel never depends on this layer.
## The 6x4 sheets contain 256x256 pose cells; clean only edge-connected pale matte
## so white clothing inside a silhouette is not blindly keyed out.
const IllustratedFallback = preload("res://scripts/hd2d_illustrated_factory.gd")
const FRAME_SIZE := 256
const COLS := 6
const ROWS := 4
## Literal preloads make the supplied images dependencies of exported Godot builds.
const ACTOR_SHEETS := {
    2: preload("res://assets/concepts/2026-10-30/characters/gu_qingshuang_24_pose.png"),
    3: preload("res://assets/concepts/2026-10-30/characters/green_robed_wanderer_24_pose.png"),
    4: preload("res://assets/concepts/2026-10-30/characters/black_blade_fighter_24_pose.png"),
    5: preload("res://assets/concepts/2026-10-30/characters/violet_dual_blade_assassin_24_pose.png")
}
const PORTRAITS := {
    "沈长风": preload("res://assets/characters/concepts/shen_changfeng_portrait.png"),
    "老镖头": preload("res://assets/characters/concepts/escort_captain_portrait.png"),
    "顾清霜": preload("res://assets/characters/concepts/gu_qingshuang_portrait_v1.png")
}
const SCENES := {
    "mountain": preload("res://assets/concepts/2026-10-30/scenes/mountain_herbal_workshop_day.jpg"),
    "snow": preload("res://assets/concepts/2026-10-30/scenes/snowy_sword_sect_courtyard.jpg")
}
static var _sheets: Dictionary = {}

static func portrait(speaker: String) -> Texture2D:
    return PORTRAITS.get(speaker, null) as Texture2D

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
            var index := y * FRAME_SIZE + x
            if visited[index] == 0 and _pale_matte(frame.get_pixel(x, y)):
                visited[index] = 1
                queue.append(index)
    for y in range(1, FRAME_SIZE - 1):
        for x in [0, FRAME_SIZE - 1]:
            var index := y * FRAME_SIZE + x
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
    if not ACTOR_SHEETS.has(actor_id):
        return IllustratedFallback.make_sheet(enemy)
    if _sheets.has(actor_id):
        return _sheets[actor_id]
    var source_texture: Texture2D = ACTOR_SHEETS[actor_id] as Texture2D
    var source: Image = source_texture.get_image() if source_texture != null else null
    if source == null or source.get_size() != Vector2i(FRAME_SIZE * COLS, FRAME_SIZE * ROWS):
        push_warning("Invalid 6x4 artwork for actor %d" % actor_id)
        return IllustratedFallback.make_sheet(enemy)
    source.convert(Image.FORMAT_RGBA8)
    var atlas := Image.create(FRAME_SIZE * COLS, FRAME_SIZE * ROWS, false, Image.FORMAT_RGBA8)
    atlas.fill(Color.TRANSPARENT)
    for row in range(ROWS):
        for column in range(COLS):
            var origin := Vector2i(column * FRAME_SIZE, row * FRAME_SIZE)
            var frame := source.get_region(Rect2i(origin, Vector2i(FRAME_SIZE, FRAME_SIZE)))
            _clear_edge_matte(frame)
            atlas.blit_rect(frame, Rect2i(Vector2i.ZERO, Vector2i(FRAME_SIZE, FRAME_SIZE)), origin)
    var texture := ImageTexture.create_from_image(atlas)
    _sheets[actor_id] = texture
    return texture

static func avatar(actor_id: int, enemy: bool = false) -> Texture2D:
    var name := "沈长风" if actor_id == 0 else ("顾清霜" if actor_id == 2 else "")
    var painting := portrait(name)
    if painting != null:
        return painting
    var atlas := AtlasTexture.new()
    var sheet := sheet_for_actor(actor_id, enemy)
    atlas.atlas = sheet
    atlas.region = Rect2(Vector2.ZERO, Vector2(sheet.get_width() / 6.0, sheet.get_height() / 4.0))
    return atlas

static func uses_supplied_sheet(actor_id: int) -> bool:
    return ACTOR_SHEETS.has(actor_id)
