extends SceneTree
## Deterministic path workload and read-only profiling baseline.
## Timings are informational: CI machines do not have stable CPU budgets.
const Space = preload("res://scripts/battle_spatial_service.gd")
var failures := 0

func _check(ok: bool, detail: String) -> void:
    if not ok:
        failures += 1
        push_error("SPATIAL_BENCH: " + detail)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var space = Space.new()
    _check(space.bake.error.is_empty(), "authored terrain loads")
    if not space.bake.error.is_empty():
        quit(1)
        return
    var centre: Vector2 = space.bake.cell_center(Vector2i(5, 4))
    var start: Vector2 = centre + Vector2(-25.0, 0.0)
    var target: Vector2 = centre + Vector2(25.0, 0.0)
    space.set_actors({42: {"position":centre, "radius":8.0, "alive":true}})
    space.diagnostics_enabled = true
    space.reset_diagnostics()
    var traced: PackedVector2Array = space.find_path(start, target, 8.0)
    var repeated: PackedVector2Array = space.find_path(start, target, 8.0)
    var profile: Dictionary = space.diagnostic_snapshot()
    _check(repeated == traced, "reused visibility graph preserves route")
    _check(traced.size() >= 3, "close-quarter detour exists")
    _check(int(profile.path_queries) == 2 and int(profile.graph_builds) == 1
        and int(profile.graph_reuses) == 1,
        "unchanged actor positions reuse the built graph")
    space.set_actors({42: {"position":centre + Vector2(0, 1), "radius":8.0, "alive":true}})
    space.find_path(start, target, 8.0)
    _check(int(space.diagnostic_snapshot().graph_builds) == 2,
        "moving an obstacle invalidates the cached graph")
    space.set_actors({42: {"position":centre, "radius":8.0, "alive":true}})
    _check(int(profile.segment_queries) > 0 and int(profile.max_nodes) >= 3,
        "profile observes real edge testing")
    space.diagnostics_enabled = false
    var timings: Array[int] = []
    for _warmup in range(8):
        space.find_path(start, target, 8.0)
    for _sample in range(48):
        var started_us: int = Time.get_ticks_usec()
        var route: PackedVector2Array = space.find_path(start, target, 8.0)
        timings.append(Time.get_ticks_usec() - started_us)
        _check(route.size() >= 3, "measured route remains valid")
    timings.sort()
    var mid: int = timings.size() / 2
    var p95_index: int = mini(timings.size() - 1, ceili(float(timings.size()) * 0.95) - 1)
    # Compare reordered approach candidates against the original ring/sector
    # scan so an optimization cannot silently change the chosen tactical spot.
    var source: Vector2 = space.bake.cell_center(Vector2i(4, 4))
    var enemy: Vector2 = space.bake.cell_center(Vector2i(6, 4))
    space.set_actors({17: {"position":enemy, "radius":8.0, "alive":true}})
    space.diagnostics_enabled = true
    space.reset_diagnostics()
    var optimized: Dictionary = space.find_attack_approach(
        source, enemy, 0.0, 90.0, 180.0, 8.0, 8.0, 0, 17, true)
    var approach_stats: Dictionary = space.diagnostic_snapshot()
    space.diagnostics_enabled = false
    var reference: Dictionary = _legacy_approach(space, source, enemy)
    _check(not optimized.is_empty() and not reference.is_empty(),
        "approach fixture yields a legal attack position")
    if not optimized.is_empty() and not reference.is_empty():
        _check(Vector2(optimized.position).distance_to(Vector2(reference.position)) < 0.01
            and absf(float(optimized.cost) - float(reference.cost)) < 0.01,
            "branch-and-bound preserves legacy attack landing and cost")
    _check(int(approach_stats.approach_paths) < int(approach_stats.approach_candidates),
        "approach lower bound avoids unnecessary A* queries")
    print("SPATIAL_BENCH p50_us=%d p95_us=%d max_us=%d graph_nodes=%d pairs=%d failures=%d"
        % [timings[mid], timings[p95_index], timings[-1],
        int(profile.max_nodes), int(profile.candidate_pairs), failures])
    quit(1 if failures > 0 else 0)

func _legacy_approach(space, source: Vector2, target: Vector2) -> Dictionary:
    var best: Dictionary = {}
    for ring in range(3):
        var edge_distance: float = 90.0 - 90.0 * float(ring) / 2.0
        var center_distance: float = edge_distance + 16.0
        for sector in range(48):
            var angle: float = TAU * float(sector) / 48.0
            var point: Vector2 = target + Vector2(cos(angle), sin(angle)) * center_distance
            if not space.is_valid_position(point, 8.0, 0):
                continue
            if not space.attack_in_range(point, target, 0.0, 90.0, 8.0, 8.0):
                continue
            var lower: float = source.distance_to(point)
            if lower > 180.0 + 0.001:
                continue
            if not best.is_empty() and lower >= float(best.cost) - 0.001:
                continue
            if not space.attack_line_clear(point, target, [0, 17]):
                continue
            var path: PackedVector2Array = space.find_path(source, point, 8.0, 0)
            if path.is_empty():
                continue
            var cost: float = space.path_length(path)
            if cost > 180.0 + 0.001:
                continue
            if best.is_empty() or cost < float(best.cost) - 0.001:
                best = {"position":point, "path":path, "cost":cost}
    return best
