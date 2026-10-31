extends SceneTree
## R29: original story content now uses typed cards, not GameSession marker shortcuts.
const Native = preload("res://scripts/content/content_registry.gd")
const Session = preload("res://scripts/game_session.gd")
const Fixture = preload("res://checks/story_test_helper.gd")
const Art = preload("res://scripts/hd2d_art_catalog.gd")
const Fallback = preload("res://scripts/fallback_assets.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("R29_MIGRATION_FAIL: " + label)

func _run() -> void:
    var native = Native.new()
    check(native.load_error.is_empty(), "manifest resolves all native cards")
    for id in ["rain_escort_prologue","river_watch"]:
        check(native.entries("chapter").has(id) and native.document("r25_" + id).is_empty(),
            "chapter migrated from opaque data: " + id)
    var original = native.entries("story").get("rain_escort_prologue_story",{})
    var nodes: Dictionary = {}
    for node in original.get("dialogues",[]):
        nodes[str(node.id)] = node
    check(original.has("resource_path")
        and nodes.has("escort_urgent") and nodes.has("escort_fragment"),
        "prologue dialogue loads typed nodes")
    check(nodes.get("escort_urgent",{}).get("choices",[]).size() == 2
        and nodes.get("escort_fragment",{}).get("events",[]).size() == 2
        and not nodes.get("escort_fragment",{}).has("event"),
        "branch and clue effects are declarative, with no legacy marker")
    var session = Session.new()
    root.add_child(session)
    for choice in [0,1]:
        session.start_new_game()
        check(Fixture.finish_prologue(session,choice), "full authored branch %d" % choice)
        check(session.choices.size() == 1
            and bool(session.flags.get("helped_escort",false)) == (choice == 0)
            and bool(session.flags.get("obtained_fragment",false))
            and int(session.items.get("taixu_fragment",0)) == 1,
            "authored choice and one-time clue match branch %d" % choice)
        check(session.begin_encounter() and session.encounter_options().get("combatants",[]).size() == 6,
            "unchanged six-person battle accepts branch %d" % choice)
    check(Fallback.ACTOR_SHEET.get_size() == Vector2(1536,1024)
        and Fallback.PORTRAIT.get_width() >= 256
        and Fallback.STORY_POSE.get_height() >= 256
        and Fallback.SCENE.get_width() == 1600,
        "all four neutral fallback assets import at expected dimensions")
    check(Art.sheet_for_character("unbound_test_actor") == Fallback.ACTOR_SHEET
        and Art.portrait_for_character("unbound_test_actor") == Fallback.PORTRAIT
        and Art.story_pose_for_character("unbound_test_actor") == Fallback.STORY_POSE,
        "missing bindings resolve to dedicated placeholders")
    check(Art.portrait_for_character("shen_changfeng") != Fallback.PORTRAIT
        and Art.uses_supplied_sheet_for_character("gu_qingshuang"),
        "valid original artwork is never downgraded")
    for path in ["res://battle.tscn","res://party_battle.tscn",
            "res://scripts/battle_view.gd","res://scripts/party_battle_view.gd"]:
        check(not FileAccess.file_exists(path),"obsolete battle presentation removed: " + path)
    session.free()
    print("R29_NATIVE_CLEANUP_PASS failures=",failures)
    quit(1 if failures > 0 else 0)
