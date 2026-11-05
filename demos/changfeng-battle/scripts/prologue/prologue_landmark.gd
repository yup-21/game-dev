extends Marker2D
## Outside exploration milestone: investigate once, then return to the temple.

@export var landmark_id: String = ""
@export var hint: String = "调查线索"
@export_range(30.0, 200.0) var interaction_radius: float = 95.0
