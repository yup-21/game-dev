@tool
class_name WuxiaSceneArtProfile
extends Resource
## Reusable layered, camera-aligned 2D artwork. Collision remains in map data.
## All layers share the viewport's untransformed pixel-space coordinate origin.

@export var reference_size: Vector2i = Vector2i(1600, 1000)
@export var background: Texture2D
@export var ground: Texture2D
@export var foreground: Texture2D
@export var weather: Texture2D
@export var story_preview: Texture2D  # Optional flattened story view of the same layered scene.

func valid_for(viewport: Vector2i) -> bool:
    if reference_size != viewport or viewport.x <= 0 or viewport.y <= 0:
        return false
    if background == null or ground == null:
        return false
    for layer in [background, ground, foreground, weather, story_preview]:
        if layer != null and Vector2i(layer.get_size()) != reference_size:
            return false
    return true
