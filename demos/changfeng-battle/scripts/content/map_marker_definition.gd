@tool
class_name WuxiaMapMarkerDefinition
extends Resource
## Editor-placed map anchors (spawns, triggers and VFX); no gameplay mutation.
@export var marker_id: String = ""
@export_enum("spawn", "story_trigger", "vfx_anchor") var marker_kind: String = "spawn"
@export var position: Vector2 = Vector2.ZERO
@export_range(0.0, 300.0, 1.0) var radius: float = 32.0

func to_record() -> Dictionary:
    if not marker_id.is_valid_identifier() or marker_kind not in ["spawn","story_trigger","vfx_anchor"] or \
            not is_finite(position.x) or not is_finite(position.y) or \
            not is_finite(radius) or radius < 0.0 or radius > 300.0:
        return {}
    return {"id":marker_id,"kind":marker_kind,
        "position":[position.x,position.y],"radius":radius}
