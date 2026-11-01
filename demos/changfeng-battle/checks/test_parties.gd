extends SceneTree
## Multi-actor rules regression; defaults still execute the old duel test suite.
const Model=preload("res://scripts/battle_model.gd")
const Policy=preload("res://scripts/enemy_ai.gd")
var failed: int=0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if not value:
		failed+=1
		push_error("FAIL: "+label)
	else:
		print("PASS: "+label)

func roster() -> Array:
	return [
		{"id":0,"name":"Player","team_id":0,"controller":"PLAYER","cell":[6,4]},
		{"id":2,"name":"Ally","team_id":0,"controller":"PLAYER","cell":[5,5]},
		{"id":3,"name":"Ally NPC","team_id":0,"controller":"AI","cell":[5,3]},
		{"id":1,"name":"Opponent A","team_id":1,"controller":"AI","cell":[8,4]},
		{"id":4,"name":"Opponent B","team_id":1,"controller":"AI","cell":[9,5]},
		{"id":5,"name":"Opponent C","team_id":1,"controller":"AI","cell":[9,3]}
	]

func battle():
	var m=Model.new()
	m.reset(2026,0,"tingfeng",{"combatants":roster()})
	return m

func legal(m, who: int, kind: String) -> Array:
	if m.state.animation_pending: m.acknowledge_animation(m.state.animation_ticket)
	var result: Array=[]
	for o in m.legal_actions(who):
		if str(o.kind)==kind: result.append(o)
	return result

func perform(m, option: Dictionary) -> bool:
	if m.state.animation_pending: m.acknowledge_animation(m.state.animation_ticket)
	if option.is_empty(): return false
	var result: Dictionary=m.submit(m.request(str(option.kind),int(option.actor_id),option))
	return bool(result.get("success",false))

func check_invalid_reset(encounter: Array, label: String) -> void:
	var model=battle()
	var setup: Array=legal(model,0,"END_ACTION")
	check(not setup.is_empty() and perform(model,setup[0]),label+" starts from a played battle")
	var actor_id: int=int(model.state.active_id)
	var old_options: Array=legal(model,actor_id,"END_ACTION")
	var old_request: Dictionary=model.request("END_ACTION",actor_id,old_options[0])
	var old_battle_id: String=model.state.battle_id
	var old_state: WeakRef=weakref(model.state)
	var revision: int=int(model.state.revision)
	var ticket: int=int(model.state.animation_ticket)
	model.reset(2026,0,"tingfeng",{"combatants":encounter})
	check(model.state.mode=="FINISHED" and not model.state.party_error.is_empty(),label+" finishes with an encounter error")
	check(model.state.battle_id!=old_battle_id and model.state.revision==revision+1 and model.state.animation_ticket==ticket+1,label+" advances battle, revision and animation boundaries")
	var stale: Array=[]
	for name in ["cards","statuses","visibility","costs","rules","audit","turns","reactions","resolver","abilities"]:
		if model.get(name).state!=model.state: stale.append(name)
	check(stale.is_empty(),label+" binds all stateful subsystems to the new state: "+str(stale))
	check(old_state.get_ref()==null,label+" releases the previous battle state")
	check(model.legal_actions(0).is_empty() and model.legal_actions(actor_id).is_empty() and model.query_legal_actions(actor_id).is_empty(),label+" exposes no actions from the previous battle")
	revision=int(model.state.revision)
	ticket=int(model.state.animation_ticket)
	var old_result: Dictionary=model.submit(old_request)
	check(not old_result.success and old_result.error_code=="STALE_BATTLE",label+" rejects the previous battle request")
	check(model.state.revision==revision and model.state.animation_ticket==ticket and not model.state.animation_pending,label+" old request leaves presentation and revision unchanged")
	var new_result: Dictionary=model.submit(model.request("END_ACTION",0))
	check(not new_result.success and new_result.error_code=="BATTLE_FINISHED",label+" rejects a request for the failed encounter")
	check(model.state.revision==revision and model.state.animation_ticket==ticket and not model.state.animation_pending,label+" new request leaves presentation and revision unchanged")
	model.reset(2026,0,"tingfeng",{"combatants":roster()})
	check(model.state.outcome=="playing" and model.state.actors.size()==6 and model.state.revision==revision+1 and model.state.animation_ticket==ticket+1,label+" recovers through a valid reset")
	var recovered: Array=legal(model,0,"END_ACTION")
	check(not recovered.is_empty() and perform(model,recovered[0]),label+" accepts actions after recovery")

func check_spawn_bounds() -> void:
	var model=Model.new()
	for coords in [[-1,4],[15,4],[6,-1],[6,10],[4294967302,4],[6,4294967300],[-4294967290,4],[6,-4294967292]]:
		var encounter: Array=roster()
		encounter[0].cell=coords
		model.reset(2026,0,"tingfeng",{"combatants":encounter})
		check(model.state.mode=="FINISHED" and not model.state.party_error.is_empty() and model.state.card_instances.is_empty() and model.legal_actions(0).is_empty(),"out-of-board spawn %s is rejected before coordinate narrowing and deck creation" % [coords])
	for coords in [[0,0],[14,0],[0,9],[14,9]]:
		var encounter: Array=roster()
		encounter[0].cell=coords
		model.reset(2026,0,"tingfeng",{"combatants":encounter})
		var actions: Array=legal(model,0,"END_ACTION")
		check(model.state.outcome=="playing" and model.state.get_actor(0).cell==Vector2i(coords[0],coords[1]) and not actions.is_empty() and perform(model,actions[0]),"in-board corner spawn %s remains playable" % [coords])

func run() -> void:
	var legacy=Model.new()
	check(legacy.state.actors.size()==2 and legacy.state.get_actor(0).team_id==0 and legacy.state.get_actor(1).team_id==1,"default duel still uses two opposing combatants")
	var m=battle()
	check(m.state.outcome=="playing" and m.state.actors.size()==6,"3v3 encounter initializes")
	check(m.state.knowledge.size()==6 and m.state.combo_history.size()==6,"per-actor state and knowledge are isolated")
	check(m.state.get_actor(2).controller=="PLAYER" and m.state.get_actor(3).controller=="AI","manual and NPC allies coexist")
	check(m.state.get_actor(5).team_id==1 and m.state.is_hostile(3,5) and not m.state.is_hostile(0,2),"team relation is symmetric")
	check(m.state.active_id==0 and m.state.get_actor(0).controller=="PLAYER","preferred player starts")
	check(legal(m,2,"MOVE").is_empty(),"inactive manual ally cannot act")
	m.state.get_actor(0).cell=Vector2i(7,4)
	m.state.get_actor(1).cell=Vector2i(8,4)
	var attacks: Array=legal(m,0,"BASIC_ATTACK")
	check(attacks.size()==1 and int(attacks[0].target_id)==1,"basic attack targets only adjacent opposing actor")
	check(perform(m,attacks[0]),"manual actor can declare attack")
	check(m.state.mode=="CLASH" and int(m.state.clash.priority_actor_id)==1,"targeted opponent receives first reaction")
	check(legal(m,3,"PASS_REACTION").is_empty() and legal(m,2,"PASS_REACTION").is_empty(),"uninvolved teammates cannot enter this response chain")
	var pass_1: Array=legal(m,1,"PASS_REACTION")
	check(not pass_1.is_empty() and perform(m,pass_1[0]),"defender passes")
	var pass_0: Array=legal(m,0,"PASS_REACTION")
	check(not pass_0.is_empty() and perform(m,pass_0[0]),"attacker passes and chain resolves")
	check(m.state.mode=="ACTION","resolved attack returns priority to original actor")
	m.state.get_actor(1).hp_u=0
	m.resolver.check_death()
	check(m.state.outcome=="playing","defeating one of multiple enemies is not victory")
	m.state.get_actor(4).hp_u=0
	m.resolver.check_death()
	check(m.state.outcome=="playing","second enemy death does not finish battle")
	m.state.get_actor(5).hp_u=0
	m.resolver.check_death()
	check(m.state.outcome=="victory" and m.state.winning_team==0,"battle ends only after all enemies fall")
	var defend=battle()
	defend.state.get_actor(0).hp_u=0
	defend.resolver.check_death()
	check(defend.state.outcome=="playing","player main character falling does not end battle while allies live")
	for id in [2,3]: defend.state.get_actor(id).hp_u=0
	defend.resolver.check_death()
	check(defend.state.outcome=="defeat" and defend.state.winning_team==1,"all friendly units falling causes defeat")
	var malformed=roster()
	malformed[1].cell=[6,4]
	var invalid=Model.new()
	invalid.reset(2026,0,"tingfeng",{"combatants":malformed})
	check(invalid.state.mode=="FINISHED" and invalid.state.get_actor(2)==null,"duplicate spawn cell is rejected before deck creation")
	var only_team=roster()
	for entry in only_team: entry.team_id=0
	invalid.reset(2026,0,"tingfeng",{"combatants":only_team})
	check(invalid.state.mode=="FINISHED","single-team encounter is rejected")
	check_invalid_reset([],"empty roster reset")
	check_invalid_reset(malformed,"overlapping roster reset")
	check_invalid_reset(only_team,"single-team roster reset")
	check_spawn_bounds()
	var timeline=battle()
	var scheduled: Array=[]
	for _i in range(6):
		var id: int=int(timeline.state.active_id)
		scheduled.append(id)
		var end: Array=legal(timeline,id,"END_ACTION")
		check(not end.is_empty() and perform(timeline,end[0]),"scheduler accepts end action from ready unit")
	var ids: Dictionary={}
	for id in scheduled: ids[id]=true
	check(ids.size()==6,"every living combatant receives a CTB action")
	var control=battle()
	control.state.active_id=3
	control.state.mode="ACTION"
	control.state.phase="ACTION"
	var ally_actions: Array=legal(control,3,"END_ACTION")
	var ally_decision: Dictionary=Policy.new().choose_action(control.decision_context(3))
	check(not ally_actions.is_empty() and not ally_decision.is_empty() and control.legal_actions(3).has(ally_decision),"ally NPC uses standard legal-action and AI API")
	control.state.active_id=1
	var enemy_decision: Dictionary=Policy.new().choose_action(control.decision_context(1))
	check(not enemy_decision.is_empty() and control.legal_actions(1).has(enemy_decision),"enemy NPC uses the same AI policy and action API")
	var who=control.state.get_actor(0)
	who.cell=Vector2i(7,4)
	control.state.get_actor(1).cell=Vector2i(8,4)
	control.state.active_id=0
	var skill=Model.new()
	skill.reset(2026,0,"tingfeng",{"combatants":roster(),"technique_catalog_path":"res://checks/fixtures/technique_graph.tres","techniques":{0:{"test_chain":3}}})
	skill.state.get_actor(0).cell=Vector2i(7,4)
	skill.state.get_actor(1).cell=Vector2i(8,4)
	var stage_actions: Array=legal(skill,0,"USE_ABILITY")
	var friendly_target: bool=false
	for option in stage_actions:
		if option.get("target_id",-1) in [0,2,3]: friendly_target=true
	check(not stage_actions.is_empty() and not friendly_target,"technique targets exclude friendly combatants")
	print("PARTY RULES: ",failed," failure(s)")
	quit(1 if failed>0 else 0)
