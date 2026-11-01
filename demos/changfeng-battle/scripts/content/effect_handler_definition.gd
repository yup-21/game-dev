@tool
class_name WuxiaEffectHandlerDefinition
extends WuxiaContentDefinition
## A new primitive is implemented by a trusted project script, then registered.

@export var effect_type: String = ""
@export var handler_script: Script

func content_kind() -> String:
    return "effect_handler"

func to_record() -> Dictionary:
    return {
        "schema_version": schema_version, "id": content_id,
        "effect_type": effect_type,
        "script_path": handler_script.resource_path if handler_script != null else ""
    }
