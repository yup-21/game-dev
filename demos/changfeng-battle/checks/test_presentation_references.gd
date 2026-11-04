extends SceneTree
## Negative contracts: broken references fail before presentation begins.
const Native = preload("res://scripts/content/content_registry.gd")
const Manifest = preload("res://scripts/content/content_manifest.gd")
const Validation = preload("res://scripts/content/presentation_reference_validator.gd")
const Art = preload("res://scripts/hd2d_art_catalog.gd")
const Assets = preload("res://scripts/asset_registry.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        printerr("PRESENTATION_REFERENCE_FAIL: " + message)

func _definitions_with(field: String, value: String) -> Dictionary:
    var altered: Dictionary = native.definitions.duplicate(true)
    var skill: Dictionary = altered["skill"]["r20_follow"]
    var usage: Dictionary = skill["usages"][0]
    usage[field] = value
    return altered

var native

func _run() -> void:
    native = Native.new()
    check(native.load_error.is_empty(), "production manifest validates: " + native.load_error)
    var definitions: Dictionary = native.definitions
    var resources: Dictionary = native.definition_resources
    check(Validation.validate(definitions, resources).is_empty(),
        "native character, timeline, VFX and map references resolve")

    var bad_action: String = Validation.validate(
        _definitions_with("animation_action", "action_not_authored"), resources)
    check(bad_action.contains("unknown animation action"), "nonempty unknown animation rejected: " + bad_action)

    var bad_trigger: String = Validation.validate(
        _definitions_with("vfx_trigger", "not_a_timeline_cue"), resources)
    check(bad_trigger.contains("unknown timeline cue"), "nonempty unknown cue rejected: " + bad_trigger)

    var bad_slot: String = Validation.validate(
        _definitions_with("vfx_slot", "not_an_asset_slot"), resources)
    check(bad_slot.contains("unknown VFX slot"), "nonempty unknown VFX rejected: " + bad_slot)

    var incorrect_kind: String = Validation.validate(
        _definitions_with("vfx_slot", "r22_shen_portrait"), resources)
    check(incorrect_kind.contains("unknown VFX slot"), "a portrait is not a VFX slot")

    var no_portrait: Dictionary = resources.duplicate(true)
    var portrait_card: WuxiaCharacterDefinition = native.resource_for(
        "character", "shen_changfeng").duplicate() as WuxiaCharacterDefinition
    portrait_card.portrait = null
    no_portrait["character"]["shen_changfeng"] = portrait_card
    check(Validation.validate(definitions, no_portrait).contains("no portrait Resource"),
        "formal combatant missing portrait fails")

    var explicit_placeholder: Texture2D = load(
        "res://assets/imported/placeholders/portraits/default_portrait.svg") as Texture2D
    check(explicit_placeholder != null, "declared neutral placeholder imports")
    if explicit_placeholder != null:
        portrait_card.portrait = explicit_placeholder
        check(Validation.validate(definitions, no_portrait).is_empty(),
            "explicit Resource placeholder is allowed")

    var no_background: Dictionary = resources.duplicate(true)
    var map_id: String = str(no_background.get("map", {}).keys()[0])
    var map_card: Resource = no_background["map"][map_id].duplicate()
    map_card.set("background", null)
    no_background["map"][map_id] = map_card
    check(Validation.validate(definitions, no_background).contains("no usable background"),
        "required map texture absent fails")

    var broken_timeline: Dictionary = resources.duplicate(true)
    var original: WuxiaActionTimelineDefinition = native.resource_for(
        "action_timeline", "r32_default_action_timeline") as WuxiaActionTimelineDefinition
    var invalid_timeline := WuxiaActionTimelineDefinition.new()
    invalid_timeline.clips = original.clips
    var missing_clip := WuxiaActionEventBinding.new()
    missing_clip.event_type = "BROKEN_EVENT"
    missing_clip.clip_id = "missing_timeline_clip"
    var event_bindings: Array[Resource] = [missing_clip]
    invalid_timeline.event_bindings = event_bindings
    broken_timeline["action_timeline"]["r32_default_action_timeline"] = invalid_timeline
    check(Validation.validate(definitions, broken_timeline).contains("missing clip"),
        "timeline event referencing missing clip rejected")

    var partial := Manifest.new()
    var invalid := WuxiaCharacterDefinition.new()
    invalid.content_id = "incomplete_battle_actor"
    invalid.display_name = "Incomplete"
    invalid.battle_actor_id = 99
    partial.characters.append(invalid)
    var loader := Native.new()
    check(not loader.import_manifest(partial) and
        loader.load_error.contains("portrait") and loader.entries("character").is_empty(),
        "invalid manifest rolls back atomically with descriptive loading error")

    var assets := Assets.new()
    check(assets.vfx_spec("shen_sword_thrust").get("kind", "") == "vfx" and
        assets.vfx_spec("missing_explicit_slot").is_empty(),
        "runtime VFX slot lookup cannot alias missing ID")
    check(Art.portrait_for_character("river_messenger") == null and
        Art.sheet_for_character("river_messenger") != null,
        "story-only messenger portrait is optional without silent placeholder")
    print("PRESENTATION_REFERENCE_PASS failures=", failures)
    quit(1 if failures > 0 else 0)
