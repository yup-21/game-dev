extends RefCounted
## Isolated QA state: never writes GameSession flags or the formal Story Resource.

signal ambush_revealed

var left_temple: bool = false
var explored_deep_outside: bool = false
var ambush_started: bool = false
var revealed_count: int = 0
var discovered_landmarks: Array[String] = []

func on_leave_hall() -> void:
	left_temple = true

func discover(landmark_id: String) -> bool:
	if landmark_id.is_empty() or discovered_landmarks.has(landmark_id):
		return false
	discovered_landmarks.append(landmark_id)
	if left_temple and landmark_id in ["cart_traces", "broken_bridge"]:
		explored_deep_outside = true
	return true

func on_enter_hall(previous_zone_id: String) -> bool:
	if previous_zone_id != "temple_courtyard" or not left_temple:
		return false
	if not explored_deep_outside or ambush_started:
		return false
	ambush_started = true
	revealed_count += 1
	ambush_revealed.emit()
	return true
