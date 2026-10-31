extends SceneTree
## Formal entry audit: menu quick mode and chapter route share Resource catalogs.
const Native = preload("res://scripts/content/content_registry.gd")
const Director = preload("res://scripts/scenario_director.gd")
const Model = preload("res://scripts/battle_model.gd")
const SceneRouter = preload("res://scripts/chapter_scene_router.gd")
const Factory = preload("res://scripts/character_factory.gd")
const Role = preload("res://scripts/opening_role_sprite.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("R40_ENTRY: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var native = Native.new()
    var director = Director.new()
    check(native.load_error.is_empty() and director.load_error.is_empty(),
        "native manifest and encounter catalog load")
    check(native.entries("encounter").has("r40_quick_duel"),
        "menu quick encounter is native Resource")
    for id in ["r40_quick_duel","escort_ambush","river_watch_ambush",
            "r24_fog_pass_battle","r26_recruitment_trial_battle"]:
        var options: Dictionary=director.battle_options(id)
        check(not options.is_empty() and str(options.get("map_definition_path","")).ends_with(".tres"),
            "native encounter map references Resource: " + id)
    var hero = Factory.new().create_runtime("shen_changfeng")
    check(hero != null and hero.inventory.stacks.get("healing_powder",0) == 2
        and hero.inventory.stacks.get("breath_pill",0) == 1,
        "quick-play consumables come from the character Resource")
    var session=root.get_node_or_null("GameSession")
    check(session != null, "session autoload exists")
    if session == null:
        quit(1)
        return
    check(session.start_quick_battle() and session.phase=="quick_battle",
        "menu quick action enters registered encounter")
    var options: Dictionary=session.encounter_options()
    check(options.get("combatants",[]).size()==2
        and options.get("inventories",{}).has(0)
        and options.get("map_definition_path","")=="res://data/maps/rainy_bridge.tres",
        "quick roster, character loadout and map derive from typed content")
    var model=Model.new()
    model.reset(session.encounter_seed(),-1,"tingfeng",options)
    check(model.state.outcome=="playing" and model.state.actors.size()==2
        and model.state.map_definition_path.ends_with(".tres"),
        "quick fight enters one authoritative BattleModel")
    session.start_new_game()
    check(session.chapter_id=="rain_escort_prologue"
        and session.director.encounter("escort_ambush").combatants.size()==6,
        "story begins through the same registered encounter system")
    check(SceneRouter.path_for("battle")=="res://battle_hd2d.tscn",
        "both modes use canonical battle scene")
    var sprite=Role.new()
    root.add_child(sprite)
    check(sprite.configure("shen_changfeng"),"story role uses native character art")
    check(sprite.animation_player != null
        and sprite.animation_player.has_animation("move"),
        "story sprite animation is owned by AnimationPlayer")
    sprite.set_motion(Vector2.RIGHT,0.15)
    check(sprite.animation_player.current_animation=="move"
        and sprite.body.frame_coords.y==1,
        "motion advances native move track")
    sprite.set_motion(Vector2.ZERO,0.0)
    check(sprite.animation_player.current_animation=="idle"
        and sprite.body.frame_coords.y==0,
        "idle uses native track, not a script frame counter")
    sprite.free()
    check(not FileAccess.file_exists("res://scripts/battle_spatial_waypoint.gd"),
        "obsolete PR57 pathfinder deleted")
    print("R40_NATIVE_ENTRY_PASS failures=",failures)
    quit(1 if failures else 0)
