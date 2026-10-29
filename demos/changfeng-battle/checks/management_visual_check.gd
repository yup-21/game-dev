extends SceneTree
## Windowed snapshots of the full, interactive bag / martial hall / save slot scenes.
const Session=preload("res://scripts/game_session.gd")
var failures: int=0

func _initialize() -> void:
	call_deferred("_run")

func _error(message: String) -> void:
	failures+=1
	push_error("MANAGEMENT VISUAL: "+message)

func _run() -> void:
	var session=root.get_node_or_null("GameSession")
	if session==null:
		session=Session.new()
		session.name="GameSession"
		root.add_child(session)
	session.start_new_game()
	session.record_story_event("obtain_fragment")
	session.study_fragment()
	session.martial_records[0]["taixu"].rank=4
	session.martial_records[0]["taixu"].xp=500
	session.character_records[0].unspent_points=2
	session.character_records[0].earned_points=2
	var folder: String=ProjectSettings.globalize_path("res://captures")
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:
		_error("cannot create captures folder")
		quit(1)
		return
	var scenes: Array=[
		["res://inventory.tscn","inventory-ui.png",12],
		["res://martial_hall.tscn","martial-hall-ui.png",6],
		["res://save_slots.tscn","save-slots-ui.png",3]]
	for entry in scenes:
		var packed: PackedScene=load(str(entry[0]))
		if packed==null:
			_error("cannot load "+str(entry[0]))
			continue
		var scene=packed.instantiate()
		root.add_child(scene)
		for _i in range(5): await process_frame
		if scene.buttons.size()<int(entry[2]):
			_error("missing clickable UI in "+str(entry[0]))
		var img: Image=root.get_texture().get_image()
		if img.is_empty() or img.save_png(folder.path_join(str(entry[1])))!=OK:
			_error("cannot save "+str(entry[1]))
		scene.queue_free()
		await process_frame
	print("MANAGEMENT VISUAL CHECK: ",failures," failures")
	quit(1 if failures>0 else 0)
