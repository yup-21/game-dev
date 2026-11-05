extends Marker2D
## Place/move this marker in the native scene; configure its connection in Inspector.

@export var target_zone_id: String = ""
@export var target_entry_id: String = ""
@export var hint: String = "前往下一场景"
@export_range(30.0, 200.0) var interaction_radius: float = 90.0
