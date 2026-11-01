extends RefCounted
## Optional, independent buff catalog. Add typed Resources to the manifest.
const Modifiers = preload("res://scripts/stat_modifier_system.gd")
const Conditions = preload("res://scripts/condition_evaluator.gd")
const NativeContent = preload("res://scripts/content/content_registry.gd")
var definitions: Dictionary = {}
var load_error: String = ""

func _init(manifest_path: String = NativeContent.DEFAULT_MANIFEST) -> void:
    var native = NativeContent.new(manifest_path)
    if not native.load_error.is_empty():
        load_error = native.load_error
        return
    for definition in native.entries("buff").values():
        if not _valid(definition) or definitions.has(str(definition.id)):
            load_error = "Invalid or duplicate native buff"
            definitions.clear()
            return
        definitions[str(definition.id)] = definition.duplicate(true)

func _whole(value: Variant, minimum: int, maximum: int) -> bool:
    return Modifiers._whole(value,minimum,maximum)

func _valid(d: Variant) -> bool:
    if not d is Dictionary or d.get("schema_version") != 1: return false
    for key in d:
        if key not in ["schema_version","id","name","public","stack_limit","expiry","modifiers","conditional_modifiers"]: return false
    if not d.get("id") is String or str(d.id).is_empty() or not d.get("name") is String or str(d.name).is_empty(): return false
    if not d.get("public") is bool or not _whole(d.get("stack_limit"),1,99): return false
    var expiry: Variant = d.get("expiry")
    if not expiry is Dictionary: return false
    if expiry.get("kind") == "permanent":
        if expiry.size() != 1: return false
    elif expiry.get("kind") == "global_ticks_after_apply":
        if expiry.size() != 2 or not _whole(expiry.get("duration"),1,1000000): return false
    else:
        return false
    if not d.get("modifiers",[]) is Array: return false
    for modifier in d.get("modifiers",[]):
        if not Modifiers.valid_spec(modifier) or modifier.has("stacks"): return false
    var conditional: Variant = d.get("conditional_modifiers", [])
    if not conditional is Array or conditional.size() > 16: return false
    var evaluator = Conditions.new()
    for rule in conditional:
        if not rule is Dictionary or rule.size() != 2 or not rule.has("when") or not rule.has("modifiers"):
            return false
        if not _status_condition(rule.when) or not evaluator.valid_spec(rule.when) or not rule.modifiers is Array or rule.modifiers.is_empty():
            return false
        for modifier in rule.modifiers:
            if not Modifiers.valid_spec(modifier) or modifier.has("stacks"): return false
    return true

# Status-gated modifiers update on add/remove/expiry. Conditions that depend
# on fluctuating Qi, targets or attack history are deliberately not allowed.
func _status_condition(spec: Variant, depth: int = 0) -> bool:
    if depth > 8 or not spec is Dictionary or spec.is_empty(): return false
    if spec.has("type"):
        return spec.size() == 2 and spec.type in ["self_status","has_status"] and spec.get("value") is String and not str(spec.value).is_empty()
    if spec.has("not"):
        return spec.size() == 1 and _status_condition(spec["not"], depth + 1)
    for key in ["all","any"]:
        if spec.has(key):
            if spec.size() != 1 or not spec[key] is Array or spec[key].is_empty(): return false
            for child in spec[key]:
                if not _status_condition(child, depth + 1): return false
            return true
    return false

func get_buff(id: String) -> Dictionary:
    return definitions.get(id,{}).duplicate(true)
