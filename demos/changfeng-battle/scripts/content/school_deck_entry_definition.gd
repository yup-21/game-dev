@tool
class_name WuxiaSchoolDeckEntryDefinition
extends Resource
## One starting card type in a native school's 12-card deck.
@export var card: Resource
@export_range(1, 12, 1) var count: int = 6

func to_record() -> Dictionary:
    if not card is WuxiaSkillDefinition or bool(card.generated_only):
        return {}
    return {"card_id":card.content_id,"count":count}
