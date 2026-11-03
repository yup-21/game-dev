extends SceneTree
## Resource-layer migration contract: every real authorable usage resolves to an
## animation action, and every explicit VFX slot resolves to a native asset.
const Native = preload("res://scripts/content/content_registry.gd")
const Assets = preload("res://scripts/asset_registry.gd")
const Profile = preload("res://scripts/content/actor_animation_profile.gd")
const NativeClips = preload("res://scripts/battle_native_sprite_clips.gd")
const Timeline = preload("res://scripts/battle_action_timeline.gd")
const PROFILE_IDS := ["shen_changfeng", "gu_qingshuang", "green_wanderer",
    "black_blade", "night_assassin", "pursuer_captain"]
const EXPECTED_MIGRATED := {
    "r36_school_forms": 41, "r37_tingfeng_cards": 12
}
const COMPAT_MAP := {"walk":"move", "run":"move", "attack1":"attack",
    "attack2":"attack", "attack3":"attack", "attack4":"attack"}
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, msg: String) -> void:
    if not ok:
        failures += 1
        push_error("RESOURCE_ACTION_MIGRATION: " + msg)

func _check_binding(binding: Dictionary, label: String, assets: Variant) -> void:
    var action: String = str(binding.get("animation_action", ""))
    var trigger: String = str(binding.get("vfx_trigger", ""))
    var slot: String = str(binding.get("vfx_slot", ""))
    _check(action in ["attack1", "attack2", "attack3", "attack4", "skill",
        "guard", "evade"], label + " has a real action ID")
    var expected: String = "strike_active" if action.begins_with("attack") else (
        "guard_active" if action == "guard" else
        ("evade_visual_start" if action == "evade" else "skill_visual_active"))
    _check(trigger == expected, label + " cue matches semantic action")
    # An empty slot is deliberate: use existing procedural/event fallback until
    # a suitable approved or candidate native VFX actually exists.
    if not slot.is_empty():
        var spec: Dictionary = assets.record(slot)
        _check(str(spec.get("kind", "")) == "vfx" and
            assets.texture(slot) != null, label + " VFX slot is registered and loadable")

func _run() -> void:
    var timeline = Timeline.new()
    _check(timeline.load_error.is_empty(), "action timeline loads")
    var content = Native.new()
    _check(content.load_error.is_empty(), "content registry: " + content.load_error)
    var assets = Assets.new()
    _check(assets.load_error.is_empty(), "asset registry: " + assets.load_error)
    for name in PROFILE_IDS:
        var profile: WuxiaActorAnimationProfile = load(
            "res://data/native/animations/" + name + ".tres") as WuxiaActorAnimationProfile
        _check(profile != null, "profile exists: " + name)
        if profile == null: continue
        _check(profile.valid_profile(), "profile valid: " + name)
        for action in COMPAT_MAP:
            _check(str(profile.action_fallbacks.get(action, "")) == str(COMPAT_MAP[action]),
                "explicit legacy fallback " + name + ":" + action)
            _check(profile.clip_for(action) == null and
                profile.resolved_clip_for(action) == profile.clip_for(str(COMPAT_MAP[action])),
                "fallback does not fabricate frames " + name + ":" + action)
        _check(profile.clip_for("attack").frame_durations.size() == 3 and
            profile.clip_for("defeat").frame_durations.size() == 2 and
            profile.clip_for("attack").root_offsets.is_empty(),
            "timing entry exists but unmeasured root motion stays empty: " + name)
        var sprite := Sprite2D.new()
        sprite.texture = profile.idle_atlas()
        sprite.hframes = profile.idle_columns()
        sprite.vframes = profile.idle_rows()
        root.add_child(sprite)
        var player: AnimationPlayer = NativeClips.attach(sprite, timeline, profile)
        for action in Profile.MODERN_REQUIRED_ACTIONS:
            _check(player.has_animation(action) and
                profile.resolved_clip_for(action) != null,
                "all twelve runtime actions resolve " + name + ":" + action)
        sprite.queue_free()
    var catalog_total: int = 0
    for catalog_id in EXPECTED_MIGRATED:
        var rule: Dictionary = content.entries("rule_catalog").get(catalog_id, {})
        var data: Dictionary = rule.get("data", {})
        var catalog_count := 0
        for card in data.get("cards", []):
            for usage in card.get("usages", []):
                catalog_count += 1
                _check_binding(usage, str(catalog_id) + ":" + str(card.id)
                    + ":" + str(usage.id), assets)
        _check(catalog_count == int(EXPECTED_MIGRATED[catalog_id]),
            "all rule usages migrated: " + str(catalog_id))
        catalog_total += catalog_count
    var skills := 0
    for skill in content.entries("skill").values():
        for usage in skill.get("usages", []):
            skills += 1
            _check_binding(usage, "skill " + str(skill.id) + ":" + str(usage.id), assets)
    _check(skills == 5, "all five skill usages migrated")
    var technique_nodes := 0
    for technique in content.entries("technique").values():
        for node in technique.get("nodes", []):
            if not bool(node.get("available", true)):
                continue
            technique_nodes += 1
            _check_binding(node, "technique " + str(technique.id) +
                ":" + str(node.id), assets)
    _check(technique_nodes == 6, "all six available technique nodes migrated")
    var hero: WuxiaCharacterDefinition = content.resource_for(
        "character", "shen_changfeng") as WuxiaCharacterDefinition
    _check(hero != null and hero.animation_profile != null and
        hero.animation_profile.action_fallbacks.size() == 6,
        "live hero references migrated profile, not an unused template")
    _check(catalog_total == 53, "53 martial usages checked")
    print("RESOURCE_ACTION_MIGRATION_PASS failures=%d" % failures)
    quit(1 if failures > 0 else 0)
