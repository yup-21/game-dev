@tool
class_name WuxiaBuffDefinition
extends WuxiaContentDefinition
## Buffs describe effects only; StatusSystem owns stacks, expiry and stat state.

@export var display_name: String = ""
@export var is_public: bool = true
@export_range(1, 99, 1) var stack_limit: int = 1
@export_enum("global_ticks_after_apply", "permanent") var expiry_kind: String = "global_ticks_after_apply"
@export_range(1, 1000000, 1) var duration_ticks: int = 100
@export var modifiers: Array[Dictionary] = []

func content_kind() -> String:
    return "buff"

func to_record() -> Dictionary:
    var expiry: Dictionary = {"kind": expiry_kind}
    if expiry_kind == "global_ticks_after_apply":
        expiry["duration"] = duration_ticks
    return {
        "schema_version": schema_version,
        "id": content_id,
        "name": display_name,
        "public": is_public,
        "stack_limit": stack_limit,
        "expiry": expiry,
        "modifiers": modifiers.duplicate(true)
    }
