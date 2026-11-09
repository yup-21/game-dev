extends SceneTree
## Run: godot --headless --path demos/changfeng-battle --script res://checks/test_frame_workbench.gd
const Workbench = preload("res://addons/wuxia_art_importer/frame_workbench_service.gd")
const Dock = preload("res://addons/wuxia_art_importer/frame_workbench_dock.gd")
var failures: Array[String] = []


func check(value: bool, description: String) -> void:
    if not value:
        failures.append(description)


func _frame(image: Image, offset: Vector2 = Vector2.ZERO) -> Dictionary:
    return {"image": image, "rect": Rect2i(Vector2i.ZERO, image.get_size()),
        "scale": 1.0, "offset": offset, "duration_ms": 120, "cleanup": true,
        "alpha_cutoff": 0.07, "bg_tolerance": 0.12, "min_island_area": 8,
        "polygon": PackedVector2Array()}


func _test_sequential_binding(frame: Dictionary) -> void:
    # Exercise actual save/reload of 3 actions on throwaway user:// resources.
    # Never replace a project's authored character or its real SpriteFrames.
    var source_actor := ResourceLoader.load(
        "res://data/native/characters/gu_qingshuang.tres") as WuxiaCharacterDefinition
    check(source_actor != null and source_actor.animation_profile != null,
        "load gu_qingshuang native resource for test")
    if source_actor == null or source_actor.animation_profile == null:
        return
    var prefix := "user://workbench_binding_%d" % Time.get_ticks_usec()
    var target := prefix + "_character.tres"
    var profile_path := prefix + "_profile.tres"
    var created: Array[String] = [target, profile_path]
    var actor := source_actor.duplicate(true) as WuxiaCharacterDefinition
    var profile := source_actor.animation_profile.duplicate(true) as WuxiaActorAnimationProfile
    var expected: Array[String] = []
    for action in ["idle", "walk", "run"]:
        var built := Workbench.build([frame], Vector2i(328, 256), action, 12.0, true)
        check(str(built.get("error", "")).is_empty(), "build %s fixture" % action)
        if not str(built.get("error", "")).is_empty():
            break
        var frames_path: String = prefix + "_" + str(action) + "_frames.tres"
        created.append(frames_path)
        var merged := Workbench.make_frames(profile.native_frames, built,
            ImageTexture.create_from_image(built["image"] as Image))
        check(ResourceSaver.save(merged, frames_path) == OK,
            "serialize %s SpriteFrames fixture" % action)
        profile.native_frames = ResourceLoader.load(frames_path, "SpriteFrames",
            ResourceLoader.CACHE_MODE_REPLACE) as SpriteFrames
        var problem: String = Workbench.save_external_binding(actor, profile,
            profile_path, target)
        check(problem.is_empty(), "save %s external binding: %s" % [action, problem])
        if not problem.is_empty():
            break
        actor = ResourceLoader.load(target, "", ResourceLoader.CACHE_MODE_REPLACE) \
            as WuxiaCharacterDefinition
        check(actor != null and actor.animation_profile != null and \
            actor.animation_profile.resource_path == profile_path,
            "%s character must retain external AnimationProfile" % action)
        if actor == null or actor.animation_profile == null:
            break
        profile = actor.animation_profile.duplicate(true) as WuxiaActorAnimationProfile
        expected.append(action)
        for previous in expected:
            check(profile.native_frames.has_animation(previous) and \
                profile.native_frames.get_frame_count(previous) == 1,
                "after %s, prior %s action still bound" % [action, previous])
    for path in created:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _initialize() -> void:
    var source := Image.create(80, 80, false, Image.FORMAT_RGBA8)
    source.fill(Color.TRANSPARENT)
    source.fill_rect(Rect2i(30, 20, 20, 30), Color.RED)
    source.set_pixel(1, 1, Color(1, 0, 0, 0.02))
    source.set_pixel(3, 3, Color(0, 0, 1, 1))
    var original := source.duplicate() as Image
    var cleaned := Workbench.clean_edges(source)
    check(cleaned.get_pixel(1, 1).a == 0.0 and cleaned.get_pixel(3, 3).a == 0.0,
        "remove low-alpha contamination and isolated pixel")
    check(cleaned.get_pixel(35, 25).a > 0.9 and source.get_pixel(3, 3).a == 1.0,
        "preserve foreground and do not modify original")
    var frame := _frame(source)
    var result := Workbench.render_frame(frame, Vector2i(328, 256))
    check(str(result.get("error", "")).is_empty(), "normalize imperfect source: " +
        str(result.get("error", "")))
    if str(result.get("error", "")).is_empty():
        var image: Image = result["image"]
        check(image.get_size() == Vector2i(328, 256) and
            image.get_pixel(1, 1).a == 0.0 and image.get_pixel(164, 226).a > 0.0,
            "standard RGBA output and stable bottom anchor")
    check(source.get_data() == original.get_data(), "source pixels untouched after render")
    var cut := _frame(source)
    cut["rect"] = Rect2i(30, 20, 20, 30)
    cut["scale"] = 0.8
    cut["offset"] = Vector2(10, -3)
    var baked := Workbench.build([frame, cut], Vector2i(328, 256), "walk", 12.0, true)
    check(str(baked.get("error", "")).is_empty(), "mixed independently edited frame build: " +
        str(baked.get("error", "")))
    if str(baked.get("error", "")).is_empty():
        check(baked["image"].get_size() == Vector2i(656, 256) and
            baked["durations"] == PackedFloat32Array([0.12, 0.12]),
            "two-frame atlas and exact timing")
        var old := SpriteFrames.new()
        old.add_animation("idle")
        old.add_frame("idle", ImageTexture.create_from_image(source))
        var native := Workbench.make_frames(old, baked, ImageTexture.create_from_image(baked["image"]))
        check(native.has_animation("idle") and native.has_animation("walk") and
            native.get_frame_count("idle") == 1 and native.get_frame_count("walk") == 2 and
            absf(native.get_frame_duration("walk", 0) - 1.44) < 0.001,
            "incremental action does not overwrite the other animations")
        check(old.get_frame_count("idle") == 1 and not old.has_animation("walk"),
            "base native SpriteFrames preserved")
        # A generated atlas texture must survive ResourceSaver serialization.
        var saved_path := "user://workbench_test_spriteframes.tres"
        var serialized := ResourceSaver.save(native, saved_path)
        check(serialized == OK, "serialize native SpriteFrames")
        if serialized == OK:
            var reopened := ResourceLoader.load(saved_path, "SpriteFrames",
                ResourceLoader.CACHE_MODE_IGNORE) as SpriteFrames
            check(reopened != null and reopened.has_animation("walk") and
                reopened.get_frame_count("walk") == 2 and
                reopened.get_frame_texture("walk", 1) != null,
                "serialized SpriteFrames textures reload")
            DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_path))
        # Read-only plan validation against a real migrated actor. Applying the
        # plan is intentionally reserved for a GUI artist's explicit approval.
        var target := "res://data/native/characters/shen_changfeng.tres"
        var actor := ResourceLoader.load(target) as WuxiaCharacterDefinition
        if actor != null and actor.animation_profile != null and \
                actor.animation_profile.native_frames != null:
            var plan := Workbench.prepare(target, baked)
            check(str(plan.get("error", "")).is_empty(), "real actor incremental import preflight: " +
                str(plan.get("error", "")))
    var white := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    white.fill(Color.WHITE)
    white.fill_rect(Rect2i(24, 18, 16, 32), Color.BLACK)
    var removed := Workbench.clean_edges(white)
    check(removed.get_pixel(0, 0).a == 0.0 and removed.get_pixel(30, 30).a > 0.9,
        "opaque uniform background removed without deleting foreground")
    var edge := _frame(source)
    edge["offset"] = Vector2(160, 0)
    check(not str(Workbench.build([edge], Vector2i(328, 256), "idle", 10.0, true)
        .get("error", "")).is_empty(), "output overflow rejected, source still accepted")
    check(not str(Workbench.build([frame], Vector2i(328, 256), "defeat", 10.0, true)
        .get("error", "")).is_empty(), "defeat cannot loop")
    _test_sequential_binding(frame)
    var dock := Dock.new()
    root.add_child(dock)
    # SceneTree._initialize runs before the first idle frame; initialize the
    # Control explicitly to exercise the same editor plugin construction path.
    dock._ready()
    check(dock.frame_list != null and dock.actor_choice != null,
        "workbench dock constructs in Godot editor runtime")
    dock.frames.append(frame)
    dock.pending = {"test": "stale preflight"}
    dock._reset_for_target()
    check(dock.frames.is_empty() and dock.pending.is_empty() and dock.current_index == -1,
        "actor/action change rejects stale editing session and approval")
    dock.queue_free()
    if failures.is_empty():
        print("PASS frame workbench: edge cleanup, normalization, native serialization, idle/walk/run binding")
        quit(0)
        return
    for failure in failures:
        printerr("FAIL ", failure)
    quit(1)
