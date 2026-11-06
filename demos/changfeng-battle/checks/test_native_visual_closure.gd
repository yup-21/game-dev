extends SceneTree
## End-to-end native scene/resource authoring contract. Rule state is read-only.
const VFX = preload("res://scripts/battle_vfx_2d.gd")
const NAMES := ["black_blade", "green_wanderer", "gu_qingshuang",
    "night_assassin", "pursuer_captain", "shen_changfeng"]
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _run() -> void:
    for name in NAMES:
        var profile: WuxiaActorAnimationProfile = load(
            "res://data/native/animations/" + name + ".tres")
        require(profile != null and profile.native_frames != null,
            "native SpriteFrames not linked for " + name)
        if profile == null or profile.native_frames == null:
            continue
        var frames: SpriteFrames = profile.native_frames
        require(profile.valid_profile() and frames.get_animation_names().size() == 15,
            "native action order/mapping invalid for " + name)
        for action in ["idle", "move", "walk", "run", "attack", "attack1",
                "attack2", "attack3", "attack4", "guard", "hit", "evade",
                "skill", "combo", "defeat"]:
            require(frames.has_animation(action) and frames.get_frame_count(action) > 0,
                "missing authored action " + name + ":" + action)
        var idle: AtlasTexture = frames.get_frame_texture("idle", 0) as AtlasTexture
        require(idle != null and idle.atlas == profile.atlas and
            idle.region == Rect2(256, 0, 256, 256),
            "in-use side-facing idle no longer references approved artwork: " + name)
        require(frames.get_animation_loop("idle") and not frames.get_animation_loop("defeat"),
            "authored loop policy changed for " + name)
    var scene: Node2D = load("res://battle_hd2d.tscn").instantiate()
    var map: CanvasLayer = scene.get_node("IllustratedBattleMap")
    var art: Node2D = map.get_node("FlatBattle/ArtCalibration")
    for layer in ["FullPaintedTerrain", "GroundArt", "ForegroundOcclusion", "WeatherOverlay"]:
        require(art.get_node_or_null(layer) is TextureRect,
            "battle painting layer is not editor-authored: " + layer)
    require(map.get_node_or_null("FlatBattle/MoveCursor") is Polygon2D,
        "cursor must be an editable Polygon2D")
    var ground: TextureRect = art.get_node("GroundArt")
    var manual_offset: Vector2 = ground.position
    map.illustration_nudge = Vector2(8, -5)
    map.configure()
    require(art.position.is_equal_approx(Vector2(8, -5)) and
        ground.position == manual_offset,
        "runtime map selection overwrote editor-authored layer offsets")
    map.illustration_nudge = Vector2.ZERO
    root.add_child(scene)
    await process_frame
    require(scene.get("illustrated_map") == map,
        "runtime rebuilt battle map instead of reusing PackedScene")
    require(art.get_node("FullPaintedTerrain").texture != null and
        art.position.is_equal_approx(Vector2.ZERO),
        "native map art calibration or texture failed")
    var rail: Control = scene.get_node("WuxiaCombatHUD/UnifiedHUD/ChargeRail")
    var shaft: Line2D = rail.get_node("TrackShaft")
    require(shaft.points.size() == 2 and rail.get_node("Ticks").get_child_count() == 11,
        "rail shaft/ticks must remain editable Godot nodes")
    var marker: Panel = load("res://scenes/ui/ctb_marker.tscn").instantiate()
    var portrait: TextureRect = marker.get_node("Portrait")
    require(portrait.material is ShaderMaterial and
        (portrait.material as ShaderMaterial).shader != null,
        "CTB avatar crop must be a native ShaderMaterial")
    marker.free()
    var revision: int = int(scene.get("model").state.revision)
    var host := Node2D.new()
    root.add_child(host)
    var vfx = VFX.new(host)
    vfx._spawn_canvas(Vector2(120, 120), "shatter", Color.WHITE, 0.6, 1.0)
    require(vfx.bursts.size() == 1, "authored VFX must instantiate")
    if not vfx.bursts.is_empty():
        var burst: Node2D = vfx.bursts[0].node
        require(burst.get_node("MartialStroke").points.size() == 29 and
            burst.get_node("Shards").get_child_count() == 12 and
            burst.get_node("ImpactShards").get_child_count() == 8,
            "VFX paths and shards must come from editable scene nodes")
        var player: AnimationPlayer = burst.get_node("VisualAnimations")
        require(burst.get_child_count() == 9 and player.has_animation("pulse"),
            "VFX should not create runtime shard nodes")
        require(player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,
            "VFX artist-authored fades must tick on the deterministic presentation clock")
    vfx.update(0.2)
    if not vfx.bursts.is_empty():
        var animated: Node2D = vfx.bursts[0].node
        require(animated.modulate.a < 1.0 and animated.scale.x > 0.64,
            "VFX animation must seek authored fade/pulse tracks")
    vfx.clear()
    require(int(scene.get("model").state.revision) == revision,
        "editor visuals must never advance the combat authority")
    host.queue_free()
    scene.queue_free()
    await process_frame
    for failure in failures:
        push_error("NATIVE_VISUAL_CLOSURE: " + failure)
    print("NATIVE_VISUAL_CLOSURE_%s checks=4 profiles=%d failures=%d" % [
        "PASS" if failures.is_empty() else "FAIL", NAMES.size(), failures.size()])
    quit(0 if failures.is_empty() else 1)
