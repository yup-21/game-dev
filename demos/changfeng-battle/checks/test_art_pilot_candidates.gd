extends SceneTree
## Read-only validation of real art-pilot files against their native Godot contracts.
## Candidate files live outside res:// and are never bound to the runtime roster.

const Importer = preload("res://addons/wuxia_art_importer/art_import_service.gd")
const NativeClips = preload("res://scripts/battle_native_sprite_clips.gd")
const ActionTimeline = preload("res://scripts/battle_action_timeline.gd")
const SceneArt = preload("res://scripts/content/scene_art_profile.gd")

const FIRST_FRAME := {
    "idle": 1, "move": 2, "attack": 6, "guard": 9, "hit": 11,
    "evade": 13, "skill": 16, "combo": 19, "defeat": 22,
}


func _initialize() -> void:
    var batch: String = Importer.production_root().path_join("candidates/2026-11-01")
    for actor_id in ["shen_changfeng", "pursuer_captain"]:
        var actor_dir: String = batch.path_join(actor_id)
        var portrait: Dictionary = Importer.inspect(
            actor_dir.path_join("portrait_%s_fullbody_v01.png" % actor_id))
        if not _is_image(portrait, Vector2i(1024, 1536), true):
            _fail("%s portrait is missing, opaque or mis-sized" % actor_id)
            return
        var atlas_path: String = actor_dir.path_join(
            "sprite_%s_atlas_normalized_v02.png" % actor_id)
        var atlas: Dictionary = Importer.inspect(atlas_path)
        if not _is_image(atlas, Vector2i(1536, 1024), true):
            _fail("%s normalized atlas is missing, opaque or mis-sized" % actor_id)
            return
        var clip_path: String = "res://data/art_previews/%s_pilot_clip_profile.tres" % actor_id
        var plan: Dictionary = Importer.plan("atlas", atlas_path,
            "res://data/native/characters/%s.tres" % actor_id,
            {"columns": 6, "rows": 4, "clip_profile_path": clip_path})
        if not str(plan.get("error", "")).is_empty():
            _fail("%s atlas preflight failed: %s" % [actor_id, str(plan["error"])])
            return
        var profile: WuxiaActorAnimationProfile = load(clip_path).duplicate(true)
        profile.atlas = atlas["texture"]
        if not profile.valid_profile():
            _fail("%s nine-action native profile is invalid" % actor_id)
            return
        var sprite := Sprite2D.new()
        sprite.texture = profile.atlas
        sprite.hframes = profile.columns
        sprite.vframes = profile.rows
        root.add_child(sprite)
        var timeline := ActionTimeline.new()
        if not timeline.load_error.is_empty():
            _fail("Timeline failed: " + timeline.load_error)
            return
        var player: AnimationPlayer = NativeClips.attach(sprite, timeline, profile)
        for action in FIRST_FRAME:
            if not player.has_animation(action):
                _fail("%s missing %s animation" % [actor_id, action])
                return
            player.play(action)
            player.advance(0.0)
            if sprite.frame != int(FIRST_FRAME[action]):
                _fail("%s %s starts at wrong sprite frame" % [actor_id, action])
                return
        sprite.queue_free()

    var scene_dir: String = batch.path_join("rainy_bridge")
    var layer_names := ["background", "ground", "foreground", "weather"]
    var layers: Dictionary = {}
    var hashes: Dictionary = {}
    for name in layer_names:
        var path: String = scene_dir.path_join("scene_rainy_bridge_%s_v01.png" % name)
        var info: Dictionary = Importer.inspect(path)
        if not _is_image(info, Vector2i(1600, 1000), true):
            _fail("Rainy bridge %s layer missing, opaque or mis-sized" % name)
            return
        layers[name] = info["texture"]
        hashes[name] = info["sha256"]
    if hashes["background"] == hashes["ground"]:
        _fail("Scene ground duplicates the background")
        return
    var scene: WuxiaSceneArtProfile = SceneArt.new()
    scene.reference_size = Vector2i(1600, 1000)
    scene.background = layers["background"]
    scene.ground = layers["ground"]
    scene.foreground = layers["foreground"]
    scene.weather = layers["weather"]
    if not scene.valid_for(Vector2i(1600, 1000)):
        _fail("Rainy bridge native layer profile is invalid")
        return
    var scene_plan: Dictionary = Importer.plan("scene",
        scene_dir.path_join("scene_rainy_bridge_background_v01.png"),
        "res://data/maps/rainy_bridge.tres", {
            "ground": scene_dir.path_join("scene_rainy_bridge_ground_v01.png"),
            "foreground": scene_dir.path_join("scene_rainy_bridge_foreground_v01.png"),
            "weather": scene_dir.path_join("scene_rainy_bridge_weather_v01.png"),
        })
    if not str(scene_plan.get("error", "")).is_empty() or scene_plan["files"].size() != 4:
        _fail("Rainy bridge four-layer native import preflight failed: " +
            str(scene_plan.get("error", "")))
        return
    print("ART_PILOT_CANDIDATES_OK: 2 actors x 9 clips, 4 aligned layers")
    quit(0)


func _is_image(info: Dictionary, expected: Vector2i, alpha: bool) -> bool:
    return str(info.get("error", "")).is_empty() and \
        Vector2i(int(info.get("width", 0)), int(info.get("height", 0))) == expected and \
        (not alpha or bool(info.get("alpha", false)))


func _fail(message: String) -> void:
    push_error(message)
    quit(1)
