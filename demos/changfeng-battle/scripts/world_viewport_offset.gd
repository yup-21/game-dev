extends RefCounted
## Presentation-only viewport shift in *world pixels*. Does not mutate map
## geometry, feet coordinates, path costs, collision or combat unit scale.
## CanvasLayer scenery ignores Camera2D, so world parents must apply this
## offset (plus temporary visual shake) and reverse it for pointer queries.
const VIEWPORT_SIZE := Vector2(1600.0, 1000.0)

static func world_offset(focus: Vector2, world_size: Vector2,
        view_size: Vector2 = VIEWPORT_SIZE) -> Vector2:
    var available := Vector2(maxf(0.0, world_size.x - view_size.x),
        maxf(0.0, world_size.y - view_size.y))
    if available == Vector2.ZERO:
        return Vector2.ZERO
    var top_left := Vector2(
        clampf(focus.x - view_size.x * 0.5, 0.0, available.x),
        clampf(focus.y - view_size.y * 0.5, 0.0, available.y))
    return -top_left

static func screen_to_world(screen: Vector2, stage_offset: Vector2) -> Vector2:
    return screen - stage_offset

static func world_to_screen(point: Vector2, stage_offset: Vector2) -> Vector2:
    return point + stage_offset
