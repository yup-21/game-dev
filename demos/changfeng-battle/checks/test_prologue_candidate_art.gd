extends SceneTree
## Four-zone art contract. PR includes aligned WebP images; optional local lossless PNGs.
## PROLOGUE_REQUIRE_ART=1 makes all 6 usable texture layers mandatory.

var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("PROLOGUE_ART_REVIEW: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var required := OS.get_environment("PROLOGUE_REQUIRE_ART") == "1"
	var imported_count := 0

	for scene_id in ["temple_hall", "mountain_road"]:
		var file_name := "prologue_hall_art_review.tscn"
		if scene_id == "mountain_road":
			file_name = "prologue_road_art_review.tscn"
		var packed := load("res://scenes/prologue/" + file_name) as PackedScene
		check(packed != null, "preview scene exists: " + scene_id)
		if packed == null:
			continue
		var preview = packed.instantiate()
		root.add_child(preview)
		await process_frame

		var zone = preview.get_node("NativeZone")
		check(zone != null, "editable native zone: " + scene_id)
		check(preview.get_node_or_null("ArtReviewStatus") is Label,
			"review label: " + scene_id)
		check(int(preview.get("imported_layer_count")) in [0, 3],
			"never partially apply candidate layers: " + scene_id)
		check(int(zone.get("painted_layer_count")) == preview.imported_layer_count,
			"preview reuses native scene art (no duplicate sprites): " + scene_id)
		var art_path := (
			"res://data/art_candidates/scenes/prologue_%s/scene_art_v01.tres" % scene_id)
		var art := load(art_path) as WuxiaSceneArtProfile
		check(art != null and art.valid_for(Vector2i(1600, 1000))
			and art.foreground != null,
			"native candidate SceneArtProfile validates: " + art_path)
		if required:
			check(preview.imported_layer_count == 3,
				"mandatory raster layers imported: " + scene_id)
		if preview.imported_layer_count == 3:
			imported_count += 1
			check(not zone.get_node(
				"Architecture" if scene_id == "temple_hall" else "BlockoutArt").visible,
				"candidate art replaces blockout visuals: " + scene_id)
			for role in ["background", "ground", "foreground"]:
				var committed_webp := (
					"res://assets/candidates/prologue/%s/%s.webp" % [scene_id, role])
				check(ResourceLoader.exists(committed_webp),
					"candidate art binary exists in PR: " + committed_webp)
				var sprite := zone.get_node_or_null(
					"PaintedLayers/" + role.capitalize()) as Sprite2D
				check(sprite != null and sprite.texture != null
					and sprite.texture.get_size() == Vector2(1600,1000),
					"aligned 1600x1000 bound candidate layer: " + scene_id + "/" + role)
		preview.queue_free()
		await process_frame

	# Existing official assets must remain bound for the two other regions.
	for spec in [
		["temple_courtyard", "ruined_temple"],
		["broken_bridge", "rainy_bridge"]
	]:
		var official_packed: PackedScene = load(
			"res://scenes/prologue/zones/%s.tscn" % spec[0]
		) as PackedScene
		check(official_packed != null, "official zone scene found: " + str(spec[0]))
		if official_packed == null:
			continue
		var zone: Node2D = official_packed.instantiate() as Node2D
		root.add_child(zone)
		await process_frame
		var paintings: Node2D = zone.get_node("PaintedLayers") as Node2D
		for role in ["Background", "Ground", "Foreground"]:
			var sprite := paintings.get_node_or_null(role) as Sprite2D
			check(sprite != null and sprite.texture != null
				and sprite.texture.get_size() == Vector2(1600,1000),
				"existing %s official layer %s" % [spec[1], role])
		zone.queue_free()
		await process_frame

	if failures == 0:
		if imported_count == 2:
			print("PROLOGUE_FOUR_ZONE_ART_PASS: 2 imported candidates, 2 official reused zones")
		else:
			print("PROLOGUE_ART_STRUCTURE_PASS: 2 native reviews + 2 official reused zones")
			print("PROLOGUE_ART_ASSETS_PENDING: rerun with PROLOGUE_REQUIRE_ART=1 after importing ZIP")
	quit(1 if failures else 0)
