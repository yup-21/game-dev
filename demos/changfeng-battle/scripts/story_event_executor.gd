extends RefCounted
## Validate and stage story effects before touching a live GameSession.
## Battle-state mutation remains exclusively under BattleModel.
const CharacterRuntime = preload("res://scripts/character_runtime.gd")
const CharacterFactory = preload("res://scripts/character_factory.gd")
const Modifiers = preload("res://scripts/stat_modifier_system.gd")

static func valid_event(value: Variant) -> bool:
    if not value is Dictionary or not value.get("type") is String:
        return false
    match str(value.type):
        "set_flag":
            return value.get("flag") is String and not str(value.flag).is_empty() and value.get("value") is bool
        "grant_clue":
            return value.get("id") is String and not str(value.id).is_empty() and _positive(value.get("count"))
        "grant_item":
            return value.get("character_id") is String and not str(value.character_id).is_empty() and value.get("item_id") is String and not str(value.item_id).is_empty() and _positive(value.get("count"))
        "recruit_character":
            return value.get("character_id") is String and not str(value.character_id).is_empty()
        "learn_school", "switch_school":
            return value.get("character_id") is String and not str(value.character_id).is_empty() and value.get("school_id") is String and not str(value.school_id).is_empty()
        "set_attribute":
            return value.get("character_id") is String and not str(value.character_id).is_empty() and value.get("stat") in ["STR","AGI","CON","MND"] and _attribute(value.get("value"))
        "set_growth":
            if not value.get("character_id") is String or not value.get("source") is String or not value.get("modifiers") is Array:
                return false
            if not str(value.source).begins_with("growth:"):
                return false
            for spec in value.modifiers:
                if not Modifiers.valid_spec(spec):
                    return false
            return true
    return false

static func _positive(value: Variant) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value >= 1 and value <= 99

static func _attribute(value: Variant) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value >= 1 and value <= 100

static func meets(requirements: Variant, flags: Dictionary) -> bool:
    if not requirements is Array:
        return false
    for requirement in requirements:
        if not requirement is Dictionary or not requirement.get("flag") is String or not requirement.get("equals") is bool:
            return false
        if flags.get(str(requirement.flag),false) != requirement.equals:
            return false
    return true

static func prepare(events: Variant, current_flags: Dictionary, current_clues: Dictionary,
        source_characters: Dictionary) -> Dictionary:
    if not events is Array:
        return {"ok":false}
    var next_flags: Dictionary = current_flags.duplicate(true)
    var next_clues: Dictionary = current_clues.duplicate(true)
    var next_characters: Dictionary = {}
    for character_id in source_characters:
        var original = source_characters[character_id]
        var role = CharacterRuntime.new(str(character_id))
        if not role.load_error.is_empty() or not role.restore(original.snapshot()):
            return {"ok":false}
        next_characters[character_id] = role
    for event in events:
        if not valid_event(event):
            return {"ok":false}
        match str(event.type):
            "set_flag":
                next_flags[str(event.flag)] = bool(event.value)
            "grant_clue":
                var clue_id: String = str(event.id)
                var new_count: int = int(next_clues.get(clue_id,0)) + int(event.count)
                if new_count > 999:
                    return {"ok":false}
                next_clues[clue_id] = new_count
            "grant_item":
                var item_recipient = next_characters.get(str(event.character_id),null)
                if item_recipient == null or not item_recipient.inventory.add(str(event.item_id),int(event.count)):
                    return {"ok":false}
            "recruit_character":
                var recruit_id: String = str(event.character_id)
                if next_characters.has(recruit_id) or next_characters.size() >= 8:
                    return {"ok":false}
                var recruit = CharacterFactory.new().create_runtime(recruit_id)
                if recruit == null:
                    return {"ok":false}
                next_characters[recruit_id] = recruit
            "learn_school":
                var learner = next_characters.get(str(event.character_id),null)
                if learner == null or not learner.learn_school(str(event.school_id)):
                    return {"ok":false}
            "switch_school":
                var switcher = next_characters.get(str(event.character_id),null)
                if switcher == null or not switcher.switch_school(str(event.school_id)):
                    return {"ok":false}
            "set_attribute":
                var trainee = next_characters.get(str(event.character_id),null)
                if trainee == null or not trainee.set_attribute(str(event.stat),int(event.value)):
                    return {"ok":false}
            "set_growth":
                var growth_recipient = next_characters.get(str(event.character_id),null)
                if growth_recipient == null or not growth_recipient.set_growth(str(event.source),event.modifiers):
                    return {"ok":false}
    return {"ok":true,"flags":next_flags,"items":next_clues,"characters":next_characters}
