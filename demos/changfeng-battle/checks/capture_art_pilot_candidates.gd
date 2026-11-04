extends SceneTree
## Candidate visual evidence only: no Content Manifest or live map/character binding.
## Displays the exact pilot layers and actor atlases at two UI resolutions.

const Importer = preload("res://addons/wuxia_art_importer/art_import_service.gd")
const OUTPUT := "res://captures/art-pilot/"

var world: Node2D


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    if DisplayServer.get_name() == "headless":
        _fail("Art preview requires a graphical display")
        return
    var batch: String = Importer.production_root().path_join("candidates")
    world = Node2D.new()
    root.add_child(world)
    var scene_dir: String = batch.path_join("scenes/rainy_bridge/baseline")
    var depths := {"background": -20, "ground": -10, "foreground": 10, "weather": 20}
    for name in ["background", "ground", "foreground", "weather"]:
        var data: Dictionary = Importer.inspect(
            scene_dir.path_join("scene_rainy_bridge_%s_v01.png" % name))
        if not str(data.get("error", "")).is_empty():
            _fail("Unable to open scene layer: " + name)
            return
        var layer := Sprite2D.new()
        layer.texture = data["texture"]
        layer.position = Vector2(800, 500)
        layer.z_index = depths[name]
        world.add_child(layer)
    var atlases: Dictionary = {}
    for id in ["shen_changfeng", "pursuer_captain"]:
        var data: Dictionary = Importer.inspect(
            batch.path_join("characters/" + id + "/baseline").path_join("sprite_%s_atlas_normalized_v02.png" % id))
        if not str(data.get("error", "")).is_empty():
            _fail("Unable to open actor atlas: " + id)
            return
        atlases[id] = data["texture"]
    # These are inspection placements, NOT tested map spawn points.
    var poses := [
        {"id": "shen_changfeng", "frame": 1, "point": Vector2(375, 424)},
        {"id": "shen_changfeng", "frame": 6, "point": Vector2(545, 450)},
        {"id": "shen_changfeng", "frame": 9, "point": Vector2(715, 425)},
        {"id": "pursuer_captain", "frame": 1, "point": Vector2(885, 427)},
        {"id": "pursuer_captain", "frame": 6, "point": Vector2(1055, 454)},
        {"id": "pursuer_captain", "frame": 9, "point": Vector2(1225, 425)},
    ]
    for pose in poses:
        var sprite := Sprite2D.new()
        sprite.texture = atlases[str(pose["id"])]
        sprite.hframes = 6
        sprite.vframes = 4
        sprite.frame = int(pose["frame"])
        sprite.offset = Vector2(0, -102)
        sprite.scale = Vector2(0.53, 0.53)
        sprite.position = pose["point"]
        sprite.z_index = 0
        world.add_child(sprite)
    var label := Label.new()
    label.text = "ART PILOT / CANDIDATE   -   2 actors, layered bridge (not gameplay)"
    label.position = Vector2(24, 14)
    label.add_theme_font_size_override("font_size", 22)
    label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
    label.z_index = 30
    world.add_child(label)

    if not await _capture(Vector2i(1600, 1000), "pilot-1600x1000"):
        quit(1)
        return
    if not await _capture(Vector2i(1440, 900), "pilot-1440x900"):
        quit(1)
        return
    _save_idle_contact_sheet()
    print("ART_PILOT_VISUAL_EVIDENCE_OK")
    quit(0)


func _capture(size: Vector2i, name: String) -> bool:
    root.size = size
    world.scale = Vector2(size) / Vector2(1600, 1000)
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty() or Vector2i(image.get_size()) != size:
        push_error("Art pilot capture resolution mismatch: " + name)
        return false
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
    var target := OUTPUT + name + ".png"
    if image.save_png(target) != OK:
        push_error("Could not save art pilot screenshot: " + target)
        return false
    print("ART_PILOT_CAPTURE ", ProjectSettings.globalize_path(target))
    return true


func _fail(message: String) -> void:
    push_error(message)
    quit(1)

## Inspect the first two native idle poses at full atlas-cell resolution.
## Column order: Shen, Gu, Green Wanderer, Black Blade, Assassin, Captain.
## Green line is the production author's 227px feet baseline.
func _save_idle_contact_sheet() -> void:
    var ids := ["shen_changfeng", "gu_qingshuang", "green_wanderer",
        "black_blade", "night_assassin", "pursuer_captain"]
    var preview := Image.create(1536, 512, false, Image.FORMAT_RGBA8)
    preview.fill(Color(0.10,0.12,0.16,1.0))
    for col in range(ids.size()):
        var profile: WuxiaActorAnimationProfile = load(
            "res://data/native/animations/%s.tres" % ids[col])
        if profile == null or profile.atlas == null:
            continue
        var source: Image = profile.atlas.get_image()
        if source == null or source.is_empty():
            continue
        for frame in range(2):
            preview.blend_rect(source, Rect2i(frame * 256, 0, 256, 256),
                Vector2i(col * 256, frame * 256))
            preview.fill_rect(Rect2i(col * 256, frame * 256 + 228, 256, 1),
                Color(0.15,0.96,0.45,1.0))
    var folder: String = ProjectSettings.globalize_path(OUTPUT)
    DirAccess.make_dir_recursive_absolute(folder)
    var target: String = folder.path_join("native-idle-0-vs-1.png")
    if preview.save_png(target) == OK:
        print("IDLE_FRAME_CONTACT_SHEET ", target)
