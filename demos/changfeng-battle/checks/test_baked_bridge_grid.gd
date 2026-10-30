extends SceneTree
## Regression for the hand-authored 15x10 orthographic battle map.
const MapBake = preload("res://scripts/map_bake.gd")
const Model = preload("res://scripts/battle_model.gd")
const Scenario = preload("res://scripts/scenario_director.gd")
var failures := 0
var checks := 0

func _check(ok: bool, reason: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("BRIDGE_BAKE: " + reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var path := MapBake.DEFAULT_PATH
    var baked = MapBake.new(path)
    _check(baked.error.is_empty() and baked.id=="rainy_bridge",
        "baked bridge JSON parses and validates")
    _check(baked.tiles.size()==150 and baked.terrain.size()==150,
        "every square of 15x10 has a tile and authoritative terrain")
    _check(baked.step.x==90.0 and baked.step.y==68.0
        and baked.image_rotation_degrees==-6.0 and baked.image_scale>=1.1,
        "flat orthographic tile lattice and independently rotated painting")
    var rows_align := true
    var hitboxes_roundtrip := true
    var blocked_rejected := true
    for y in range(10):
        for x in range(15):
            var point := Vector2i(x,y)
            var center: Vector2=baked.cell_center(point)
            if absf(center.y-baked.cell_center(Vector2i(0,y)).y)>0.001:
                rows_align=false
            if baked.cell_at_screen(center,false)!=point:
                hitboxes_roundtrip=false
            if baked.is_walkable(point) and baked.cell_at_screen(center,true)!=point:
                hitboxes_roundtrip=false
            if not baked.is_walkable(point) and baked.cell_at_screen(center,true)!=Vector2i(-1,-1):
                blocked_rejected=false
            var box: Rect2=baked.cell_rect(point)
            if not box.has_point(center) or box.size!=baked.step:
                hitboxes_roundtrip=false
    _check(rows_align,"all tile rows are truly horizontal, not a 45-degree diamond")
    _check(hitboxes_roundtrip,"150/150 pixel-to-grid and grid-to-pixel tests match")
    _check(blocked_rejected,"river, bamboo and stone never snap to a legal cell")
    _check(not baked.is_walkable(Vector2i(7,8))
        and baked.terrain[Vector2i(7,8)]=="water",
        "false lower-river ford is absent")
    var unbroken := true
    for x in range(5,11):
        if not baked.is_walkable(Vector2i(x,4)) or baked.terrain[Vector2i(x,4)]!="bridge":
            unbroken=false
    _check(unbroken,"six full wooden bridge cells form one horizontal playable crossing")
    _check(baked.cell_at_screen(Vector2(1590,30))==Vector2i(-1,-1),
        "clicking outside the authored grid does not teleport a unit")
    # An explicit path is required: no only-visual bridge.
    var m=Model.new()
    var quick: Dictionary={"map_definition_path":path}
    m.reset(2026,-1,"tingfeng",quick)
    _check(m.state.outcome=="playing" and m.state.map_definition_path==path
        and m.state.terrain==baked.terrain,
        "BattleModel consumes the exact baked terrain, not the old implicit river")
    # Leave bridge unoccupied for the *terrain* path test; normal occupied
    # checks are independently enforced by the combat model.
    m.state.get_actor(0).cell=Vector2i(2,3)
    m.state.get_actor(1).cell=Vector2i(13,3)
    var path_across: Array=m.state.find_path(Vector2i(3,4),Vector2i(12,4))
    var crossed: bool=path_across.size()>0 and path_across.has(Vector2i(7,4))
    var all_passable := true
    for point in path_across:
        if not m.state.passable(Vector2i(point)):
            all_passable=false
    _check(crossed and all_passable, "crossing route connects both shores through the bridge")
    _check(m.state.find_path(Vector2i(3,4),Vector2i(7,8)).is_empty(),
        "movement cannot navigate into painted river rapids")
    var old=Model.new()
    _check(old.state.terrain[Vector2i(7,8)]=="ford"
        and old.state.map_definition_path.is_empty(),
        "pure rules fixtures retain their original deterministic terrain")
    var director=Scenario.new()
    var opts: Dictionary=director.battle_options("escort_ambush")
    _check(opts.get("map_definition_path","")==path,
        "the first act declares its own map resource")
    var story=Model.new()
    story.reset(2026,-1,"tingfeng",opts)
    _check(story.state.outcome=="playing" and story.state.actors.size()==6,
        "all six scene actors have valid painted-road or bridge spawns")
    for actor in story.state.actors:
        _check(story.state.passable(actor.cell)
            and baked.cell_at_screen(baked.cell_center(actor.cell))==actor.cell,
            "spawn foot matches visible walkable painting: "+str(actor.id))
    var packed: PackedScene=load("res://battle_hd2d.tscn")
    var scene=packed.instantiate()
    root.add_child(scene)
    await process_frame
    var painted=scene.get("illustrated_map")
    _check(painted!=null and painted.bake.tiles.size()==150,
        "real HD-2D scene owns the baked grid projection")
    if painted!=null:
        var model=scene.get("model")
        _check(painted.picture.rotation_degrees==-6.0 and painted.picture.texture!=null,
            "runtime artwork rotated to level real wooden bridge")
        _check(model.state.terrain==baked.terrain,
            "presentation and gameplay share precisely the same 150 tile types")
        for cell in baked.terrain:
            var px: Vector2=painted.point_for_cell(cell)
            if painted.cell_from_screen(px,model.state.terrain)!=baked.cell_at_screen(px,true):
                hitboxes_roundtrip=false
        _check(hitboxes_roundtrip,
            "all painted click targets agree with authoritative hit polygons")
        _check(not painted.debug_grid.visible,
            "debug overlay stays invisible during normal combat")
        painted.set_debug_grid(true)
        _check(painted.debug_grid.visible and painted.debug_grid.get_child_count()>=450,
            "F3 calibration overlay renders 150 tiles, each with line/fill and label")
        painted.set_debug_grid(false)
        _check(not painted.debug_grid.visible,
            "calibration grid can be hidden without touching battle rules")
    scene.queue_free()
    await process_frame
    print("BRIDGE_BAKE_PASS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures>0 else 0)
