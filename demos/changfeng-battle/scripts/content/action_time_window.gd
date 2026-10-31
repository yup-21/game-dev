@tool
class_name WuxiaActionTimeWindow
extends Resource
## Authored visual-only interval; never controls damage or i-frames.

@export var from_sec: float = 0.0
@export var to_sec: float = 0.0

func valid_for(duration_sec: float) -> bool:
    return is_finite(from_sec) and is_finite(to_sec) and from_sec >= 0.0 \
        and from_sec < to_sec and to_sec <= duration_sec + 0.001

func contains(second: float) -> bool:
    return second >= from_sec and second < to_sec
