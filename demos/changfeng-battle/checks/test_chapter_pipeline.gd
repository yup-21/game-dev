extends SceneTree
## Contract test: an independent chapter, NPC and conditional story are data-only.
const Session = preload("res://scripts/game_session.gd")
const Chapters = preload("res://scripts/chapter_catalog.gd")
const Story = preload("res://scripts/opening_story.gd")
const Router = preload("res://scripts/chapter_scene_router.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("CHAPTER_PIPELINE: " + label)

func _run() -> void:
    var catalog = Chapters.new()
    check(catalog.load_error.is_empty(),"legacy and native chapter definitions load and cross-reference")
    check(catalog.chapter_order.slice(0,2)==["rain_escort_prologue","river_watch"]
        and catalog.first_chapter_id()=="rain_escort_prologue"
        and catalog.chapter_order.has("r21_crossroads"),
        "chapter index has deterministic entry and order")
    var second: Dictionary = catalog.get_chapter("river_watch")
    check(second.get("encounter_id","")=="river_watch_ambush"
        and second.get("scene",{}).get("npc_character_id","")=="river_messenger",
        "new battle and new story-only NPC resolve from content data")
    check(Router.path_for("story")=="res://opening.tscn"
        and Router.path_for("battle")=="res://battle_hd2d.tscn"
        and Router.path_for("aftermath")=="res://demo_result.tscn"
        and Router.path_for("untrusted").is_empty(),"only safe scene templates are routable")
    var session = Session.new()
    root.add_child(session)
    session.start_new_game()
    check(not session.begin_encounter(),"chapter prerequisites cannot be skipped")
    session.record_choice("escort_urgent",0)
    session.record_story_event("obtain_fragment")
    check(session.begin_encounter(),"first chapter admits its declared encounter")
    check(session.report_battle("victory",0),"first encounter result transitions to aftermath")
    check(session.can_advance_chapter() and session.advance_chapter()
        and session.phase=="story" and session.chapter_id=="river_watch",
        "a victory opens the second chapter without replacing the scene script")
    check(not session.begin_encounter(),"second chapter encounter gated by a declarative flag")
    var story = Story.new(str(second.story_path))
    check(story.load_error.is_empty(),"new authored dialogue validates")
    story.begin()
    story.skip_cinematic()
    check(story.interact() and story.take_events().size()==1,
        "NPC interaction emits a typed event on its entry node")
    check(session.apply_story_events([{"type":"set_flag","flag":"met_messenger","value":true}]),
        "typed event commits in the shared session")
    check(story.advance_dialogue(),"first dialogue advances")
    check(story.advance_dialogue(),"second dialogue advances")
    var options: Array = story.available_choices(session.flags)
    check(options.size()==2 and story.available_choices({"met_messenger":true}).size()==1,
        "second chapter checks prior branching flags")
    check(story.choose(0,session.flags),"conditional choice selects the authored branch")
    check(session.apply_story_events(story.take_events()),"choice and reached node effects commit together")
    check(bool(session.flags.get("messenger_trust",false))
        and int(session.character("shen_changfeng").inventory.stacks.get("breath_pill",0))==2,
        "branch effects and NPC item reward enter the party inventory")
    var before: Dictionary = session.character("shen_changfeng").inventory.snapshot()
    check(not session.apply_story_events([
        {"type":"grant_item","character_id":"shen_changfeng","item_id":"healing_powder","count":1},
        {"type":"grant_item","character_id":"shen_changfeng","item_id":"does_not_exist","count":1}
    ]) and session.character("shen_changfeng").inventory.snapshot()==before,
        "mixed invalid story rewards roll back atomically")
    check(session.begin_encounter()
        and session.encounter_options().get("combatants",[]).size()==6,
        "second chapter can launch its own six-actor encounter")
    check(not session.begin_encounter("escort_ambush"),
        "a chapter cannot bypass its declared encounter by ID")
    print("CHAPTER_PIPELINE_PASS failures=",failures)
    session.free()
    quit(0 if failures==0 else 1)
