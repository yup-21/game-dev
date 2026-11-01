@tool
class_name WuxiaSkillDefinition
extends WuxiaContentDefinition
## Card is one entrance to a skill. Generated cards are not initial deck entries.

@export var display_name: String = ""
@export var school_id: String = ""
@export var tags: Array[String] = []
@export var generated_only: bool = true
@export_enum("normal", "exile_on_finish") var lifecycle: String = "normal"
@export var retain_own_actions: int = 0
@export var usages: Array[Resource] = []

func content_kind() -> String:
    return "skill"

func to_record() -> Dictionary:
    var converted: Array = []
    for usage in usages:
        if not usage is WuxiaSkillUsageDefinition:
            return {}
        var record: Dictionary = usage.to_record()
        if record.is_empty():
            return {}
        converted.append(record)
    return {
        "schema_version": schema_version, "id": content_id,
        "name": display_name, "school_id": school_id,
        "tags": tags.duplicate(), "generated_only": generated_only,
        "lifecycle": lifecycle, "retain_own_actions": retain_own_actions,
        "relations": {}, "usages": converted
    }
