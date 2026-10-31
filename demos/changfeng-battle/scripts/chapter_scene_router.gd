extends RefCounted
## Whitelisted scene templates; chapter content never executes arbitrary scene paths.
const PATHS := {
    "menu":"res://opening.tscn",
    "story":"res://opening.tscn",
    "battle":"res://battle_hd2d.tscn",
    "aftermath":"res://demo_result.tscn",
    "complete":"res://demo_result.tscn"
}

static func path_for(phase: String) -> String:
    return str(PATHS.get(phase,""))
