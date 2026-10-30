extends RefCounted

const CombatantState = preload("res://scripts/combatant_state.gd")
const BridgeLayout = preload("res://scripts/rainy_bridge_layout.gd")
const COLS: int = BridgeLayout.COLS
const ROWS: int = BridgeLayout.ROWS
const MAX_CHAIN_DEPTH: int = 4
const DIRECTIONS: Array = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var actors: Array = []
var mode: String = "TIMELINE"
var global_tick: int = 0
var action_no: int = 0
var clash: Dictionary = {}
var card_instances: Dictionary = {}
var knowledge: Dictionary = {0:{},1:{}}
var party_error: String = ""
var last_ready: int = -1
var preferred_first: int = 0
var next_link: int = 0
var next_uid: int = 0
var events: Array = []
var pending_events: Array = []
var hook_queue: Array = []
var processing_hooks: bool = false
var resolving_clash: bool = false
var active_id: int = 0
var phase: String = "DRAW"
var reaction_window: String = "NONE"
var attack: Dictionary = {}
var outcome: String = "playing"
var winner_id: int = -1
var winning_team: int = -1
var revision: int = 0
var animation_pending: bool = false
var animation_ticket: int = 0
var seed: int = 74291
var rng_seed: int = 74291
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var battle_id: String = ""
var round_no: int = 1
var root_action_id: String = ""
var event_seq: int = 0
var combo_history: Dictionary = {0: [], 1: []}
var combo_used: Dictionary = {}
var hook_usage: Dictionary = {}
var profile: String = "tingfeng"
var effect_queue: Array = []
var root_effect_count: int = 0
var terrain: Dictionary = {}
var logs: Array = []
var phase_history: Array = []
var processed_requests: Dictionary = {}
# Stable slots for future declarative passives and board traps.
var hooks: Array = []
var traps: Array = []


func _init(battle_seed: int = 74291) -> void:
	seed = battle_seed
	rng_seed = battle_seed
	rng.seed = battle_seed
	actors = [
		CombatantState.new(0, "沈长风", Vector2i(6, 4)),
		CombatantState.new(1, "拦江客", Vector2i(8, 4))
	]
	actors[0].team_id=0
	actors[0].controller="PLAYER"
	actors[1].team_id=1
	actors[1].facing=Vector2i.LEFT
	actors[1].controller="AI"
	terrain = BridgeLayout.make_terrain()


## Optional encounter roster; default duel remains unchanged.
## Format: [{id:int, name:String, team_id:0|1, controller:"PLAYER"|"AI", cell:[x,y]}].
func configure_combatants(roster: Variant) -> bool:
	if not roster is Array or roster.size()<2 or roster.size()>8:
		party_error="Encounter must have 2–8 combatants"
		return false
	var created: Array=[]
	var used_ids: Dictionary={}
	var used_cells: Dictionary={}
	var teams: Dictionary={}
	for entry in roster:
		if not entry is Dictionary:
			party_error="Combatant must be an object"
			return false
		if not entry.get("id") is int or int(entry.id)<0 or int(entry.id)>1023 or used_ids.has(entry.id):
			party_error="Invalid or duplicated actor ID"
			return false
		if not entry.get("team_id") is int or int(entry.team_id) not in [0,1]:
			party_error="Encounter teams must be 0 and 1"
			return false
		if entry.get("controller","AI") not in ["PLAYER","AI"]:
			party_error="Controller must be PLAYER or AI"
			return false
		var name: Variant=entry.get("name","")
		var coords: Variant=entry.get("cell",[])
		if not name is String or str(name).is_empty() or not coords is Array or coords.size()!=2 or not coords[0] is int or not coords[1] is int:
			party_error="Invalid actor name or cell"
			return false
		if coords[0]<0 or coords[0]>=COLS or coords[1]<0 or coords[1]>=ROWS:
			party_error="Actor spawn must be inside the board"
			return false
		var cell: Vector2i=Vector2i(int(coords[0]),int(coords[1]))
		if not passable(cell) or used_cells.has(cell):
			party_error="Actor spawn must be passable and unoccupied"
			return false
		var actor=CombatantState.new(int(entry.id),str(name),cell)
		actor.team_id=int(entry.team_id)
		actor.facing=Vector2i.LEFT if actor.team_id==1 else Vector2i.RIGHT
		actor.controller=str(entry.get("controller","AI"))
		created.append(actor)
		used_ids[actor.id]=true
		used_cells[cell]=true
		teams[actor.team_id]=true
	if teams.size()!=2:
		party_error="Both opposing teams must be present"
		return false
	actors=created
	knowledge.clear()
	combo_history.clear()
	for actor in actors:
		knowledge[actor.id]={}
		combo_history[actor.id]=[]
	party_error=""
	return true

func is_hostile(a_id: int, b_id: int) -> bool:
	var a=get_actor(a_id)
	var b=get_actor(b_id)
	return a!=null and b!=null and a.id!=b.id and a.team_id!=b.team_id

func living_teams() -> Array:
	var result: Array=[]
	for actor in actors:
		if actor.hp_u>0 and not result.has(actor.team_id): result.append(actor.team_id)
	return result

func get_actor(actor_id: int):
	for actor in actors:
		if actor.id == actor_id:
			return actor
	return null


func in_bounds(point: Vector2i) -> bool:
	return BridgeLayout.in_bounds(point)


func passable(point: Vector2i) -> bool:
	return BridgeLayout.is_walkable(point, terrain)


func occupied(point: Vector2i, exclude_id: int = -1) -> bool:
	for actor in actors:
		if actor.id != exclude_id and actor.hp > 0 and actor.cell == point:
			return true
	return false


func neighbors(point: Vector2i) -> Array:
	var result: Array = []
	for direction in DIRECTIONS:
		var next: Vector2i = point + Vector2i(direction)
		if in_bounds(next):
			result.append(next)
	return result


func find_path(start: Vector2i, goal: Vector2i, actor_id: int = -1) -> Array:
	if not passable(start) or not passable(goal) or occupied(goal, actor_id) or start == goal:
		return []
	var frontier: Array = [start]
	var previous: Dictionary = {start: start}
	var head: int = 0
	while head < frontier.size():
		var current: Vector2i = frontier[head]
		head += 1
		for candidate in neighbors(current):
			var next: Vector2i = candidate
			if previous.has(next) or not passable(next) or occupied(next, actor_id):
				continue
			previous[next] = current
			if next == goal:
				var path: Array = [goal]
				var cursor: Vector2i = goal
				while Vector2i(previous[cursor]) != start:
					cursor = previous[cursor]
					path.push_front(cursor)
				return path
			frontier.append(next)
	return []


func reachable_paths(start: Vector2i, actor_id: int = -1) -> Dictionary:
	# One BFS for an entire legal-action query; preserve the same directional tie-break.
	if not passable(start): return {}
	var paths: Dictionary={start:[]}
	var frontier: Array=[start]
	var head: int=0
	while head<frontier.size():
		var current: Vector2i=frontier[head]
		head+=1
		for cell in neighbors(current):
			if paths.has(cell) or not passable(cell) or occupied(cell,actor_id): continue
			var path: Array=paths[current].duplicate()
			path.append(cell)
			paths[cell]=path
			frontier.append(cell)
	return paths
