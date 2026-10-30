extends SceneTree
## Regression: the prologue must load the authoritative multi-party encounter.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("HD2D_STORY: " + message)
    quit(1)

func _run() -> void:
    var session = root.get_node_or_null("GameSession")
    if session == null:
        _fail("GameSession autoload missing")
        return
    session.start_new_game()
    session.record_story_event("obtain_fragment")
    if not session.begin_encounter():
        _fail("prologue encounter was not started")
        return
    var options: Dictionary = session.encounter_options()
    var packed: PackedScene = load("res://battle_hd2d.tscn")
    if packed == null:
        _fail("HD-2D scene missing")
        return
    var scene = packed.instantiate()
    root.add_child(scene)
    await process_frame
    if not bool(scene.get("story_encounter")):
        _fail("story flag not propagated")
        return
    var snap: Dictionary = scene.get("snap")
    if snap.get("actors", []).size() != options.get("combatants", []).size():
        _fail("battle roster differs from scenario")
        return
    var player_count := 0
    for actor in snap.get("actors", []):
        if str(actor.get("controller", "")) == "PLAYER":
            player_count += 1
        var battle_map=scene.get("illustrated_map")
        var id: int=int(actor.id)
        if battle_map==null or not battle_map.actors.has(id) or not battle_map.actors[id] is Node2D:
            _fail("native 2D actor missing: %d" % id)
            return
        if battle_map.actors[id].get_node_or_null("ActionSprite") == null:
            _fail("Sprite2D visual missing for actor: %d" % id)
            return
    if player_count < 2:
        _fail("expected multiple player-controlled units")
        return
    if scene.get("model").state.seed != session.encounter_seed():
        _fail("scenario seed mismatch")
        return
    print("HD2D_STORY_PASS actors=", snap.actors.size(), " players=", player_count)
    quit(0)
