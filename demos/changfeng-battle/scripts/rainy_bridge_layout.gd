extends RefCounted
## Authored bridge battlefield layout: one contract for rules, hit testing and art.
##
## The painting is a single high-resolution illustration, not a TileMap.
## Each logical cell maps to a hand-calibrated foot contact point on the
## 1600x1000 UI canvas. Keep terrain topology and projection together: a
## future re-paint/re-crop must update these anchors and their regression tests.
const COLS := 15
const ROWS := 10
const PAINTING_SIZE := Vector2i(1586, 992)
const CANVAS_SIZE := Vector2(1600, 1000)
const ART_PATH := "res://assets/scenes/battle/rainy_bridge_battle.webp"
const PICK_RADIUS := 55.0
const BLOCKED_TYPES := ["water", "rock", "bamboo"]

static func make_terrain() -> Dictionary:
    var terrain: Dictionary = {}
    for row in range(ROWS):
        for col in range(COLS):
            terrain[Vector2i(col, row)] = "water" if col == 7 else "grass"
    # The river divides west/east banks except at these authored crossings.
    terrain[Vector2i(7, 4)] = "bridge"
    terrain[Vector2i(7, 8)] = "ford"
    for cell in [Vector2i(4, 1), Vector2i(5, 1), Vector2i(3, 7),
            Vector2i(4, 7), Vector2i(10, 2), Vector2i(11, 7)]:
        terrain[cell] = "rock"
    for cell in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(5, 6),
            Vector2i(9, 7), Vector2i(12, 1), Vector2i(12, 8)]:
        terrain[cell] = "bamboo"
    terrain[Vector2i(13, 4)] = "exit"
    return terrain

static func in_bounds(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS

static func is_walkable(cell: Vector2i, terrain: Dictionary) -> bool:
    return in_bounds(cell) and terrain.has(cell) and str(terrain[cell]) not in BLOCKED_TYPES

static func point_for_cell(cell: Vector2i) -> Vector2:
    return point_for_grid(Vector2(cell))

static func point_for_grid(grid: Vector2) -> Vector2:
    # West bank, bridge/river and east bank have independent authored
    # perspective corrections. Preserve interpolation for smooth walk sprites.
    var x: float = grid.x
    var y: float = grid.y
    if x <= 6.0:
        return Vector2(220.0 + 64.0*x, 200.0 - 20.0*x + 65.0*y)
    if x < 7.0:
        return Vector2(604.0, 80.0 + 65.0*y).lerp(
            Vector2(790.0, 72.0 + 66.0*y), x - 6.0)
    if x == 7.0:
        return Vector2(790.0, 72.0 + 66.0*y)
    if x < 8.0:
        return Vector2(790.0, 72.0 + 66.0*y).lerp(
            Vector2(990.0, 85.0 + 65.0*y), x - 7.0)
    return Vector2(990.0 + 65.0*(x - 8.0), 85.0 + 20.0*(x - 8.0) + 65.0*y)

static func cell_from_screen(screen: Vector2, terrain: Dictionary) -> Vector2i:
    # Invert only walkable floor anchors; painted water and props are not
    # selectable even if they are visually within the landscape.
    var closest := Vector2i(-1, -1)
    var nearest := PICK_RADIUS * PICK_RADIUS
    for cell in terrain:
        var grid_cell := Vector2i(cell)
        if not is_walkable(grid_cell, terrain):
            continue
        var distance := point_for_cell(grid_cell).distance_squared_to(screen)
        if distance < nearest:
            nearest = distance
            closest = grid_cell
    return closest
