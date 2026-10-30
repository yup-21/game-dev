extends SceneTree
## Facing belongs to the authoritative combatant, never an inferred UI pose.
const Model=preload("res://scripts/battle_model.gd")
const Facing=preload("res://scripts/actor_facing.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("ACTOR_FACING: " + message)

func _action(model, actor_id: int, kind: String, target: Variant = null) -> Dictionary:
    for choice in model.legal_actions(actor_id):
        if str(choice.get("kind","")) != kind: continue
        if target is Vector2i and choice.get("target_cell") != target: continue
        if target is int and choice.get("target_id",-1) != target: continue
        return choice
    return {}

func _move_once(destination: Vector2i, expected: Vector2i) -> void:
    var m=Model.new()
    var initial_rev: int=m.state.revision
    var action: Dictionary=_action(m,0,"MOVE",destination)
    _check(not action.is_empty(),"move legal: "+str(destination))
    if action.is_empty(): return
    var result: Dictionary=m.submit(m.request("MOVE",0,{"target_cell":destination}))
    _check(bool(result.get("success",false)),"move accepted: "+str(destination))
    _check(m.state.get_actor(0).facing==expected,"logical facing follows FINAL PATH STEP: "+str(destination))
    _check(m.state.revision==initial_rev+1,"movement uses versioned model action")
    var seen:=false
    for event in result.get("events",[]):
        if event.get("type","")=="MOVE":
            seen=true
            _check(Vector2i(event.get("facing",Vector2i.ZERO))==expected,
                "MOVE event declares final facing")
            var path: Array=event.get("path",[])
            if path.size()>0:
                var prior: Vector2i=Vector2i(event.get("from",Vector2i.ZERO)) if path.size()==1 else Vector2i(path[path.size()-2])
                _check(Facing.from_delta(Vector2i(path.back())-prior)==expected,
                    "facing derives from actual final waypoint, not diagonal chord")
    _check(seen,"movement emits MOVE event")
    _check(m.snapshot(0).actors[0].facing==expected,
        "snapshot exposes facing for the UI")

func _attack(direction: Vector2i) -> void:
    var m=Model.new()
    var attacker=m.state.get_actor(0)
    var target=m.state.get_actor(1)
    target.cell=attacker.cell+direction
    _check(not _action(m,0,"BASIC_ATTACK",1).is_empty(),"basic attack legal: "+str(direction))
    var result: Dictionary=m.submit(m.request("BASIC_ATTACK",0,{"target_id":1}))
    _check(bool(result.get("success",false)),"attack accepted: "+str(direction))
    _check(attacker.facing==direction,"attacker turns to target: "+str(direction))
    var found:=false
    for event in result.get("events",[]):
        if str(event.get("type",""))=="ATTACK_DECLARED":
            found=true
            _check(Vector2i(event.get("facing",Vector2i.ZERO))==direction,
                "attack event carries cardinal facing")
    _check(found,"basic attack emits ATTACK_DECLARED")
    _check(m.snapshot(0).actors[0].facing==direction,"attack facing persisted into snapshot")

func _run() -> void:
    for direction in [Facing.EAST,Facing.WEST,Facing.NORTH,Facing.SOUTH]:
        _check(Facing.is_cardinal(direction),"four canonical directions only")
    _check(Facing.from_delta(Vector2i.ZERO,Facing.NORTH)==Facing.NORTH,
        "zero displacement keeps facing")
    _check(Facing.from_delta(Vector2i(-2,2))==Facing.WEST,
        "diagonal tie breaks predictably on X")
    _check(is_equal_approx(Facing.yaw(Facing.EAST),PI/2.0),
        "east maps to proper terrain pointer yaw")
    var initial=Model.new()
    _check(initial.state.get_actor(0).facing==Facing.EAST
        and initial.state.get_actor(1).facing==Facing.WEST,
        "default teams start facing each other")
    _move_once(Vector2i(5,4),Facing.WEST)
    _move_once(Vector2i(6,3),Facing.NORTH)
    _move_once(Vector2i(6,5),Facing.SOUTH)
    # BFS neighbor order yields left then up; last segment is NORTH,
    # not WEST based on the origin/destination diagonal chord.
    _move_once(Vector2i(5,3),Facing.NORTH)
    for facing in [Facing.EAST,Facing.WEST,Facing.NORTH,Facing.SOUTH]:
        _attack(facing)
    # Direct martial attack goes through the same declare_attack path.
    var martial=Model.new()
    var origin=martial.state.get_actor(0)
    var victim=martial.state.get_actor(1)
    victim.cell=Vector2i(5,4)
    origin.qi_u=100000
    var uid: String=martial.cards.create_instance(origin,"tf_probe","hand")
    var choice: Dictionary={}
    for option in martial.legal_actions(0):
        if (option.get("kind","")=="PLAY_CARD"
                and option.get("card_uid","")==uid
                and option.get("usage_id","")=="probe"
                and option.get("target_id",-1)==1):
            choice=option
    _check(not choice.is_empty(),"martial attack has a real legal target")
    if not choice.is_empty():
        var outcome: Dictionary=martial.submit(martial.request("PLAY_CARD",0,choice))
        _check(bool(outcome.get("success",false)) and origin.facing==Facing.WEST,
            "martial card turns toward victim in same BattleModel pipeline")
    # Pushed actors also face the displacement direction (not the pusher).
    var pushed=Model.new()
    var enemy=pushed.state.get_actor(1)
    pushed.resolver.force_move(0,1,{"direction":"away_from_attacker","max_distance":1})
    _check(enemy.cell==Vector2i(9,4) and enemy.facing==Facing.EAST,
        "forced movement updates pushed actor facing")
    var invalid=pushed.submit(pushed.request("MOVE",0,{"target_cell":Vector2i(30,30)}))
    _check(not invalid.success and pushed.state.get_actor(0).facing==Facing.EAST,
        "invalid action cannot rotate an actor")
    # Native HD-2D scene: visible Sprite2D flip follows authoritative facing.
    var scene=load("res://battle_hd2d.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var visual_actors: Dictionary=scene.get("actor_nodes")
    var protagonist: Node2D=visual_actors.get(0,null) as Node2D
    var opponent: Node2D=visual_actors.get(1,null) as Node2D
    _check(protagonist!=null and opponent!=null,"both native Sprite2D actors in real scene")
    if protagonist!=null and opponent!=null:
        var sprite: Sprite2D=protagonist.get_node_or_null("ActionSprite") as Sprite2D
        var enemy_sprite: Sprite2D=opponent.get_node_or_null("ActionSprite") as Sprite2D
        _check(sprite!=null and enemy_sprite!=null,"painted scene owns two visible action sprites")
        if sprite!=null and enemy_sprite!=null:
            _check(bool(sprite.get_meta("faces_left_unflipped",false)) and bool(enemy_sprite.get_meta("faces_left_unflipped",false)),
                "supplied 6x4 atlases face WEST before flip, unlike generated fallback")
            _check(sprite.flip_h and not enemy_sprite.flip_h,
                "initial east-facing hero and west-facing enemy are mirrored against authored atlas")
            var driver=scene.get("animation_driver")
            driver.set_facing(0,Facing.NORTH)
            _check(sprite.flip_h and driver.facing_for(0)==Facing.NORTH,
                "north movement retains prior horizontal silhouette")
            driver.set_facing(0,Facing.EAST)
            _check(sprite.flip_h,"east heading mirrors a west-facing supplied atlas")
        var battle=scene.get("model")
        var step: Dictionary=battle.submit(battle.request("MOVE",0,{"target_cell":Vector2i(5,4)}))
        _check(bool(step.get("success",false)),"rendered scene move is legal")
        if bool(step.get("success",false)):
            scene.call("_accept",step)
            for _frame in range(8):
                await process_frame
            if sprite!=null:
                _check(not sprite.flip_h,"model MOVE event turns west-facing atlas back to its unflipped pose")
            _check(scene.get("animation_driver").facing_for(0)==Facing.WEST,
                "sprite animation track maintains authoritative westward direction")
    # Multi-party CTB scene uses the same state and pointers.
    var registry=preload("res://scripts/character_registry.gd").new()
    var many=Model.new()
    many.reset(2026,-1,"tingfeng",registry.battle_options([],{0:"shen_changfeng",1:"pursuer_captain"}))
    _check(many.state.get_actor(0).facing==Facing.EAST
        and many.state.get_actor(1).facing==Facing.WEST,
        "character registry battle carries actor facing")
    scene.queue_free()
    await process_frame
    print("ACTOR_FACING_PASS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures>0 else 0)
