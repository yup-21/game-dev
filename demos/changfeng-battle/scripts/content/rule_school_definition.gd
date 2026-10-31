@tool
class_name WuxiaRuleSchoolDefinition
extends Resource
@export var school_id: String = ""
@export var display_name: String = ""
@export var identity: String = ""
@export var core_forms: Array[String] = []
@export var deck: Array[Resource] = []

func to_record() -> Dictionary:
    if school_id.is_empty() or display_name.is_empty() or core_forms.size() != 2: return {}
    var output: Array = []
    for entry in deck:
        if not entry is WuxiaRuleDeckEntryDefinition: return {}
        var item: Dictionary = entry.to_record()
        if item.is_empty(): return {}
        output.append(item)
    return {"id": school_id, "name":display_name, "identity":identity,
        "core_forms":core_forms.duplicate(), "deck":{"cards":output}}
