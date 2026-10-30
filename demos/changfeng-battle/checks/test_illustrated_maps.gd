extends SceneTree
## Validate actual 2D battle presentation, role anchoring and story scene.
const SceneMap = preload("res://scripts/illustrated_battle_map.gd")
var failures := 0
var checks := 0

func _check(ok: bool, why: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("ILLUSTRATED_MAP: " + why)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: Node = load("res://battle_hd2d.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var model = scene.get("model")
    var painted = scene.get("illustrated_map")
    _check(painted!=null and painted.picture.texture!=null,
        "battle must contain a complete screen-space painted scene")
    _check(scene.get_node_or_null("River")==null and
        scene.get_node_or_null("WuxiaScenery")==null and
        scene.get_node_or_null("Ground_6_4")==null,
        "no procedural 3D terrain or distant background is constructed")
    _check(painted.actors.size()==2 and painted.actors[0].get_node("ActionSprite").texture!=null,
        "duel actors are visual 2D Sprite2D nodes with real atlas")
    var left: Vector2=SceneMap.point_for_cell(Vector2i(6,4))
    var bridge: Vector2=SceneMap.point_for_cell(Vector2i(7,4))
    var right: Vector2=SceneMap.point_for_cell(Vector2i(8,4))
    _check(left.x<bridge.x and bridge.x<right.x,
        "bridge endpoints align with foot anchors of the painting")
    var crossing: Vector2=SceneMap.point_for_cell(Vector2i(7,8))
    _check(crossing.y>bridge.y+210,
        "ford crossing is in the foreground, separated from the bridge")
    _check(painted.cell_from_screen(bridge,model.state.terrain)==Vector2i(7,4),
        "map projection inverses the real traversable bridge")
    _check(painted.cell_from_screen(crossing,model.state.terrain)==Vector2i(7,8),
        "map projection inverses the real traversable ford")
    _check(painted.cell_from_screen(Vector2(1550,40),model.state.terrain)==Vector2i(-1,-1),
        "non-playable off-map art does not resolve to movement")
    var hero = painted.actors[0].get_node("ActionSprite") as Sprite2D
    _check(hero.hframes==6 and hero.vframes==4,
        "2D actor preserves original action atlas frame convention")
    var seq = model.state.revision
    painted.update_actor(0,Vector2(6,4),13,false,true)
    _check(hero.frame==13 and model.state.revision==seq,
        "visual animation updates sprite without modifying the model")
    scene.queue_free()
    await process_frame
    var session=root.get_node_or_null("GameSession")
    session.start_new_game()
    session.record_story_event("obtain_fragment")
    _check(session.begin_encounter(),"enter 3v3 story battle")
    var battle: Node = load("res://battle_hd2d.tscn").instantiate()
    root.add_child(battle)
    await process_frame
    var bmap = battle.get("illustrated_map")
    _check(bmap!=null and bmap.actors.size()==6,"all six characters shown as 2D actor sprites")
    _check(battle.get("model").state.actors.size()==6,
        "story battle remains 3v3 and preserves existing rules")
    battle.queue_free()
    await process_frame
    session.return_to_menu()
    var opening: Node2D = load("res://opening.tscn").instantiate()
    root.add_child(opening)
    await process_frame
    _check(opening.story.load_error.is_empty(),"opening story loads unchanged")
    opening.call("_enter_new_game")
    opening.story.skip_cinematic()
    _check(opening.story.phase=="explore","first-act exploration uses existing dialogue mechanics")
    _check(Vector2(1050,560).distance_to(Vector2(opening.get("player_pos")))>175.0,
        "hero starts away from escort interaction point")
    opening.queue_free()
    await process_frame
    print("ILLUSTRATED_MAP_PASS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures>0 else 0)
