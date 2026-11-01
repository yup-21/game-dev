extends SceneTree
## R21: a new story, chapter, two NPCs, encounter and quest use only .tres.
const Native = preload("res://scripts/content/content_registry.gd")
const Stories = preload("res://scripts/story_runtime.gd")
const Quests = preload("res://scripts/quest_runtime.gd")
const Chapters = preload("res://scripts/chapter_catalog.gd")
const Scenarios = preload("res://scripts/scenario_director.gd")
const Session = preload("res://scripts/game_session.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("R21_STORY_QUEST_FAIL: " + label)

func _run() -> void:
    var native = Native.new()
    check(native.load_error.is_empty() and native.entries("story").has("r21_crossroads_story"),
        "native story validated through the manifest")
    check(native.entries("chapter").has("r21_crossroads")
        and native.entries("encounter").has("r21_gate_ambush")
        and native.entries("quest").has("r21_find_the_path"),
        "chapter, encounter and quest registered by stable unique IDs")
    var stories = Stories.new()
    var story = stories.create("r21_crossroads_story")
    check(stories.load_error.is_empty() and story != null, "story factory resolves Resource")
    if story == null:
        quit(1)
        return
    var quests = Quests.new()
    check(quests.load_error.is_empty(), "quest objective catalog validates")
    var chapters = Chapters.new()
    var chapter: Dictionary = chapters.get_chapter("r21_crossroads")
    check(chapters.load_error.is_empty() and chapter.get("scene",{}).get("npcs",[]).size() == 2,
        "chapter scene declares two independent NPC triggers")
    check(str(chapter.get("story_id","")) == "r21_crossroads_story",
        "chapter links separate story ID without collision")
    var director = Scenarios.new()
    check(director.load_error.is_empty() and director.encounter("r21_gate_ambush").get("combatants",[]).size() == 2,
        "native encounter joins canonical scenario registry")

    var session = Session.new()
    root.add_child(session)
    session.start_new_game("r21_crossroads")
    check(session.phase == "story" and session.chapter_id == "r21_crossroads"
        and session.character("shen_changfeng") != null,
        "native chapter starts using the existing CharacterFactory")
    var initial: Dictionary = session.quest_status("r21_find_the_path")
    check(initial.get("objectives",[]).size() == 3 and not bool(initial.get("complete",true)),
        "three-objective quest begins incomplete")
    check(not session.begin_encounter(), "chapter's flag gate cannot be skipped")
    story.begin()
    story.skip_cinematic()
    check(story.interact(), "native story begins via unchanged interaction contract")
    check(session.apply_story_events(story.take_events()),
        "entering the first dialogue commits a typed event")
    check(bool(session.flags.get("met_r21_guide",false)),
        "typed event set a shared session flag")
    check(story.advance_dialogue(), "graph advances to choice node")
    check(story.available_choices({}).is_empty()
        and story.available_choices(session.flags).size() == 1,
        "Inspector-authored flag requirements gate choices")
    check(story.choose(0,session.flags) and session.apply_story_events(story.take_events()),
        "choice reaches next node and atomically grants the map clue")
    var middle: Dictionary = session.quest_status("r21_find_the_path")
    var progress: Array = middle.get("objectives",[])
    check(progress.size() == 3 and progress[0].complete and progress[1].complete
        and not progress[2].complete, "quest derives partial progress from facts")
    check(session.begin_encounter()
        and session.encounter_options().get("combatants",[]).size() == 2,
        "native battle route accepts the same authoritative options")
    check(session.report_battle("victory",0),
        "native chapter routes victory through the existing reward transaction")
    var final: Dictionary = session.quest_status("r21_find_the_path")
    check(bool(final.get("complete",false))
        and session.items.get("r21_victory_token",0) == 1,
        "all three objectives close and victory reward is granted once")
    check(session.quest_status("unknown").is_empty(),
        "unknown quests never expose partial state")
    print("R21_STORY_QUEST_PASS failures=",failures)
    session.free()
    quit(0 if failures == 0 else 1)
