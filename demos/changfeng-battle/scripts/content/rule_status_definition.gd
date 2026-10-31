@tool
class_name WuxiaRuleStatusDefinition
extends Resource
@export var status_id: String = ""
@export var display_name: String = ""
@export var public: bool = true
@export var stack_limit: int = 1
@export var expiry_kind: String = ""
@export var expiry_duration: int = 0
@export var consume: String = ""
@export var effect: String = ""
@export var has_negative: bool = false
@export var negative: bool = false
@export var has_refresh_on_reapply: bool = false
@export var refresh_on_reapply: bool = false
@export var visibility: String = ""

func to_record() -> Dictionary:
    if status_id.is_empty() or display_name.is_empty() or expiry_kind.is_empty(): return {}
    var d: Dictionary = {"id":status_id,"name":display_name,"public":public,
        "stack_limit":stack_limit,"expiry":{"kind":expiry_kind,"duration":expiry_duration}}
    if not consume.is_empty(): d["consume"] = consume
    if not effect.is_empty(): d["effect"] = effect
    if has_negative: d["negative"] = negative
    if has_refresh_on_reapply: d["refresh_on_reapply"] = refresh_on_reapply
    if not visibility.is_empty(): d["visibility"] = visibility
    return d
