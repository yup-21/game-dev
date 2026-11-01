@tool
class_name WuxiaActionClipDefinition
extends Resource
## Editor-authored clip phases and optional cosmetic cue windows.

@export var clip_id: String = ""
@export var duration_sec: float = 0.4
@export var startup_sec: float = 0.0
@export var active_sec: float = 0.4
@export var recovery_sec: float = 0.0
@export var cancel_window: WuxiaActionTimeWindow
@export var reaction_window: WuxiaActionTimeWindow
@export var invulnerable_window: WuxiaActionTimeWindow
@export var cues: Array[Resource] = []

func valid_clip() -> bool:
    if clip_id.is_empty() or not is_finite(duration_sec) or duration_sec <= 0.0:
        return false
    for value in [startup_sec, active_sec, recovery_sec]:
        if not is_finite(value) or value < 0.0:
            return false
    if absf(startup_sec + active_sec + recovery_sec - duration_sec) > 0.002:
        return false
    for window in [cancel_window, reaction_window, invulnerable_window]:
        if window != null and not window.valid_for(duration_sec):
            return false
    for cue in cues:
        if not cue is WuxiaActionCueDefinition or not cue.valid_for(duration_sec):
            return false
    return true

func window(kind: String) -> WuxiaActionTimeWindow:
    match kind:
        "cancel": return cancel_window
        "reaction": return reaction_window
        "invulnerable": return invulnerable_window
    return null
