@tool
class_name WuxiaMapMarkerDefinition
extends Resource
## Editor-placed map anchors (spawns, triggers and VFX); no gameplay mutation.
@export var marker_id: String = ""
@export_enum("spawn", "story_trigger", "vfx_anchor", "zone_exit") var marker_kind: String = "spawn"
@export var position: Vector2 = Vector2.ZERO
@export_range(0.0, 300.0, 1.0) var radius: float = 32.0
## A zone exit stores routing metadata only; the story scene switcher is not
## implemented yet. Direction refers to WORLD coordinates, never sheet rows.
@export_enum("none", "north", "south", "east", "west") var exit_side: String = "none"
@export var target_zone_id: String = ""
@export var target_entry_id: String = ""

func to_record() -> Dictionary:
    if not marker_id.is_valid_identifier() or marker_kind not in ["spawn","story_trigger","vfx_anchor","zone_exit"] or \
            not is_finite(position.x) or not is_finite(position.y) or \
            not is_finite(radius) or radius < 0.0 or radius > 300.0:
        return {}
    var result := {"id":marker_id,"kind":marker_kind,
        "position":[position.x,position.y],"radius":radius}
    if marker_kind == "zone_exit":
        if exit_side not in ["north", "south", "east", "west"] or \
                not target_zone_id.is_valid_identifier() or \
                not target_entry_id.is_valid_identifier():
            return {}
        result["exit_side"] = exit_side
        result["target_zone_id"] = target_zone_id
        result["target_entry_id"] = target_entry_id
    return result
