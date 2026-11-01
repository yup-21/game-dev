extends SceneTree
## New native per-action sprite profiles must remain editable and deterministic.

const Profile = preload("res://scripts/content/actor_animation_profile.gd")
const Clip = preload("res://scripts/content/actor_animation_clip.gd")
const NativeClips = preload("res://scripts/battle_native_sprite_clips.gd")
const ActionTimeline = preload("res://scripts/battle_action_timeline.gd")

func _initialize() -> void:
    var profile = load("res://data/templates/actor_animation_profile.tres") as WuxiaActorAnimationProfile
    if profile == null or not profile.valid_profile():
        push_error("Animation template profile is invalid")
        quit(1)
        return
    var sprite := Sprite2D.new()
    sprite.texture = profile.atlas
    sprite.hframes = profile.columns
    sprite.vframes = profile.rows
    sprite.scale = profile.actor_scale
    root.add_child(sprite)
    var timeline = ActionTimeline.new()
    if not timeline.load_error.is_empty():
        push_error(timeline.load_error)
        quit(1)
        return
    var player: AnimationPlayer = NativeClips.attach(sprite, timeline, profile)
    for state in Profile.REQUIRED_ACTIONS:
        if not player.has_animation(state):
            push_error("Missing authored animation: " + state)
            quit(1)
            return
    player.play("attack")
    player.advance(0.0)
    if sprite.frame != 12:
        push_error("Authored attack frames were not applied")
        quit(1)
        return
    var broken := Clip.new()
    broken.action = "attack"
    broken.frames = PackedInt32Array([999])
    if broken.valid_for(profile.columns * profile.rows):
        push_error("Out-of-atlas animation frame was accepted")
        quit(1)
        return
    print("ACTOR_ANIMATION_PROFILE_OK")
    quit(0)
