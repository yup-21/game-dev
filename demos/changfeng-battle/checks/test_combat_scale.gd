extends SceneTree
## Scale invariants: illustration, authored atlas and FREE spatial math.
const Scale = preload("res://scripts/combat_scale.gd")
const MapBake = preload("res://scripts/map_bake.gd")
const State = preload("res://scripts/battle_state.gd")
const Spatial = preload("res://scripts/battle_spatial_service.gd")
const Geometry = preload("res://scripts/battle_spatial_facade.gd")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("COMBAT_SCALE: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    check(is_equal_approx(Scale.to_pixels(1.0), 80.0), "one combat unit equals 80 world pixels")
    check(is_equal_approx(Scale.to_units(160.0), 2.0), "roundtrip distance is consistent")
    check(is_equal_approx(Scale.actor_height_pixels(), 200.0), "actor visual height 2.5 units")
    check(is_equal_approx(Scale.footprint_radius_pixels(), 24.0), "footprint radius 0.3 units")
    var path := "res://data/maps/rainy_bridge.tres"
    var map: WuxiaMapDefinition = load(path)
    check(map != null and is_equal_approx(map.pixels_per_unit, Scale.PIXELS_PER_UNIT),
        "map resource scale follows shared contract")
    var mismatched: WuxiaMapDefinition = map.duplicate(true)
    mismatched.pixels_per_unit = 96.0
    check(mismatched.to_record().is_empty(), "mismatched texture map scale rejected")
    var bake = MapBake.new(path)
    check(bake.error.is_empty() and bake.polygon_mode, "polygon map still loads")
    check(is_equal_approx(bake.pixels_per_unit, Scale.PIXELS_PER_UNIT),
        "map bake carries combat scale")
    check(not is_equal_approx(bake.step.x, bake.step.y),
        "tactical grid dimensions are deliberately NOT the physical scale")
    var state = State.new(11)
    state.spatial = Spatial.new(path)
    state.spatial_mode = "FREE"
    var origin := Vector2(400, 420)
    var reach := Scale.to_pixels(1.0) + 2.0 * Scale.footprint_radius_pixels()
    state.actors[0].position = origin
    state.actors[1].position = origin + Vector2(reach, 0)
    var geometry = Geometry.new(state)
    check(is_equal_approx(geometry.unit_distance(), Scale.PIXELS_PER_UNIT),
        "facade world unit matches authored map")
    check(geometry.can_attack(state.actors[0], state.actors[1], 0.0, 1.0, false),
        "one-unit melee range uses surface-to-surface distance")
    state.actors[1].position.x += 0.5
    check(not geometry.can_attack(state.actors[0], state.actors[1], 0.0, 1.0, false),
        "attack outside one-unit footprint gap is rejected")
    var collision = Geometry.new(state)
    check(not collision.can_land(state.actors[0], state.actors[1].position - Vector2(10, 0)),
        "actor footprints cannot overlap")
    for actor_name in ["shen_changfeng", "pursuer_captain", "gu_qingshuang",
            "green_wanderer", "black_blade", "night_assassin"]:
        var profile: WuxiaActorAnimationProfile = load(
            "res://data/native/animations/%s.tres" % actor_name)
        check(profile != null and profile.valid_profile(),
            actor_name + " authored sprite metadata stays valid")
        if profile == null or not profile.valid_profile():
            continue
        var sprite := Sprite2D.new()
        sprite.texture = profile.atlas
        sprite.hframes = profile.columns
        sprite.vframes = profile.rows
        var idle = profile.clip_for("idle")
        var idle_index: int = int(idle.frames[0])
        var fitted: bool = VisualScale.fit(sprite, profile.actor_scale,
            Scale.actor_height_pixels(), profile.feet_adjust, idle_index)
        check(fitted, actor_name + " has a measurable idle silhouette")
        if fitted:
            var bounds: Rect2i = VisualScale._opaque_bounds(
                sprite.texture, sprite.hframes, sprite.vframes, idle_index)
            check(absf(float(bounds.size.y)*sprite.scale.y-Scale.actor_height_pixels()) < 2.0,
                actor_name + " rendered idle silhouette matches world proportion")
        sprite.free()
    print("COMBAT_SCALE_PASS failures=%d" % failures)
    quit(1 if failures else 0)
