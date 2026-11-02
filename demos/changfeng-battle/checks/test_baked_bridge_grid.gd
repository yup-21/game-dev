extends SceneTree
## New painted walkable contour is the authority for GRID and FREE alike.
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
    var resource := load(path) as WuxiaMapDefinition
    var baked := MapBake.new(path)
    _check(resource != null and not resource.walkable_outline.is_empty(),
        "bridge is a painted polygon Resource, never the former tile mask")
    _check(baked.error.is_empty() and baked.id == "rainy_bridge"
        and baked.polygon_mode and baked.walkable_outline.size() >= 3,
        "native map loads with paint-aligned walkable contour")
    _check(baked.tiles.size() == 150 and baked.terrain.size() == 150
        and baked.scene_art != null and baked.scene_art.valid_for(Vector2i(1600,1000)),
        "one 1600x1000 layered painting bakes the 15x10 tactical index")
    var hitboxes_roundtrip := true
    var blocked_rejected := true
    var passable_count := 0
    for y in range(10):
        for x in range(15):
            var cell := Vector2i(x,y)
            var center: Vector2 = baked.cell_center(cell)
            if baked.cell_at_screen(center,false) != cell:
                hitboxes_roundtrip = false
            if baked.is_walkable(cell):
                passable_count += 1
                if baked.cell_at_screen(center,true) != cell:
                    hitboxes_roundtrip = false
            elif baked.cell_at_screen(center,true) != Vector2i(-1,-1):
                blocked_rejected = false
    _check(hitboxes_roundtrip and blocked_rejected,
        "pixel hit tests, cell feet and locked terrain agree")
    _check(passable_count > 12 and passable_count < 100,
        "walking area is a finite strip, not the entire painting")
    _check(not baked.is_walkable(Vector2i(7,9))
        and baked.cell_at_screen(Vector2(1590,30)) == Vector2i(-1,-1),
        "outside bridge and distant painting cannot be walked upon")
    _check(not baked.is_walkable_point(Vector2(800,900),8.0)
        and baked.segment_blocked(Vector2(800,510), Vector2(800,900),8.0),
        "FREE movement respects the identical walkable contour")
    var encounter := Scenario.new().battle_options("escort_ambush")
    _check(str(encounter.get("map_definition_path","")) == path,
        "story encounter selects the new painted map")
    var story := Model.new()
    story.reset(2026,-1,"tingfeng",encounter)
    _check(story.state.outcome=="playing" and story.state.actors.size()==6,
        "3v3 actors spawn onto the native painted map")
    for actor in story.state.actors:
        _check(story.state.passable(actor.cell)
            and baked.is_walkable_point(actor.position,8.0),
            "actor feet are inside the walkable image contour: "+str(actor.id))
    var scene := load("res://battle_hd2d.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var painted = scene.get("illustrated_map")
    _check(painted != null and painted.bake.polygon_mode,
        "live battle uses the same painted map authority")
    if painted != null:
        _check(painted.picture.texture == baked.scene_art.background,
            "rendered bridge layers match the authoring Resource")
        painted.set_debug_grid(true)
        _check(painted.debug_grid.visible
            and painted.debug_grid.get_child_count() >= 450,
            "F3 overlays legal/blocked GRID and painted contour")
        painted.set_debug_grid(false)
    scene.queue_free()
    await process_frame
    print("BRIDGE_BAKE_PASS checks=%d failures=%d" % [checks, failures])
    quit(1 if failures > 0 else 0)
