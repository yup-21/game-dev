extends RefCounted
## Single project-wide battle/world-art scale contract.
## Vector2 world positions, authored map markers and painted map coordinates
## are in logical 2D world pixels. One combat distance unit is always 80px,
## regardless of the 15x10 tactical terrain sampling lattice.
const PIXELS_PER_UNIT := 80.0
const ACTOR_HEIGHT_UNITS := 2.5
const FOOTPRINT_RADIUS_UNITS := 0.30
const SAFE_FRAME_MARGIN_PX := 8
const REFERENCE_HEIGHT_MIN_FRACTION := 0.35
const REFERENCE_HEIGHT_MAX_FRACTION := 0.95

static func to_pixels(units: float) -> float:
    return units * PIXELS_PER_UNIT

static func to_units(world_pixels: float) -> float:
    return world_pixels / PIXELS_PER_UNIT

static func actor_height_pixels() -> float:
    return to_pixels(ACTOR_HEIGHT_UNITS)

static func footprint_radius_pixels() -> float:
    return to_pixels(FOOTPRINT_RADIUS_UNITS)

static func valid_map_pixels_per_unit(value: float) -> bool:
    return is_finite(value) and absf(value - PIXELS_PER_UNIT) <= 0.001
