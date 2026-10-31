extends SceneTree
## Headless narrative contract test. No combat numbers, UI state or scene tree side effects.
const Story = preload("res://scripts/opening_story.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok: print("PASS: ",label)
	else:
		failures += 1
		push_error("FAIL: "+label)

func _opening_root_script_valid(scene: PackedScene) -> bool:
	if scene == null: return false
	var opening = scene.instantiate()
	if opening == null: return false
	var script = opening.get_script()
	var valid: bool = script is Script and script.can_instantiate()
	opening.free()
	return valid

func _finish_branch(choice: int) -> void:
	var s = Story.new()
	s.begin()
	check(s.phase=="cinematic","new game enters cinematic")
	var beats: int=s.data.cinematic.size()
	check(beats==3,"cinematic has three timed scenes")
	for _i in range(beats): s.next_beat()
	check(s.phase=="explore","cinematic ends in walkable opening")
	check(s.interact(),"talk interaction begins")
	var emitted: Array=[]
	var visited: Dictionary={}
	var choice_used: bool=false
	for _i in range(24):
		if s.phase!="dialogue": break
		var node: Dictionary=s.current_dialogue()
		check(not node.is_empty(),"dialogue lookup is valid")
		if node.is_empty(): break
		if visited.has(s.dialogue_id):
			check(false,"dialogue cycle detected")
			break
		visited[s.dialogue_id]=true
		emitted.append_array(s.take_events())
		if not node.get("choices",[]).is_empty():
			check(not choice_used,"choice shown only once")
			choice_used=true
			check(not s.advance_dialogue(),"branch prompt cannot be bypassed")
			check(s.choose(choice),"selected branch advances")
		else:
			check(s.advance_dialogue(),"plain dialogue advances")
	check(s.phase=="complete","branch reaches chapter completion")
	emitted.append_array(s.take_events())
	check(emitted.has({"type":"set_flag","flag":"helped_escort","value":choice==0}),
		"branch choice emits its authored flag")
	check(emitted.has({"type":"set_flag","flag":"obtained_fragment","value":true})
		and emitted.has({"type":"grant_clue","id":"taixu_fragment","count":1}),
		"chapter completion emits the Taixu fragment events")
	check(choice_used,"branch choice was encountered")

func _run() -> void:
	var s = Story.new()
	check(s.load_error.is_empty(),"typed prologue Resource validates")
	check(s.phase=="menu" and s.dialogue_id.is_empty(),"new session shows menu")
	check(not s.interact(),"cannot interact from menu")
	s.begin()
	check(s.phase=="cinematic" and s.current_beat().has("caption"),"starting new game exposes cinematic beat")
	s.next_beat()
	check(s.cinematic_index==1 and s.phase=="cinematic","beat advances in order")
	s.skip_cinematic()
	check(s.phase=="explore" and s.current_beat().is_empty(),"skip enters exploration without dialogue")
	check(s.interact(),"exploration triggers first dialogue")
	check(s.current_dialogue().speaker=="旁白","opening speaker and text come from story Resource")
	check(not s.choose(-1) and not s.choose(0),"choices unavailable outside choice node")
	s.reset()
	check(s.phase=="menu" and s.take_events().is_empty(),"returning to menu resets story state")
	_finish_branch(0)
	_finish_branch(1)
	var default_scene=load("res://opening.tscn")
	check(default_scene!=null and load("res://battle_hd2d.tscn") is PackedScene,
		"title and canonical battle scene resolve")
	check(_opening_root_script_valid(default_scene),"opening root script compiles and instantiates")
	var missing_script_scene = PackedScene.new()
	var missing_script_root = Node2D.new()
	missing_script_scene.pack(missing_script_root)
	missing_script_root.free()
	check(not _opening_root_script_valid(missing_script_scene),"opening root without script fails validation")
	print("OPENING STORY FAILURES: ",failures)
	quit(1 if failures!=0 else 0)
