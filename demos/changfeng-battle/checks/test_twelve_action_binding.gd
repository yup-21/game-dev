extends SceneTree
## Native twelve-action animation and one-animation/one-VFX skill binding.
const Driver = preload("res://scripts/hd2d_animation.gd")
const VFX = preload("res://scripts/battle_vfx_2d.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, label: String) -> void:
    if not condition:
        failures += 1
        push_error("TWELVE_ACTION_BINDING: " + label)

func _run() -> void:
    var legacy = load("res://data/templates/actor_animation_profile.tres")
    check(legacy != null and legacy.valid_profile(), "legacy nine-action resources remain valid")
    var profile = load("res://checks/fixtures/animation_profile_12.tres") as WuxiaActorAnimationProfile
    check(profile != null and profile.valid_profile(), "twelve-action profile is valid")
    if profile == null or not profile.valid_profile():
        quit(1)
        return
    var host := Node2D.new()
    root.add_child(host)
    var sprite := Sprite2D.new()
    sprite.texture = profile.atlas
    host.add_child(sprite)
    var driver = Driver.new()
    driver.register_actor(1, sprite, Vector2i.RIGHT, profile)
    var player: AnimationPlayer = sprite.get_node("NativeSpriteAnimation")
    for action in WuxiaActorAnimationProfile.BASE_ACTIONS:
        check(player.has_animation(action), "native action registered: " + action)
    check(player.has_animation("skill_mist"), "custom skill action registered")
    for i in range(4):
        var action: String = "attack%d" % (i + 1)
        driver.play(1, action)
        check(sprite.frame == 12 + i, "independent frame for " + action)
    driver.events([{"type": "ATTACK_DECLARED", "actor_id": 1,
        "target_id": 2, "animation_action": "attack4"}])
    check(driver.tracks[1].state == "attack4" and sprite.frame == 15,
        "attack usage can select attack4")
    driver.events([{"type": "CARD_PLAYED", "actor_id": 1,
        "animation_action": "skill_mist"}])
    check(driver.tracks[1].state == "skill_mist" and sprite.frame == 16,
        "nonattack skill can select a custom action")
    driver.events([{"type": "CARD_PLAYED", "actor_id": 1,
        "animation_action": "missing_action"}])
    check(driver.tracks[1].state == "skill_mist",
        "invalid explicit animation logs an error without silently playing a fallback")
    driver.play(1, "run")
    check(driver.tracks[1].loop, "run loops independently")
    driver.play(1, "defeat")
    driver.update(2.0)
    check(driver.tracks[1].state == "defeat", "defeat holds its final pose")

    var usage := WuxiaSkillUsageDefinition.new()
    usage.usage_id = "cut"
    usage.animation_action = "attack3"
    usage.vfx_slot = load("res://checks/fixtures/scene_vfx_definition.tres") as WuxiaVFXDefinition
    usage.vfx_trigger = "strike_active"
    var record: Dictionary = usage.to_record()
    check(str(record.get("animation_action", "")) == "attack3",
        "skill usage serializes exactly one action ID")
    check(str(record.get("vfx_slot", "")) == "r117_scene_marker" and
        str(record.get("vfx_trigger", "")) == "strike_active",
        "scene VFX binds through one typed Resource and cue")
    var stage := WuxiaTechniqueNodeDefinition.new()
    stage.node_id = "stage"
    stage.animation_action = "attack2"
    check(str(stage.to_record().get("animation_action", "")) == "attack2",
        "technique stage can select an action")

    var painted := Node2D.new()
    host.add_child(painted)
    var actor := Node2D.new()
    actor.position = Vector2(47, 82)
    painted.add_child(actor)
    var effects = VFX.new(painted)
    check(effects.native_assets._register(usage.vfx_slot.to_record()),
        "scene VFX registers as an authored native asset")
    effects.handle_events([{"type": "ATTACK_DECLARED", "actor_id": 1,
        "vfx_slot": "r117_scene_marker"}], {1: actor})
    check(effects.skill_scenes.is_empty(),
        "scene VFX does not instantiate on attack declaration")
    effects.handle_action_cues([{"name": "preparation", "vfx_trigger": "strike_active",
        "actor_id": 1, "vfx_slot": "r117_scene_marker"}], {1: actor})
    check(effects.skill_scenes.is_empty(), "unmatched scene VFX cue is ignored")
    effects.handle_action_cues([{"name": "strike_active", "vfx_trigger": "strike_active",
        "actor_id": 1, "vfx_slot": "r117_scene_marker", "profile": "attack",
        "event_type": "ATTACK_DECLARED"}], {1: actor})
    check(effects.skill_scenes.size() == 1 and effects.bursts.is_empty(),
        "configured PackedScene instantiates only at the authored cue")
    effects.update(2.0)
    check(effects.skill_scenes.is_empty(), "custom effect is cleaned up")
    effects.clear()
    host.free()
    print("TWELVE_ACTION_BINDING_PASS failures=", failures)
    quit(1 if failures > 0 else 0)
