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
        "target_id": 2, "animation_id": "attack4"}])
    check(driver.tracks[1].state == "attack4" and sprite.frame == 15,
        "attack usage can select attack4")
    driver.events([{"type": "ACTION_PRESENTATION", "actor_id": 1,
        "animation_id": "skill_mist"}])
    check(driver.tracks[1].state == "skill_mist" and sprite.frame == 16,
        "nonattack skill can select a custom action")
    driver.events([{"type": "ACTION_PRESENTATION", "actor_id": 1,
        "animation_id": "missing_action"}])
    check(driver.tracks[1].state == "skill_mist",
        "invalid explicit animation logs an error without silently playing a fallback")
    driver.play(1, "run")
    check(driver.tracks[1].loop, "run loops independently")
    driver.play(1, "defeat")
    driver.update(2.0)
    check(driver.tracks[1].state == "defeat", "defeat holds its final pose")

    var usage := WuxiaSkillUsageDefinition.new()
    usage.usage_id = "cut"
    usage.animation_id = "attack3"
    usage.vfx_scene = load("res://checks/fixtures/skill_vfx_marker.tscn")
    var record: Dictionary = usage.to_record()
    check(str(record.get("animation_id", "")) == "attack3",
        "skill usage serializes exactly one action ID")
    check(str(record.get("vfx_path", "")) == "res://checks/fixtures/skill_vfx_marker.tscn",
        "skill usage serializes one optional PackedScene path")
    var stage := WuxiaTechniqueNodeDefinition.new()
    stage.node_id = "stage"
    stage.animation_id = "attack2"
    check(str(stage.to_record().get("animation_id", "")) == "attack2",
        "technique stage can select an action")

    var painted := Node2D.new()
    host.add_child(painted)
    var actor := Node2D.new()
    actor.position = Vector2(47, 82)
    painted.add_child(actor)
    var effects = VFX.new(painted)
    effects.handle_events([{"type": "ACTION_PRESENTATION", "actor_id": 1,
        "vfx_path": "res://checks/fixtures/skill_vfx_marker.tscn"}], {1: actor})
    check(effects.skill_scenes.size() == 1,
        "configured VFX scene instantiates from the visual event")
    effects.update(2.0)
    check(effects.skill_scenes.is_empty(), "custom effect is cleaned up")
    effects.clear()
    host.free()
    print("TWELVE_ACTION_BINDING_PASS failures=", failures)
    quit(1 if failures > 0 else 0)
