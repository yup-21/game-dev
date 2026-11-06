extends SceneTree
## The art download is optional. Preview scenes must still load as blockouts.
## A full raster audit runs only when all three 1600x1000 PNGs are present.

var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("PROLOGUE_ART_REVIEW: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var names := ["temple_hall", "mountain_road"]
	var imported_count := 0
	for id in names:
		var path := "res://scenes/prologue/prologue_hall_art_review.tscn"
		if id == "mountain_road":
			path = "res://scenes/prologue/prologue_road_art_review.tscn"
		var scene_file := load(path) as PackedScene
		check(scene_file != null, "scene exists: " + id)
		if scene_file == null:
			continue
		var scene := scene_file.instantiate()
		root.add_child(scene)
		await process_frame
		check(scene.get_node_or_null("NativeZone") != null,
			"review preserves editable native zone: " + id)
		check(scene.get_node_or_null("ArtReviewStatus") is Label,
			"review displays candidate/missing status: " + id)
		check(scene.imported_layer_count == 0 or scene.imported_layer_count == 3,
			"partial candidate layers never replace graybox: " + id)
		if scene.imported_layer_count == 3:
			imported_count += 1
			for layer in ["background", "ground", "foreground"]:
				var image_path := "res://assets/candidates/prologue/%s/%s.png" % [id,layer]
				var tex := load(image_path) as Texture2D
				check(tex != null and tex.get_size() == Vector2(1600,1000),
					"layer size and existence: " + image_path)
		scene.queue_free()
		await process_frame
	if failures == 0:
		print("PROLOGUE_ART_REVIEW_STRUCTURE_PASS: two native review scenes; full raster sets imported: %d/2" % imported_count)
		if imported_count < 2:
			print("PROLOGUE_ART_REVIEW_IMAGES_PENDING: download and import PNG candidates before visual signoff")
	quit(1 if failures else 0)
