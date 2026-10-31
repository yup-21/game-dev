@tool
class_name WuxiaRuleCatalogDefinition
extends WuxiaContentDefinition
## An authorable Godot hierarchy for the two historical martial rulebooks.
## The Dictionary is GENERATED at the domain boundary, never stored as content.
@export_enum("schools", "tingfeng") var catalog_type: String = "schools"
@export var original_schema: String = ""
@export var source: String = ""
@export_multiline var design: String = ""
@export var implementation_status: String = ""
@export var meta: Dictionary = {}
@export var rules: Dictionary = {}
@export var statuses: Array[Resource] = []
@export var schools: Array[Resource] = []
@export var cards: Array[Resource] = []
@export var combos: Array[Resource] = []
@export var deck: Resource
@export var passive_skills: Array[Resource] = []

func content_kind() -> String:
    return "rule_catalog"

func _records(resources: Array, expected_script: String) -> Array:
    var output: Array = []
    for item in resources:
        if item == null or not item.has_method("to_record"):
            return []
        if item.get_script().get_global_name() != expected_script:
            return []
        var value: Dictionary = item.to_record()
        if value.is_empty(): return []
        output.append(value)
    return output

func to_record() -> Dictionary:
    if content_id.is_empty() or original_schema.is_empty(): return {}
    var statuses_out: Array = _records(statuses, "WuxiaRuleStatusDefinition")
    var cards_out: Array = _records(cards, "WuxiaRuleCardDefinition")
    var combos_out: Array = _records(combos, "WuxiaRuleComboDefinition")
    if statuses_out.size() != statuses.size() or cards_out.size() != cards.size() or combos_out.size() != combos.size():
        return {}
    var data: Dictionary = {"schema_version": original_schema}
    if catalog_type == "schools":
        var schools_out: Array = _records(schools, "WuxiaRuleSchoolDefinition")
        if schools_out.size() != schools.size() or schools_out.is_empty() or cards_out.is_empty():
            return {}
        data["source"] = source
        data["design"] = design
        data["statuses"] = statuses_out
        data["schools"] = schools_out
        data["cards"] = cards_out
        data["combos"] = combos_out
    elif catalog_type == "tingfeng":
        if deck == null or not deck is WuxiaRuleDeckDefinition:
            return {}
        var deck_out: Dictionary = deck.to_record()
        var passive_out: Array = _records(passive_skills, "WuxiaRulePassiveDefinition")
        if deck_out.is_empty() or passive_out.size() != passive_skills.size() or cards_out.is_empty():
            return {}
        data["implementation_status"] = implementation_status
        data["meta"] = meta.duplicate(true)
        data["rules"] = rules.duplicate(true)
        data["statuses"] = statuses_out
        data["combos"] = combos_out
        data["cards"] = cards_out
        data["deck"] = deck_out
        data["passive_skills"] = passive_out
    else:
        return {}
    return {"schema_version": schema_version, "id": content_id, "data": data}
