extends "res://scripts/opening_role_sprite.gd"
## NPC is an inherited native role, so callers retain BodySprite, feet,
## animation_player and all existing identity/animation semantics.
signal interaction_requested(trigger_id: String)

@export var trigger_id: String = ""
@export var talk_label: String = "交谈"

func configure_npc(id: String, dialogue_trigger: String = "", label: String = "交谈") -> bool:
    trigger_id = dialogue_trigger
    talk_label = label
    $TalkPrompt.text = label
    return configure(id)

func request_talk() -> void:
    interaction_requested.emit(trigger_id)

func _ready() -> void:
    $TalkPrompt.text = talk_label
