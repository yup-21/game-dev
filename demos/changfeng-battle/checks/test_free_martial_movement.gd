extends SceneTree
## Action step and defensive evasion use continuous destinations and original
## card consumption + LIFO clash rules in FREE mode.
const Model=preload("res://scripts/battle_model.gd")
const MapBake=preload("res://scripts/map_bake.gd")
var failures:=0
var checks:=0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, reason: String) -> void:
    checks+=1
    if not ok:
        failures+=1
        push_error("FREE_MARTIAL_STEP: "+reason)

func _new_mode(mode: String):
    var m=Model.new()
    m.reset(2026,-1,"tingfeng",{"map_definition_path":MapBake.DEFAULT_PATH,"spatial_mode":mode})
    return m

func _run() -> void:
    var m=_new_mode("FREE")
    var actor=m.state.get_actor(0)
    var uid: String=m.cards.create_instance(actor,"tf_step","hand")
    var legacy_cell: Vector2i=Vector2i(5,4)
    var legacy_actions: Array=m.legal_actions(actor.id).filter(func(action):
        return str(action.get("kind",""))=="PLAY_CARD"
            and str(action.get("card_uid",""))==uid
            and action.has("target_cell"))
    _check(legacy_actions.is_empty(),
        "FREE mode must not enumerate grid-based movement card destinations")
    var forbidden: Dictionary=m.submit(m.request("PLAY_CARD",actor.id,{
        "card_uid":uid,"usage_id":"step","target_cell":legacy_cell}))
    _check(str(forbidden.get("error_code",""))=="ILLEGAL_ACTION",
        "direct legacy cell movement request cannot bypass continuous collision")
    _check(actor.hand.has(uid) and actor.normal_moves_used==0,
        "rejected grid-style request retains card and movement budget")
    var origin: Vector2=actor.position
    var goal: Vector2=origin+Vector2(20.25,0)
    var req: Dictionary=m.request("PLAY_CARD_FREE_MOVE",actor.id,{
        "card_uid":uid,"usage_id":"step","target_position":goal})
    var check: Dictionary=m.validate(req)
    _check(bool(check.get("success",false)),"authored step card permits arbitrary feet position")
    var before: int=actor.qi_u
    var used: Dictionary=m.submit(req)
    _check(bool(used.get("success",false)) and actor.position==goal,
        "step card commits continuous position")
    _check(actor.normal_moves_used==0 and actor.qi_u==before-int(check.get("plan",{}).get("qi_u",-1)),
        "martial step pays its card quote, not normal movement budget")
    _check(not actor.hand.has(uid) and m.state.card_instances.has(uid),
        "card leaves hand exactly once without destroying instance")
    var moved:=false
    for event in used.get("events",[]):
        if str(event.get("type",""))=="MOVE_FREE": moved=true
    _check(moved,"step emits native continuous movement animation event")
    m.acknowledge_animation(int(used.ticket))
    var invalid: Dictionary=m.submit(m.request("PLAY_CARD_FREE_MOVE",actor.id,{
        "card_uid":uid,"usage_id":"step","target_position":origin}))
    _check(str(invalid.get("error_code",""))=="INVALID_CARD","consumed step cannot be replayed")

    var grid=_new_mode("GRID")
    var grid_uid: String=grid.cards.create_instance(grid.state.get_actor(0),"tf_step","hand")
    var grid_options: Array=grid.legal_actions(0).filter(func(action):
        return str(action.get("kind",""))=="PLAY_CARD"
            and str(action.get("card_uid",""))==grid_uid
            and action.has("target_cell"))
    _check(not grid_options.is_empty(),
        "GRID mode still supports legacy reachable-cell movement cards")
    var denied: Dictionary=grid.submit(grid.request("PLAY_CARD_FREE_MOVE",0,{
        "card_uid":grid_uid,"usage_id":"step","target_position":grid.state.get_actor(0).position+Vector2(20,0)}))
    _check(str(denied.get("error_code",""))=="WRONG_SPATIAL_MODE",
        "GRID still owns the legacy integer-cell martial step")

    var fight=_new_mode("FREE")
    var attacker=fight.state.get_actor(0)
    var defender=fight.state.get_actor(1)
    defender.cell=Vector2i(7,4)
    defender.position=fight.state.spatial.bake.cell_center(defender.cell)
    var defender_hp: int=defender.hp_u
    var attack: Dictionary=fight.submit(fight.request("BASIC_ATTACK",0,{"target_id":1}))
    _check(bool(attack.get("success",false)) and fight.state.mode=="CLASH",
        "direct free-space attack enters existing clash")
    fight.acknowledge_animation(int(attack.ticket))
    var evasion_uid: String=fight.cards.create_instance(defender,"tf_step","hand")
    var evade_position: Vector2=defender.position+Vector2(0,20)
    var dodge: Dictionary=fight.submit(fight.request("PLAY_CARD_FREE_MOVE",1,{
        "card_uid":evasion_uid,"usage_id":"evasion","target_position":evade_position}))
    _check(bool(dodge.get("success",false)) and fight.state.mode=="CLASH",
        "defender can commit arbitrary-position evade during response window")
    if bool(dodge.get("success",false)):
        _check(defender.position!=evade_position,
            "LIFO reaction movement is deferred until clash resolves")
        fight.acknowledge_animation(int(dodge.ticket))
        for _turn in range(2):
            if fight.state.mode!="CLASH": break
            var responder: int=fight.rules.responder_id()
            var passed: Dictionary=fight.submit(fight.request("PASS_REACTION",responder))
            _check(bool(passed.get("success",false)),"LIFO pass accepted")
            if not bool(passed.get("success",false)): break
            fight.acknowledge_animation(int(passed.ticket))
        _check(defender.position==evade_position,
            "deferred evasive response moves the defender to exact free landing")
        _check(defender.hp_u==defender_hp,
            "attacker misses if defender escaped the world-space target lock")

    print("FREE_MARTIAL_STEP_PASS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
