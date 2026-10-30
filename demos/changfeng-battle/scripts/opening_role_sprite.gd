extends Node2D
## An in-world character, not a drawing command or generated SVG.
## Stable character_id selects art from CharacterRegistry/ArtCatalog.
## Base node position is the actual feet point in the painted temple.
const Registry = preload("res://scripts/character_registry.gd")
const Art = preload("res://scripts/hd2d_art_catalog.gd")
const ANIMATION_COLUMNS := 6
const ANIMATION_ROWS := 4
const WALK_FPS := 9.0

var character_id: String = ""
var role: Dictionary = {}
var body: Sprite2D
var foot_shadow: Polygon2D
var animation_clock: float = 0.0
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
    name = "Role_" + character_id
    is_sheet = not str(role.art.sprite_sheet).is_empty()
    var texture: Texture2D
    if is_sheet:
        # The same 6x4 actor asset and animation indexing as in battle.
        texture = Art.sheet_for_actor(int(role.battle_actor_id),false)
        if not Art.uses_supplied_sheet(int(role.battle_actor_id)):
            load_error = "Missing actor sprite sheet: " + character_id
            push_error(load_error)
            return false
    else:
        # The injured elder has a dedicated painted portrait, but no pose
        # sheet yet. Render it as a static in-world sprite: never invent
        # walking frames or substitute an unrelated character/SVG model.
        texture = Art.portrait_for_character(character_id)
    if texture == null:
        load_error = "Missing story sprite/portrait: " + character_id
        push_error(load_error)
        return false
    body = Sprite2D.new()
    body.name = "BodySprite"
    body.texture = texture
    body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    body.centered = true
    if is_sheet:
        body.hframes = ANIMATION_COLUMNS
        body.vframes = ANIMATION_ROWS
        body.offset = Vector2(0,-128)
        body.scale = Vector2(120.0/256.0,130.0/256.0)
    else:
        # The existing painted art remains visibly an NPC portrait stand-in,
        # feathered at the edges, until a true transparent NPC sheet exists.
        var image_size: Vector2 = texture.get_size()
        body.offset = Vector2(0,-image_size.y*0.5)
        body.scale = Vector2(126.0/image_size.x,175.0/image_size.y)
        body.rotation_degrees = -5.0
        var shader := Shader.new()
        shader.code = """
shader_type canvas_item;
void fragment() {
    vec4 painted = texture(TEXTURE, UV);
    float side = 1.0 - smoothstep(0.75, 0.99, abs(UV.x - 0.5) * 2.0);
    float top = smoothstep(0.01, 0.10, UV.y);
    float bottom = 1.0 - smoothstep(0.91, 0.99, UV.y);
    COLOR = vec4(painted.rgb, painted.a * side * top * bottom);
}
"""
        var material := ShaderMaterial.new()
        material.shader = shader
        body.material = material
    foot_shadow = Polygon2D.new()
    foot_shadow.name = "FootShadow"
    foot_shadow.color = Color(0.015,0.060,0.065,0.22)
    var polygon := PackedVector2Array()
    for i in range(24):
        var theta := TAU * float(i)/24.0
        polygon.append(Vector2(cos(theta)*35.0,sin(theta)*8.0))
    foot_shadow.polygon = polygon
    add_child(foot_shadow)
    add_child(body)
    has_real_sprite = true
    return true

func set_motion(motion: Vector2, delta: float) -> void:
    if not has_real_sprite or not is_sheet:
        return
    walking = motion.length_squared() > 0.0001
    if walking:
        animation_clock += maxf(delta,0.0)
        if absf(motion.x) > 0.05:
            body.flip_h = motion.x < 0.0
    else:
        animation_clock = 0.0
    var frame: int = int(animation_clock*WALK_FPS) % ANIMATION_COLUMNS if walking else 0
    body.frame_coords = Vector2i(frame,1 if walking else 0)

func feet() -> Vector2:
    return position
