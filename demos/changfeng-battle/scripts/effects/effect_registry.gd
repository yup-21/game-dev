extends RefCounted
## Type -> handler dispatch. No code evaluation from skill/card data.
const Native = preload("res://scripts/content/content_registry.gd")
const Basic = preload("res://scripts/effects/basic_effect_handler.gd")
const BUILTINS = ["gain_qi", "heal_hp", "add_shield", "apply_status", "consume_status"]
# Stateless handlers may be reused across battle instances. The registry map
# is copied, so one battle cannot mutate another battle's dispatch table.
static var _default_handlers_ready: bool = false
static var _default_handlers: Dictionary = {}
var handlers: Dictionary = {}
var load_error: String = ""

func _init(manifest_path: String = "res://data/content_manifest.tres") -> void:
    if manifest_path == Native.DEFAULT_MANIFEST and _default_handlers_ready:
        handlers = _default_handlers.duplicate()
        return
    var basic = Basic.new()
    for effect_type in BUILTINS:
        handlers[effect_type] = basic
    var native = Native.new(manifest_path)
    if not native.load_error.is_empty():
        load_error = native.load_error
        return
    for spec in native.entries("effect_handler").values():
        var kind: String = str(spec.get("effect_type", ""))
        var path: String = str(spec.get("script_path", ""))
        if kind.is_empty() or handlers.has(kind) or not path.begins_with("res://scripts/effects/") or \
                not ResourceLoader.exists(path, "Script"):
            load_error = "Invalid or duplicate effect handler: " + kind
            return
        var script: Script = ResourceLoader.load(path, "Script")
        if script == null or not script.can_instantiate():
            load_error = "Effect handler cannot instantiate: " + kind
            return
        var instance = script.new()
        if not instance.has_method("valid_spec") or not instance.has_method("execute"):
            load_error = "Effect handler lacks contract: " + kind
            return
        handlers[kind] = instance
    if manifest_path == Native.DEFAULT_MANIFEST:
        _default_handlers = handlers.duplicate()
        _default_handlers_ready = true

func supports(effect_type: String) -> bool:
    return handlers.has(effect_type)

func valid_custom(effect: Dictionary) -> bool:
    var handler = handlers.get(str(effect.get("type", "")), null)
    return handler != null and bool(handler.valid_spec(effect))

func dispatch(resolver, source: int, target_id: int,
        effect: Dictionary, choice: Dictionary) -> bool:
    var handler = handlers.get(str(effect.get("type", "")), null)
    if handler == null:
        return false
    handler.execute(resolver, source, target_id, effect, choice)
    return true
