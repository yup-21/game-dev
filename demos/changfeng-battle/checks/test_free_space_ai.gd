extends SceneTree
## The exact production EnemyAI selects only validated spatial requests in
## FREE mode, while all cards/CTB reactions still use the existing model.
const Model=preload("res://scripts/battle_model.gd")
const EnemyAI=preload("res://scripts/enemy_ai.gd")
const MapBake=preload("res://scripts/map_bake.gd")
var checks:=0
var failures:=0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, reason: String) -> void:
    checks+=1
    if not ok:
        failures+=1
        push_error("FREE_AI: "+reason)

func _roster() -> Array:
    var entries: Array=[]
    for i in range(6):
        var side: int=0 if i<3 else 1
        var x: int=2+i if side==0 else 8+i
        entries.append({"id":i,"name":"自动交锋_%d"%i,"team_id":side,
            "controller":"AI","cell":[x,4]})
    return entries

func _run() -> void:
    var duel=Model.new()
    duel.reset(2026,1,"tingfeng",
        {"map_definition_path":MapBake.DEFAULT_PATH,"spatial_mode":"FREE"})
    _check(duel.state.active_id==1 and duel.state.spatial_mode=="FREE",
        "enemy can be given first FREE CTB action")
    var ai=EnemyAI.new()
    var context: Dictionary=duel.decision_context(1)
    var candidates: Array=context.get("legal_actions",[])
    var spatial_found:=false
    for candidate in candidates:
        if str(candidate.get("kind","")) in ["MOVE_FREE","MOVE_AND_ATTACK"]:
            spatial_found=true
    _check(spatial_found,"AI receives only authority-validated continuous candidates")
    var selected: Dictionary=ai.choose_action(context)
    _check(not selected.is_empty(),"production EnemyAI selects a legal action in FREE mode")
    var old_revision: int=duel.state.revision
    var verdict: Dictionary=duel.submit(selected)
    _check(bool(verdict.get("success",false)) and duel.state.revision==old_revision+1,
        "selected AI action commits through identical player authority")
    if bool(verdict.get("success",false)):
        duel.acknowledge_animation(int(verdict.ticket))
    var simulated=Model.new()
    simulated.reset(2026,-1,"tingfeng",{
        "map_definition_path":MapBake.DEFAULT_PATH,
        "spatial_mode":"FREE",
        "combatants":_roster()})
    _check(simulated.state.outcome=="playing" and simulated.state.actors.size()==6,
        "3v3 free-space AI encounter loads")
    var production=EnemyAI.new()
    var moved:=0
    var attacks:=0
    var completed:=0
    for index in range(12):
        if simulated.state.outcome!="playing": break
        var who: int=simulated.rules.responder_id() if simulated.state.mode=="CLASH" else simulated.state.active_id
        var before_rev: int=simulated.state.revision
        var request: Dictionary=production.choose_action(simulated.decision_context(who))
        if request.is_empty():
            _check(false,"AI did not produce a command on decision %d"%index)
            break
        var answer: Dictionary=simulated.submit(request)
        if not bool(answer.get("success",false)):
            _check(false,"AI submitted invalid command on decision %d: %s"%[index,answer.get("error_code","")])
            break
        _check(simulated.state.revision==before_rev+1,"AI commands advance exactly one revision")
        for event in answer.get("events",[]):
            var kind: String=str(event.get("type",""))
            if kind=="MOVE_FREE": moved+=1
            if kind=="ATTACK_DECLARED": attacks+=1
        completed+=1
        simulated.acknowledge_animation(int(answer.ticket))
    _check(completed>=8,"3v3 automatic decisions advance without deadlock")
    _check(moved+attacks>0,"free AI uses world-space moves or attacks, not only END_ACTION")
    print("FREE_AI_PASS checks=%d failures=%d decisions=%d moves=%d attacks=%d"%
        [checks,failures,completed,moved,attacks])
    quit(1 if failures else 0)
