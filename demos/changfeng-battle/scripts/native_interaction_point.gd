extends Area2D
## Editable interaction volume. Quests and story decisions remain in their Resources.
signal interaction_requested(interaction_id: StringName)

@export var interaction_id: StringName = &""
@export var prompt_text := "交互"
@export var enabled := true:
    set(value):
        enabled = value
        monitoring = value

func _ready() -> void:
    $Prompt.text = prompt_text
    monitoring = enabled

func request_interaction() -> void:
    if not enabled or interaction_id.is_empty():
        return
    interaction_requested.emit(interaction_id)
    if $InteractionAudio.stream != null:
        $InteractionAudio.play()
