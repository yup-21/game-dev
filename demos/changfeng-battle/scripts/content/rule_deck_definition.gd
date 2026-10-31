@tool
class_name WuxiaRuleDeckDefinition
extends Resource
@export var deck_id: String = ""
@export var has_identical_deck: bool = false
@export var actors_use_identical_deck: bool = false
@export var cards: Array[Resource] = []

func to_record() -> Dictionary:
    var entries: Array = []
    for entry in cards:
        if not entry is WuxiaRuleDeckEntryDefinition: return {}
        var d: Dictionary = entry.to_record()
        if d.is_empty(): return {}
        entries.append(d)
    var data: Dictionary = {"id":deck_id,"cards":entries}
    if has_identical_deck: data["actors_use_identical_deck"] = actors_use_identical_deck
    return data
