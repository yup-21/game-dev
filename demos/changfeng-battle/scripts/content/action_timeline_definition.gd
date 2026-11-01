@tool
class_name WuxiaActionTimelineDefinition
extends WuxiaContentDefinition
## Strongly typed, editor-authored battle presentation catalog.
## This metadata has no authority to grant combat actions or invulnerability.

@export_multiline var note: String = ""
@export var clips: Array[Resource] = []
@export var event_bindings: Array[Resource] = []

func content_kind() -> String:
    return "action_timeline"

func to_record() -> Dictionary:
    return {
        "schema_version": schema_version,
        "id": content_id,
        "clip_count": clips.size(),
        "event_count": event_bindings.size()
    }
