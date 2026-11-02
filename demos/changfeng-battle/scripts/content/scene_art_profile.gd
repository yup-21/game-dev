@tool
class_name WuxiaSceneArtProfile
extends Resource
const CombatScale = preload("res://scripts/combat_scale.gd")
## Reusable layered, camera-aligned 2D artwork. Collision remains in map data.
## All layers share the viewport's untransformed pixel-space coordinate origin.

@export var reference_size: Vector2i = Vector2i(1600, 1000)
## Even story-only and indoor scenes share the combat world pixel ruler.
@export var pixels_per_unit: float = CombatScale.PIXELS_PER_UNIT
@export var background: Texture2D
@export var ground: Texture2D
@export var foreground: Texture2D
@export var weather: Texture2D
@export var story_preview: Texture2D  # Optional flattened story view of the same layered scene.

func valid_for(viewport: Vector2i) -> bool:
    if reference_size != viewport or viewport.x <= 0 or viewport.y <= 0 or \
            not CombatScale.valid_map_pixels_per_unit(pixels_per_unit):
        return false
    if background == null or ground == null:
        return false
    for layer in [background, ground, foreground, weather, story_preview]:
        if layer != null and Vector2i(layer.get_size()) != reference_size:
            return false
    return true
