@tool
class_name WuxiaDataDocument
extends WuxiaContentDefinition
## Native editor-inspectable data for established complex catalog schemas.
## Production loads this Resource; original JSON remains a read-only test fixture.

@export var data: Dictionary = {}

func content_kind() -> String:
    return "document"

func to_record() -> Dictionary:
    if data.is_empty():
        return {}
    return {
        "schema_version": schema_version,
        "id": content_id,
        "data": data.duplicate(true)
    }
