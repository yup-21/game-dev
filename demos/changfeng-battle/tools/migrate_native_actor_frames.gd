extends SceneTree
## One-time, non-destructive migration of approved in-use atlases to Godot's
## editable SpriteFrames. Existing destination files are never overwritten:
## artists can subsequently change their frame order/timing in the Inspector.
const CHARACTERS := [
    "black_blade", "green_wanderer", "gu_qingshuang",
    "night_assassin", "pursuer_captain", "shen_changfeng"
]
const SOURCE := "res://data/native/animations/"
const DEST := "res://data/native/sprite_frames/"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var failed := false
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
    for character in CHARACTERS:
        var target: String = DEST + character + ".tres"
        if FileAccess.file_exists(target):
            print("NATIVE_FRAMES_PRESERVED ", target)
            continue
        var profile: WuxiaActorAnimationProfile = load(SOURCE + character + ".tres")
        if profile == null or not profile.valid_profile():
            push_error("Invalid approved in-use actor profile: " + character)
            failed = true
            continue
        var frames := SpriteFrames.new()
        frames.remove_animation("default")
        var built: Dictionary = {}
        for entry in profile.clips:
            var clip: WuxiaActorAnimationClip = entry as WuxiaActorAnimationClip
            if clip == null or not _append_clip(frames, profile, clip.action, clip):
                failed = true
                continue
            built[clip.action] = true
        for alias in profile.action_fallbacks:
            var action: String = str(alias)
            var source: String = str(profile.action_fallbacks[alias])
            if built.has(action):
                continue
            var clip: WuxiaActorAnimationClip = profile.clip_for(source)
            if clip == null or not _append_clip(frames, profile, action, clip):
                failed = true
        if not frames.has_animation("idle") or failed:
            continue
        var result := ResourceSaver.save(frames, target)
        if result != OK:
            push_error("Could not save native SpriteFrames " + target + ": " + str(result))
            failed = true
        else:
            print("NATIVE_FRAMES_CREATED ", target, " actions=", frames.get_animation_names().size())
    quit(1 if failed else 0)

func _append_clip(frames: SpriteFrames, profile: WuxiaActorAnimationProfile,
        action: String, clip: WuxiaActorAnimationClip) -> bool:
    var texture: Texture2D = clip.effective_atlas(profile.atlas)
    var columns: int = clip.effective_columns(profile.columns)
    var rows: int = clip.effective_rows(profile.rows)
    if texture == null or not clip.valid_for(columns * rows):
        push_error("Invalid source clip for action " + action)
        return false
    var cell := Vector2(texture.get_width() / float(columns),
        texture.get_height() / float(rows))
    frames.add_animation(action)
    # Native frame duration units are 1/fps. We use 1 FPS deliberately so
    # each Frame duration stores the exact legacy authored seconds.
    frames.set_animation_speed(action, 1.0)
    frames.set_animation_loop(action, clip.loop)
    for index in range(clip.frames.size()):
        var cell_index: int = clip.frames[index]
        var region := AtlasTexture.new()
        region.atlas = texture
        region.region = Rect2(Vector2(cell_index % columns, cell_index / columns) * cell, cell)
        var seconds: float = 1.0 / clip.loop_fps
        if not clip.frame_durations.is_empty():
            seconds = float(clip.frame_durations[index])
        frames.add_frame(action, region, seconds)
    return true
