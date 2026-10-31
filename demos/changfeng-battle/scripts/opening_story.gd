extends RefCounted
const Events = preload("res://scripts/story_event_executor.gd")
## Opening cutscene and branching dialogue state independent of Node2D / combat UI.
## A later chapter can replace the JSON file without editing the presentation script.
var phase: String = "menu" # menu / cinematic / explore / dialogue / complete
var data: Dictionary = {}
var nodes: Dictionary = {}
var cinematic_index: int = 0
var dialogue_id: String = ""
var obtained_fragment: bool = false
var pending_events: Array = []
var load_error: String = ""

func _init(path: String = "res://data/opening_story.json") -> void:
	if not FileAccess.file_exists(path):
		load_error = "Missing story: " + path
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema_version") != 1:
		load_error = "Invalid opening story format"
		return
	if not parsed.get("cinematic") is Array or parsed.cinematic.is_empty():
		load_error = "Opening cutscene is empty"
		return
	if not parsed.get("dialogues") is Array or parsed.dialogues.is_empty():
		load_error = "Opening dialogue is empty"
		return
	for beat in parsed.cinematic:
		if not beat is Dictionary or not beat.get("text") is String or not beat.get("caption") is String:
			load_error = "Invalid cinematic beat"
			return
		if not (beat.get("duration") is int or beat.get("duration") is float) or float(beat.duration) < 0.5:
			load_error = "Invalid cinematic duration"
			return
	for entry in parsed.dialogues:
		if not entry is Dictionary or not entry.get("id") is String or str(entry.id).is_empty() or nodes.has(entry.id):
			load_error = "Duplicate or invalid dialogue ID"
			return
		if not entry.get("speaker") is String or not entry.get("text") is String:
			load_error = "Invalid dialogue speaker/text"
			return
		if not entry.get("next", "") is String or not entry.get("choices", []) is Array:
			load_error = "Invalid dialogue transition"
			return
		if not _valid_events(entry.get("events",[])):
			load_error = "Invalid dialogue events"
			return
		if entry.has("choices") and entry.choices.size() > 3:
			load_error = "Too many choices"
			return
		nodes[entry.id] = entry.duplicate(true)
	var start_id: String = str(parsed.get("entry_node", ""))
	if not nodes.has(start_id):
		load_error = "Missing dialogue entry"
		return
	for node in nodes.values():
		if not str(node.get("next", "")).is_empty() and not nodes.has(str(node.next)):
			load_error = "Unknown next node"
			return
		for choice in node.get("choices", []):
			if not choice is Dictionary or not choice.get("text") is String or not choice.get("next") is String or not nodes.has(str(choice.next)):
				load_error = "Invalid dialogue choice destination"
				return
			if not _valid_events(choice.get("events",[])) or not _valid_requirements(choice.get("requires",[])):
				load_error = "Invalid dialogue choice effects or conditions"
				return
	data = parsed.duplicate(true)

func begin() -> void:
	if not load_error.is_empty(): return
	phase = "cinematic"
	cinematic_index = 0
	dialogue_id = ""
	obtained_fragment = false
	pending_events.clear()

func reset() -> void:
	phase = "menu"
	cinematic_index = 0
	dialogue_id = ""
	obtained_fragment = false
	pending_events.clear()

func current_beat() -> Dictionary:
	if phase != "cinematic" or cinematic_index >= data.get("cinematic", []).size(): return {}
	return data.cinematic[cinematic_index].duplicate(true)

func next_beat() -> void:
	if phase != "cinematic": return
	cinematic_index += 1
	if cinematic_index >= data.cinematic.size(): phase = "explore"

func skip_cinematic() -> void:
	if phase == "cinematic": phase = "explore"

func interact() -> bool:
	if phase != "explore": return false
	_open_node(str(data.get("entry_node", "")))
	phase = "dialogue"
	return true

func current_dialogue() -> Dictionary:
	if phase != "dialogue" or not nodes.has(dialogue_id): return {}
	return nodes[dialogue_id].duplicate(true)

func _open_node(id: String) -> void:
	if not nodes.has(id):
		phase = "complete"
		dialogue_id = ""
		return
	dialogue_id = id
	pending_events.append_array(nodes[id].get("events",[]).duplicate(true))
	if str(nodes[id].get("event", "")) == "obtain_fragment":
		obtained_fragment = true

func advance_dialogue(flags: Dictionary = {}) -> bool:
	if phase != "dialogue": return false
	if not available_choices(flags).is_empty(): return false
	_open_node(str(current.get("next", "")))
	return true

func choose(index: int, flags: Dictionary = {}) -> bool:
	if phase != "dialogue": return false
	var choices: Array = available_choices(flags)
	if index < 0 or index >= choices.size(): return false
	pending_events.append_array(choices[index].get("events",[]).duplicate(true))
	_open_node(str(choices[index].next))
	return true

func available_choices(flags: Dictionary = {}) -> Array:
	var visible: Array = []
	for choice in current_dialogue().get("choices",[]):
		if Events.meets(choice.get("requires",[]),flags):
			visible.append(choice.duplicate(true))
	return visible

func take_events() -> Array:
	var delivered: Array = pending_events.duplicate(true)
	pending_events.clear()
	return delivered

func _valid_events(entries: Variant) -> bool:
	if not entries is Array: return false
	for event in entries:
		if not Events.valid_event(event): return false
	return true

func _valid_requirements(entries: Variant) -> bool:
	if not entries is Array: return false
	for condition in entries:
		if not condition is Dictionary or not condition.get("flag") is String or not condition.get("equals") is bool: return false
	return true
