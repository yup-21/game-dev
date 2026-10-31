@tool
class_name WuxiaContentManifest
extends Resource
## Content is explicitly referenced for predictable export and dependency tracking.
## Add a .tres card in the Inspector; no JSON index or filesystem scan required.

@export var characters: Array[Resource] = []
@export var buffs: Array[Resource] = []
@export var items: Array[Resource] = []
@export var skills: Array[Resource] = []
@export var techniques: Array[Resource] = []
@export var effect_handlers: Array[Resource] = []
