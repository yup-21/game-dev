extends SceneTree
## R26: native dialogue recruits a persistent fighter and unlocks a real encounter.
const Native = preload("res://scripts/content/content_registry.gd")
const Session = preload("res://scripts/game_session.gd")
const Story = preload("res://scripts/opening_story.gd")
const Events = preload("res://scripts/story_event_executor.gd")
const EventResource = preload("res://scripts/content/story_event_definition.gd")
const Battle = preload("res://scripts/battle_model.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("R26 RECRUITMENT FAIL: " + label)

func _run() -> void:
    var native = Native.new()
    check(native.load_error.is_empty(), "native manifest loads")
    for pair in [["story","r26_recruitment_story"],
        ["chapter","r26_recruitment_trial"],
        ["encounter","r26_recruitment_trial_battle"]]:
        check(native.entries(pair[0]).has(pair[1]), "new Resource " + str(pair[1]))
    var event = EventResource.new()
    event.event_type = "recruit_character"
    event.character_id = "green_wanderer"
    check(Events.valid_event(event.to_record()), "Inspector-authored recruit event validates")
    event.event_type = "learn_school"
    event.school_id = "r24_mist_sword"
    check(Events.valid_event(event.to_record()), "Inspector-authored learn-school event validates")
    event.event_type = "set_attribute"
    event.attribute_stat = "MND"
    event.attribute_value = 100
    check(Events.valid_event(event.to_record()), "Inspector-authored attribute event validates")

    var session = Session.new()
    root.add_child(session)
    session.start_new_game("r26_recruitment_trial")
    check(session.phase == "story" and session.character("shen_changfeng") != null
        and session.character("green_wanderer") == null,
        "recruit-at-story combatant is not silently seeded in starting party")
    check(not session.begin_encounter(), "battle locked until dialogue recruits companion")
    check(not session.apply_story_events([
        {"type":"set_flag","flag":"r26_companion_joined","value":true},
        {"type":"recruit_character","character_id":"unknown_actor"}]),
        "unknown recruitment rolls back all previously staged flags")
    check(not session.flags.has("r26_companion_joined")
        and session.character("green_wanderer") == null,
        "transaction rollback preserves flags and party")
    var chapter: Dictionary = session.chapter_definition()
    var story = Story.new(str(chapter.get("story_path","")))
    check(story.load_error.is_empty(), "native story and event graph load")
    if story.load_error.is_empty():
        story.begin()
        story.skip_cinematic()
        check(story.interact_at("r26_wanderer"), "authored NPC interaction opens")
        var events: Array = story.take_events()
        check(events.size() == 3 and session.apply_story_events(events),
            "native story recruits, teaches a school and raises the chapter flag")
        check(story.advance_dialogue() and story.complete_if_ready(session.flags),
            "chapter completion waits for recruited ally's dialogue flag")
    var recruit = session.character("green_wanderer")
    check(recruit != null and session.flags.get("r26_companion_joined",false),
        "recruited ally persists in GameSession")
    if recruit != null:
        check(recruit.learned_schools.has("r24_mist_sword"),
            "native learn-school effect changes persistent character build")
        check(not session.apply_story_events([
            {"type":"set_attribute","character_id":"green_wanderer","stat":"STR","value":23},
            {"type":"switch_school","character_id":"green_wanderer","school_id":"unknown_school"}]),
            "invalid school switch rejects all staged growth")
        check(int(session.character("green_wanderer").attributes["STR"]) != 23,
            "failed transaction does not mutate original runtime")
        check(session.apply_story_events([
            {"type":"switch_school","character_id":"green_wanderer","school_id":"r24_mist_sword"},
            {"type":"set_attribute","character_id":"green_wanderer","stat":"MND","value":20},
            {"type":"grant_item","character_id":"green_wanderer","item_id":"healing_powder","count":1}]),
            "school selection, training and equipment rewards commit together")
        check(session.character("green_wanderer").school_id == "r24_mist_sword"
            and int(session.character("green_wanderer").attributes["MND"]) == 20,
            "learned school and attributes persist")
    check(session.begin_encounter(), "recruited ally now unlocks real battle")
    var options: Dictionary = session.encounter_options()
    check(options.get("combatants",[]).size() == 3,
        "battle roster includes story-recruited player character")
    if not options.is_empty():
        var battle = Battle.new()
        battle.reset(2626,0,"tingfeng",options)
        check(battle.state.outcome == "playing" and battle.state.get_actor(1) != null,
            "real combat engine receives recruit without gameplay fork")
    print("R26_STORY_RECRUITMENT_PASS failures=",failures)
    quit(0 if failures == 0 else 1)
