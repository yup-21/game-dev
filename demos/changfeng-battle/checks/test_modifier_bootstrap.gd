extends SceneTree
const Attributes = preload("res://scripts/attribute_system.gd")
const Modifiers = preload("res://scripts/stat_modifier_system.gd")
const Actor = preload("res://scripts/combatant_state.gd")
func _initialize() -> void:
    var actor = Actor.new()
    Attributes.new().configure(actor)
    var valid: bool = actor.stats.get("attack",-1) == 10 and Modifiers.valid_spec({"stat":"STR","op":"flat","value":1})
    print("R13_BOOTSTRAP_PASS ",valid)
    quit(0 if valid else 1)
