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
    var profile: Dictionary = space.diagnostic_snapshot()
    _check(traced.size() >= 3, "close-quarter detour exists")
    _check(int(profile.path_queries) == 1 and int(profile.graph_builds) == 1,
        "profile observes exactly one graph build")
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
    print("SPATIAL_BENCH p50_us=%d p95_us=%d max_us=%d graph_nodes=%d pairs=%d failures=%d"
        % [timings[mid], timings[p95_index], timings[-1],
        int(profile.max_nodes), int(profile.candidate_pairs), failures])
    quit(1 if failures > 0 else 0)
