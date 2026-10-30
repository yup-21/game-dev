extends RefCounted
## Four-way combat facing, measured on the logical battle grid.
## X grows east; Y grows south. Tie breaks use X for deterministic diagonals.
const EAST := Vector2i(1,0)
const WEST := Vector2i(-1,0)
const NORTH := Vector2i(0,-1)
const SOUTH := Vector2i(0,1)

static func from_delta(delta: Vector2i, fallback: Vector2i = EAST) -> Vector2i:
    if delta == Vector2i.ZERO:
        return fallback if is_cardinal(fallback) else EAST
    if absi(delta.x) >= absi(delta.y):
        return EAST if delta.x > 0 else WEST
    return SOUTH if delta.y > 0 else NORTH

static func is_cardinal(direction: Vector2i) -> bool:
    return direction in [EAST,WEST,NORTH,SOUTH]

static func yaw(direction: Vector2i) -> float:
    # Arrow's local tip points +Z; the map's positive Y points +Z.
    return atan2(float(direction.x),float(direction.y))

static func name_of(direction: Vector2i) -> String:
    if direction == WEST: return "西"
    if direction == NORTH: return "北"
    if direction == SOUTH: return "南"
    return "东"
