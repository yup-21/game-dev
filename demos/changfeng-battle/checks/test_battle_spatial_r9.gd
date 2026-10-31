extends SceneTree
## R9: FREE landing, GRID LOS, forced displacement and preview cache.
const Model = preload("res://scripts/battle_model.gd")
const Geometry = preload("res://scripts/battle_spatial_facade.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("R9_SPATIAL: " + message)

func _run() -> void:
    var model = Model.new()
    model.reset(2026, -1, "tingfeng",
        {"map_definition_path":"res://data/maps/rainy_bridge.json","spatial_mode":"GRID"})
    var actor=model.state.get_actor(0)
    var target=model.state.get_actor(1)
    var grid=Geometry.new(model.state)
    var preview: Dictionary=grid.forced_displacement(target,actor,1,false)
    if not preview.is_empty():
        model.resolver.force_move(actor.id,target.id,{"max_distance":1,"direction":"away"})
        _check(target.cell==Vector2i(preview.cell),
            "GRID knockback shares exact axis-constrained preview")
    _check(not grid.can_attack(actor,target,0.0,10.0,true) or
        actor.cell.x==target.cell.x or actor.cell.y==target.cell.y,
        "GRID LOS rejects unsupported diagonal rays")

    model.reset(2026, -1, "tingfeng",
        {"map_definition_path":"res://data/maps/rainy_bridge.json","spatial_mode":"FREE"})
    actor=model.state.get_actor(0)
    target=model.state.get_actor(1)
    var free=Geometry.new(model.state)
    var revision: int=int(model.state.revision)
    var landing: Dictionary=free.plan_free_landing(actor,actor.position+Vector2(20,0))
    _check(bool(landing.get("success",false)) and
        PackedVector2Array(landing.get("path",PackedVector2Array())).size()>=2,
        "FREE landing exposes collision checked route")
    _check(model.state.revision==revision,"geometry planning cannot change revision")
    var path1: PackedVector2Array=model.preview_free_path(actor.id,actor.position+Vector2(20,0))
    var path2: PackedVector2Array=model.preview_free_path(actor.id,actor.position+Vector2(20,0))
    _check(path1==path2 and not model._free_preview_cache.is_empty(),
        "same revision and point reuse cached preview")
    var forced: Dictionary=free.forced_displacement(target,actor,1,false)
    if not forced.is_empty():
        model.resolver.force_move(actor.id,target.id,{"max_distance":1,"direction":"away"})
        _check(target.position.distance_to(Vector2(forced.position))<0.3,
            "FREE forced displacement matches the preview endpoint")
    print("R9_SPATIAL_PASS failures=%d" % failures)
    quit(1 if failures else 0)
