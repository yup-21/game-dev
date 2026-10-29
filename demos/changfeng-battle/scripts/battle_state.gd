extends RefCounted

const CombatantState = preload("res://scripts/combatant_state.gd")
const COLS: int = 15
const ROWS: int = 10
const MAX_CHAIN_DEPTH: int = 4
const DIRECTIONS: Array = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var actors: Array = []
var mode: String = "TIMELINE"
var global_tick: int = 0
var action_no: int = 0
var clash: Dictionary = {}
var card_instances: Dictionary = {}
var knowledge: Dictionary = {0:{},1:{}}
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
	for row in range(ROWS):
		for col in range(COLS):
			terrain[Vector2i(col, row)] = "water" if col == 7 else "grass"
	terrain[Vector2i(7, 4)] = "bridge"
	terrain[Vector2i(7, 8)] = "ford"
	for point in [Vector2i(4, 1), Vector2i(5, 1), Vector2i(3, 7), Vector2i(4, 7), Vector2i(10, 2), Vector2i(11, 7)]:
		terrain[point] = "rock"
	for point in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(5, 6), Vector2i(9, 7), Vector2i(12, 1), Vector2i(12, 8)]:
		terrain[point] = "bamboo"
	terrain[Vector2i(13, 4)] = "exit"


func get_actor(actor_id: int):
	for actor in actors:
		if actor.id == actor_id:
			return actor
	return null


func in_bounds(point: Vector2i) -> bool:
	return point.x >= 0 and point.x < COLS and point.y >= 0 and point.y < ROWS


func passable(point: Vector2i) -> bool:
	return in_bounds(point) and terrain.has(point) and str(terrain[point]) not in ["water", "rock", "bamboo"]


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
