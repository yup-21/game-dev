extends SceneTree
## R24 infrastructure contract: native school schema, reactive status and NPC triggers.
const Native = preload("res://scripts/content/content_registry.gd")
const Manifest = preload("res://scripts/content/content_manifest.gd")
const School = preload("res://scripts/content/school_definition.gd")
const DeckEntry = preload("res://scripts/content/school_deck_entry_definition.gd")
const Skill = preload("res://scripts/content/skill_definition.gd")
const Usage = preload("res://scripts/content/skill_usage_definition.gd")
const Effect = preload("res://scripts/content/effect_definition.gd")
const Model = preload("res://scripts/battle_model.gd")
const BuffCatalog = preload("res://scripts/status_catalog.gd")
const Story = preload("res://scripts/opening_story.gd")
const Flow = preload("res://scripts/opening_flow.gd")
const Chapters = preload("res://scripts/chapter_catalog.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("R24 FOUNDATION FAIL: " + label)

func _run() -> void:
    var manifest = Manifest.new()
    var school = School.new()
    school.content_id = "r24_test_school"
    school.display_name = "测试门派"
    school.identity = "双式基础牌"
    var skills: Array = []
    for id in ["r24_test_one","r24_test_two"]:
        var skill = Skill.new()
        skill.content_id = id
        skill.display_name = id
        skill.school_id = school.content_id
        skill.generated_only = false
        var effect = Effect.new()
        effect.effect_type = "gain_qi"
        effect.amount = 1.0
        var usage = Usage.new()
        usage.usage_id = "action"
        usage.display_name = id
        usage.effects.append(effect)
        skill.usages.append(usage)
        skills.append(skill)
        school.core_forms.append(skill)
        var entry = DeckEntry.new()
        entry.card = skill
        entry.count = 6
        school.deck.append(entry)
        manifest.skills.append(skill)
    manifest.schools.append(school)
    var imported = Native.new()
    check(imported.import_manifest(manifest)
        and imported.entries("school").has("r24_test_school"),
        "native school + two authored skills import without JSON")
    check(imported.entries("school").get("r24_test_school",{}).get("deck",{}).get("cards",[]).size() == 2,
        "12-card deck with two stable core skill IDs")
    var invalid = Manifest.new()
    var missing_core = School.new()
    missing_core.content_id = "r24_invalid"
    invalid.schools.append(missing_core)
    check(not imported.import_manifest(invalid), "incomplete school is rejected atomically")

    var catalog = BuffCatalog.new()
    var condition: Dictionary = {"type":"self_status","value":"iron_body"}
    var conditional: Dictionary = {"when":condition,
        "modifiers":[{"stat":"STR","op":"flat","value":3}]}
    var spec: Dictionary = {"schema_version":1,"id":"r24_probe_buff",
        "name":"条件测试","public":true,"stack_limit":1,
        "expiry":{"kind":"permanent"},"modifiers":[],
        "conditional_modifiers":[conditional]}
    check(catalog._valid(spec), "status-condition gated modifier schema accepted")
    var disallowed: Dictionary = spec.duplicate(true)
    disallowed.conditional_modifiers[0].when = {"type":"qi_at_least","value":2}
    check(not catalog._valid(disallowed), "volatile Qi gate requires a different trigger service")
    var model = Model.new()
    var actor = model.state.get_actor(0)
    model.cards.statuses[spec.id] = spec
    check(model.statuses.add(0,spec.id) and actor.attributes.STR == 10,
        "conditional buff sleeps until status precondition")
    check(model.statuses.add(0,"iron_body") and actor.attributes.STR == 13,
        "status event activates conditional modifier")
    model.statuses.remove(0,"iron_body")
    check(actor.attributes.STR == 10, "removal automatically retracts modifier")

    var chapters = Chapters.new()
    var chapter: Dictionary = chapters.get_chapter("r21_crossroads")
    var scene: Dictionary = chapter.get("scene",{})
    var flow = Flow.new()
    flow.chapter_scene = scene
    flow.player_pos = Vector2(1220,600)
    check(flow._npcs().size() == 2 and str(flow._nearest_npc().get("character_id","")) == "escort_elder",
        "nearest one of two independent authored NPCs selected")
    var story = Story.new(str(chapter.get("story_path","")))
    story.begin()
    story.skip_cinematic()
    check(story.interact_at("r21_intro") and story.dialogue_id == "r21_intro",
        "NPC trigger opens the correct graph node")
    flow.free()
    print("R24_FOUNDATION_PASS failures=",failures)
    quit(0 if failures == 0 else 1)
