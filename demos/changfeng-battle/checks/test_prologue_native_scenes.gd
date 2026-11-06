extends SceneTree
## The prologue is an isolated native-scene QA entry, not the formal chapter.
## Validate scene authoring, spawn, both safe/hostile returns, and one-shot reveal.

const Progress = preload("res://scripts/prologue/prologue_progress.gd")
var failures := 0

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("PROLOGUE_NATIVE_SCENES: " + description)

func _initialize() -> void:
	call_deferred("_run")

func use_gate(scene: Node2D, portal_name: String) -> bool:
	var portal: Marker2D = scene.current_zone.get_node("Exits/" + portal_name)
	check(scene.current_zone.permits_foot(portal.position), "gate is walkable: " + portal_name)
	scene.hero.position = portal.position
	return scene.follow_portal(portal_name)

func walk_by_input(scene: Node2D, destination: Vector2) -> void:
	var directions := {"ui_left": Vector2.LEFT, "ui_right": Vector2.RIGHT,
		"ui_up": Vector2.UP, "ui_down": Vector2.DOWN}
	for step in range(900):
		var remaining: Vector2 = destination - scene.hero.position
		if remaining.length() <= 5.0:
			break
		for action in directions:
			if remaining.normalized().dot(directions[action]) > 0.15:
				Input.action_press(action)
			else:
				Input.action_release(action)
		scene._physics_process(1.0 / 60.0)
		check(scene.current_zone.permits_foot(scene.hero.position),
			"input-controlled movement remains on editable walkable polygon")
	for action in directions:
		Input.action_release(action)
	check(scene.hero.position.distance_to(destination) <= 5.0,
		"player can reach waypoint with actual input: " + str(destination))

func capture(label: String) -> void:
	var directory: String = OS.get_environment("PROLOGUE_CAPTURE_DIR")
	if directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	check(not screenshot.is_empty() and screenshot.save_png(directory.path_join(label + ".png")) == OK,
		"render " + label)

func _run() -> void:
	var isolated_progress = Progress.new()
	check(not isolated_progress.on_enter_hall("temple_courtyard"), "cannot reveal before leaving")
	isolated_progress.on_leave_hall()
	check(not isolated_progress.on_enter_hall("temple_courtyard"), "immediate return is safe")
	check(isolated_progress.discover("cart_traces"), "new landmark records exploration")
	check(not isolated_progress.discover("cart_traces"), "landmark only records once")
	check(isolated_progress.on_enter_hall("temple_courtyard"), "discovery enables ambush")
	check(not isolated_progress.on_enter_hall("temple_courtyard")
		and isolated_progress.revealed_count == 1, "ambush one-shot")

	var zone_files := {
		"temple_hall": "res://scenes/prologue/zones/temple_hall.tscn",
		"temple_courtyard": "res://scenes/prologue/zones/temple_courtyard.tscn",
		"mountain_road": "res://scenes/prologue/zones/mountain_road.tscn",
		"broken_bridge": "res://scenes/prologue/zones/broken_bridge.tscn"
	}
	for zone_id in zone_files:
		var zone: Node2D = load(zone_files[zone_id]).instantiate()
		check(zone.zone_id == zone_id and not zone.zone_title.is_empty(), "native zone metadata: " + zone_id)
		check(zone.get_node_or_null("Navigation/Walkable") is Polygon2D
			and zone.get_node_or_null("Entries") != null
			and zone.get_node_or_null("Exits") != null,
			"editable polygons, entry markers and exits: " + zone_id)
		for marker in zone.get_node("Entries").get_children():
			check(zone.permits_foot(marker.position), "safe native spawn: " + zone_id + "/" + marker.name)
		for gate in zone.get_node("Exits").get_children():
			check(zone_files.has(gate.target_zone_id) and not gate.target_entry_id.is_empty(),
				"resolved connection: " + zone_id + "/" + gate.name)
		zone.free()

	var scene: Node2D = load("res://scenes/prologue/prologue_exploration.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.current_zone.zone_id == "temple_hall", "player starts in hall")
	await capture("01_hall_fire_start")
	check(scene.hero.position == Vector2(862, 699), "wakes beside the campfire")
	check(not scene.progress.ambush_started
		and not scene.current_zone.get_node("AmbushActors").visible, "enemies initially hidden")
	check(not scene.current_zone.permits_foot(Vector2(630, 580)), "campfire has authored obstacle")
	check(not scene.current_zone.permits_foot(Vector2(1180, 382)), "statue has authored obstacle")
	check(scene.interact(), "player may inspect campfire on first spawn")
	check(scene.progress.discovered_landmarks.has("campfire"), "campfire observation recorded")
	check(not scene.progress.explored_deep_outside, "indoor investigation cannot complete outside milestone")
	check(not scene.follow_portal("nonexistent"), "cannot take nonexistent exit")
	check(not scene.follow_portal("ToCourtyard"), "cannot activate a distant exit")
	walk_by_input(scene, Vector2(800, 859))
	check(use_gate(scene, "ToCourtyard"), "hall -> courtyard")
	check(scene.current_zone.zone_id == "temple_courtyard", "courtyard was mounted")
	check(scene.current_zone.get_node_or_null("StoryAnchors/HanXiaoForecourtBattle") is Marker2D,
		"forecourt boss stage is reserved without firing formal encounter")
	await capture("02_courtyard")
	check(not scene.progress.explored_deep_outside, "leaving alone is not a milestone")
	check(use_gate(scene, "ToHall"), "courtyard -> hall immediately")
	check(not scene.progress.ambush_started, "no enemy on premature return")
	check(use_gate(scene, "ToCourtyard"), "hall -> courtyard again")
	check(use_gate(scene, "ToRoad"), "courtyard -> road")
	check(scene.current_zone.zone_id == "mountain_road", "road was mounted")
	await capture("03_mountain_road")
	check(not scene.progress.explored_deep_outside, "must investigate or reach the bridge")
	walk_by_input(scene, Vector2(746, 406))
	walk_by_input(scene, Vector2(748, 646))
	check(scene.interact(), "can inspect broken cart evidence")
	check(scene.progress.explored_deep_outside, "cart evidence marks meaningful exploration")
	check(use_gate(scene, "ToCourtyard"), "road -> courtyard")
	check(use_gate(scene, "ToHall"), "courtyard -> hall after exploration")
	check(scene.progress.ambush_started and scene.progress.revealed_count == 1,
		"return reveals ambush exactly once")
	check(scene.current_zone.get_node("AmbushActors").visible, "two guards and elder scene anchors visible")
	check(scene.current_zone.get_node("Campfire/Flame").modulate.a < 0.5,
		"return ambience visibly dims the campfire")
	await capture("04_hall_ambush")
	check(scene.current_zone.get_node("AmbushActors/GhostMaskGuardA") is Marker2D
		and scene.current_zone.get_node("AmbushActors/GhostMaskGuardB") is Marker2D
		and scene.current_zone.get_node("AmbushActors/YanShouchengHiding") is Marker2D,
		"all enemy and elder markers are editable")
	check(use_gate(scene, "ToCourtyard") and use_gate(scene, "ToHall"), "can reenter after ambush")
	check(scene.progress.revealed_count == 1, "repeat crossing never replays event")
	scene.queue_free()
	await process_frame

	var bridge_scene: Node2D = load("res://scenes/prologue/prologue_exploration.tscn").instantiate()
	root.add_child(bridge_scene)
	await process_frame
	check(use_gate(bridge_scene, "ToCourtyard")
		and use_gate(bridge_scene, "ToRoad")
		and use_gate(bridge_scene, "ToBridge"), "all three outbound gates connected")
	check(bridge_scene.current_zone.zone_id == "broken_bridge"
		and bridge_scene.progress.explored_deep_outside, "bridge arrival records exploration")
	check(bridge_scene.current_zone.get_node_or_null("StoryAnchors/FutureFerryTrailNotConnected") is Marker2D,
		"later ferry direction is a non-functional anchor")
	await capture("05_broken_bridge")
	check(use_gate(bridge_scene, "ToRoad")
		and use_gate(bridge_scene, "ToCourtyard")
		and use_gate(bridge_scene, "ToHall"), "bridge -> hall fully connected")
	check(bridge_scene.progress.ambush_started, "bridge route also triggers return encounter")
	bridge_scene.queue_free()
	await process_frame
	if failures == 0:
		print("PROLOGUE_NATIVE_SCENES_PASS: four native editable zones; safe return; explored return; single ambush")
	quit(1 if failures else 0)
