@tool
class_name WuxiaSchoolDefinition
extends WuxiaContentDefinition
## New martial schools are content Resources, independent of legacy catalogs.
@export var display_name: String = ""
@export var identity: String = ""
@export var core_forms: Array[Resource] = []
@export var deck: Array[Resource] = []

func content_kind() -> String:
    return "school"

func to_record() -> Dictionary:
    var core: Array = []
    var cards: Array = []
    for form in core_forms:
        if not form is WuxiaSkillDefinition: return {}
        core.append(form.content_id)
    for entry in deck:
        if not entry is WuxiaSchoolDeckEntryDefinition: return {}
        var record: Dictionary = entry.to_record()
        if record.is_empty(): return {}
        cards.append(record)
    return {"schema_version":schema_version,"id":content_id,
        "name":display_name,"identity":identity,
        "core_forms":core,"deck":{"cards":cards}}
