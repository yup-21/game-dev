@tool
extends Node2D
## Minimal native-map contract fixture; the production class lives in map PR #140.
@export var source_map: WuxiaMapDefinition

func build_definition() -> WuxiaMapDefinition:
    return source_map

func sync_to_resource() -> void:
    pass
