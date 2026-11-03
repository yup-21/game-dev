extends SceneTree
## Proves authored VFX pixels/resources and the hero's canonical martial usages.
const Assets = preload("res://scripts/asset_registry.gd")
const VFX = preload("res://scripts/battle_vfx_2d.gd")
var failures := 0
const SLOTS := {
    "shen_sword_thrust": 0, "shen_sword_sweep": 4,
    "shen_sword_heavy": 8, "shen_wind_guard": 12, "shen_wind_step": 16
}

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("SHEN_MARTIAL_VFX: " + message)

func _run() -> void:
    var assets = Assets.new()
    _check(assets.load_error.is_empty(), "assets validate: " + assets.load_error)
    var stage := Node2D.new()
    root.add_child(stage)
    var actor := Node2D.new()
    stage.add_child(actor)
    var effects = VFX.new(stage)
    for slot in SLOTS:
        var spec: Dictionary = assets.record(slot)
        var tex: Texture2D = assets.texture(slot)
        _check(not spec.is_empty() and tex != null, "slot registered: " + slot)
        if tex == null:
            continue
        _check(tex.get_size() == Vector2(1024, 1280), "atlas dimensions: " + slot)
        _check(int(spec.columns) == 4 and int(spec.rows) == 5 and
            spec.frame_indices.size() == 4 and
            int(spec.frame_indices[0]) == int(SLOTS[slot]),
            "four ordered frames: " + slot)
        var count: int = effects.bursts.size()
        effects.handle_events([{"type":"ATTACK_DECLARED", "actor_id":0}], {0:actor})
        _check(effects.bursts.size() == count, "do not fire on attack declaration")
        var trigger := "strike_active"
        effects.handle_action_cues([{"name":trigger, "vfx_trigger":trigger,
            "profile":"attack", "event_type":"ATTACK_DECLARED",
            "actor_id":0, "vfx_slot":slot}], {0:actor})
        _check(effects.bursts.size() == count + 1, "fires at authored cue: " + slot)
        if effects.bursts.size() > count:
            var burst: Dictionary = effects.bursts[-1]
            var sprite: Sprite2D = burst.node.get_node_or_null("AuthoredVFX") as Sprite2D
            _check(sprite != null and sprite.texture != null and
                sprite.frame == int(SLOTS[slot]), "authored sprite active: " + slot)
            effects.update(0.24)
            if sprite != null:
                _check(sprite.frame > int(SLOTS[slot]), "atlas advances: " + slot)
        effects.clear()
    var expected := {
        "r36_school_forms": {"wind_flow":["probe","follow"],
            "wind_final":["expose","finisher"],
            "step_shadow":["step","evasion"], "step_swallow":["guard_step","strike"]},
        "r37_tingfeng_cards": {"tf_probe":["probe"], "tf_sunder":["heavy","expose"],
            "tf_step":["step","evasion"], "tf_guard":["guard","yield","intercept"],
            "tf_change":["change","attack_counter","defense_counter"],
            "tf_follow":["follow"]}
    }
    for catalog_id in expected:
        var catalog: WuxiaRuleCatalogDefinition = load(
            "res://data/native/rule_catalogs/" + str(catalog_id) + ".tres")
        _check(catalog != null, "rule catalog exists: " + str(catalog_id))
        if catalog == null: continue
        var records: Dictionary = catalog.to_record()
        _check(not records.is_empty(), "catalog validates: " + str(catalog_id))
        var found := {}
        for card in records.get("data", {}).get("cards", []):
            if expected[catalog_id].has(str(card.get("id", ""))):
                for usage in card.usages:
                    if expected[catalog_id][str(card.id)].has(str(usage.id)):
                        found[str(card.id) + ":" + str(usage.id)] = true
                        _check(SLOTS.has(str(usage.get("vfx_slot", ""))) and
                            not str(usage.get("animation_action", "")).is_empty() and
                            not str(usage.get("vfx_trigger", "")).is_empty(),
                            "bound " + str(card.id) + ":" + str(usage.id))
        for card_id in expected[catalog_id]:
            for usage_id in expected[catalog_id][card_id]:
                _check(found.has(str(card_id) + ":" + str(usage_id)),
                    "usage exists " + str(card_id) + ":" + str(usage_id))
    var technique: WuxiaTechniqueDefinition = load(
        "res://data/native/techniques/tf_change_stage.tres")
    _check(technique != null and not technique.to_record().is_empty(),
        "equipped change-stage technique validates")
    if technique != null:
        for node in technique.nodes:
            if node.node_id in ["change", "attack_counter", "defense_counter"]:
                _check(SLOTS.has(node.vfx_slot) and not node.animation_action.is_empty(),
                    "technique node bound: " + node.node_id)
    var hero: WuxiaCharacterDefinition = load(
        "res://data/native/characters/shen_changfeng.tres")
    _check(hero != null and hero.content_id == "shen_changfeng" and
        hero.learned_schools.has("wind_sword") and
        hero.learned_schools.has("tingfeng") and
        hero.learned_schools.has("step"), "targets currently learned hero schools")
    print("SHEN_MARTIAL_VFX_PASS failures=%d" % failures)
    quit(1 if failures > 0 else 0)
