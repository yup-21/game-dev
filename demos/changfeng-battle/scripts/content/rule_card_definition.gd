@tool
class_name WuxiaRuleCardDefinition
extends Resource
@export var card_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var school_id: String = ""
@export var tags: Array[String] = []
@export var threat_level: String = "NORMAL"
@export var usages: Array[Resource] = []
@export var has_relations: bool = false
@export var relations: Dictionary = {}
@export var has_generated_only: bool = false
@export var generated_only: bool = false
@export var lifecycle: String = ""
@export var legacy_only: bool = false
@export var has_retain_own_actions: bool = false
@export var retain_own_actions: int = 0

func to_record() -> Dictionary:
    if card_id.is_empty() or display_name.is_empty() or usages.is_empty(): return {}
    var usage_records: Array = []
    for entry in usages:
        if not entry is WuxiaRuleUsageDefinition: return {}
        var d: Dictionary = entry.to_record()
        if d.is_empty(): return {}
        usage_records.append(d)
    var result: Dictionary = {"id":card_id,"name":display_name,
        "threat_level":threat_level,"tags":tags.duplicate(),"usages":usage_records}
    if not description.is_empty(): result["description"] = description
    if not school_id.is_empty(): result["school_id"] = school_id
    if has_relations: result["relations"] = relations.duplicate(true)
    if has_generated_only: result["generated_only"] = generated_only
    if not lifecycle.is_empty(): result["lifecycle"] = lifecycle
    if legacy_only: result["legacy_only"] = true
    if has_retain_own_actions: result["retain_own_actions"] = retain_own_actions
    return result
