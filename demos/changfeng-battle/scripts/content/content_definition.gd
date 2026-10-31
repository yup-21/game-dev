@tool
class_name WuxiaContentDefinition
extends Resource
## Immutable authoring definition. Runtime state must never be stored here.
## The editor saves these definitions as native .tres resources.

@export var schema_version: int = 1
@export var content_id: String = ""

func content_kind() -> String:
    return ""

func to_record() -> Dictionary:
    return {}
