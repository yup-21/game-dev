extends SceneTree
## R24 gate: only .tres files author a character, school, buffs, items,
## four-objective quest, dual-NPC chapter, encounter, freehand map and art.
const Native = preload("res://scripts/content/content_registry.gd")
const Schools = preload("res://scripts/school_catalog.gd")
const Registry = preload("res://scripts/character_registry.gd")
const Factory = preload("res://scripts/character_factory.gd")
const StatusCatalog = preload("res://scripts/status_catalog.gd")
const Items = preload("res://scripts/item_catalog.gd")
const Assets = preload("res://scripts/asset_registry.gd")
const Art = preload("res://scripts/hd2d_art_catalog.gd")
const Session = preload("res://scripts/game_session.gd")
const Story = preload("res://scripts/opening_story.gd")
const Model = preload("res://scripts/battle_model.gd")
const MapBake = preload("res://scripts/map_bake.gd")
const Spatial = preload("res://scripts/battle_spatial_service.gd")
const Techniques = preload("res://scripts/technique_runtime.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("R24 CLOSURE FAIL: " + label)

func _run() -> void:
    var native = Native.new()
    check(native.load_error.is_empty(), "all authored native records validate: " + native.load_error)
    for pair in [["character","r24_lan_chen"],["school","r24_mist_sword"],
        ["skill","r24_mist_veil"],["skill","r24_mist_cut"],["skill","r24_mist_follow"],
        ["technique","r24_mist_steps"],["buff","r24_dew_guard"],
        ["buff","r24_mist_edge"],["item","r24_reed_sword"],
        ["item","r24_mist_pill"],["quest","r24_fog_pass_quest"],
        ["story","r24_fog_pass_story"],["chapter","r24_fog_pass"],
        ["encounter","r24_fog_pass_battle"],["map","r24_fog_pass_map"]]:
        check(native.entries(pair[0]).has(pair[1]), "native " + str(pair[0]) + ": " + str(pair[1]))

    var schools = Schools.new()
    var school: Dictionary = schools.get_school("r24_mist_sword")
    check(schools.load_error.is_empty() and school.get("core_forms",[]).size() == 2
        and schools.deck_for("r24_mist_sword",[]).size() == 2,
        "new school registered in canonical SchoolCatalog with two core forms")
    var registry = Registry.new()
    var factory = Factory.new(registry)
    var profile: Dictionary = registry.get_profile("r24_lan_chen")
    check(registry.load_error.is_empty() and profile.get("school_id","") == "r24_mist_sword",
        "new recruitable character is visible in the roster")
    var recruit = factory.create_runtime("r24_lan_chen")
    check(recruit != null and factory.load_error.is_empty(),
        "real CharacterFactory creates a persistent recruit with loadout")
    if recruit != null:
        var uid: String = str(recruit.inventory.equipped.get("weapon",""))
        var snap: Dictionary = recruit.inventory.snapshot()
        check(int(recruit.inventory.stacks.get("r24_mist_pill",0)) == 2
            and snap.instances.get(uid,{}).get("definition_id","") == "r24_reed_sword",
            "native consumables and equipment seed/equip without runtime changes")
    var statuses = StatusCatalog.new()
    var items = Items.new()
    check(statuses.load_error.is_empty() and statuses.definitions.has("r24_mist_edge")
        and statuses.get_buff("r24_mist_edge").get("conditional_modifiers",[]).size() == 1,
        "two native buffs incl status-reactive condition pass validation")
    check(items.load_error.is_empty() and items.get_item("r24_reed_sword").get("kind","") == "equipment"
        and items.get_item("r24_mist_pill").get("kind","") == "consumable",
        "new inventory definitions are catalogued")
    var techniques = Techniques.new()
    check(techniques.load_error.is_empty() and techniques.definitions.has("r24_mist_steps")
        and techniques.definitions.get("r24_mist_steps",{}).get("nodes",[]).size() == 2,
        "two native technique stages resolve independently of starting card deck")

    var assets = Assets.new()
    check(assets.load_error.is_empty()
        and assets.texture_for_character("r24_lan_chen","portrait") != null
        and assets.texture_for_character("r24_lan_chen","pose_sheet") != null
        and assets.scene_for_character("r24_lan_chen") != null
        and assets.texture_for_event("STATUS_APPLIED") != null,
        "portrait, 24-pose sheet, actor scene and actual status VFX bind automatically")
    check(Art.sheet_for_character("r24_lan_chen") != null,
        "canonical HD2D actor factory sees the manifest sheet")
    var presentation = factory.instantiate_presentation("r24_lan_chen")
    check(presentation is Node2D, "recruit actor PackedScene instantiates")
    if presentation != null: presentation.free()

    const MAP_PATH = "res://data/maps/r24_fog_pass_map.tres"
    var map = MapBake.new(MAP_PATH)
    var spatial = Spatial.new(MAP_PATH)
    check(map.error.is_empty() and map.polygon_mode and map.polygons.size() == 2
        and not map.is_walkable_point(Vector2(800,450),8.0),
        "editor-authored polygon obstacles constrain continuous positions")
    check(not spatial.clear_segment(Vector2(650,450),Vector2(950,450),8.0)
        and spatial.find_path(Vector2(650,450),Vector2(950,450),8.0).size() > 2,
        "FREE actor navigation detours around the ink-painted fog wall")

    var session = Session.new()
    root.add_child(session)
    session.start_new_game("r24_fog_pass")
    var chapter: Dictionary = session.chapter_definition()
    check(session.phase == "story" and session.character("r24_lan_chen") != null
        and chapter.get("scene",{}).get("npcs",[]).size() == 2,
        "new chapter enters with a new recruit and two independent NPCs")
    check(not session.begin_encounter(), "battle gate rejects untouched NPC triggers")
    var quest: Dictionary = session.quest_status("r24_fog_pass_quest")
    check(quest.get("objectives",[]).size() == 4 and not bool(quest.get("complete",true)),
        "four-objective quest begins incomplete")

    var story = Story.new(str(chapter.get("story_path","")))
    check(story.load_error.is_empty(), "multi-trigger native story Resource loads")
    if story.load_error.is_empty():
        story.begin()
        story.skip_cinematic()
        check(story.interact_at("r24_scout") and story.dialogue_id == "r24_scout",
            "first NPC opens its own dialogue trigger")
        check(session.apply_story_events(story.take_events()), "first NPC facts commit")
        check(story.advance_dialogue() and story.phase == "explore"
            and not story.complete_if_ready(session.flags),
            "chapter returns to exploration after first NPC, without premature battle")
        check(not session.begin_encounter(), "chapter still requires the second NPC")
        check(story.interact_at("r24_elder") and story.dialogue_id == "r24_elder",
            "second NPC opens its independent dialogue trigger")
        check(session.apply_story_events(story.take_events()), "second NPC grants route clue")
        check(story.advance_dialogue() and story.complete_if_ready(session.flags)
            and story.phase == "complete",
            "both NPC flags unlock chapter completion")
    quest = session.quest_status("r24_fog_pass_quest")
    var progress: Array = quest.get("objectives",[])
    check(progress.size() == 4 and progress[0].complete and progress[1].complete
        and progress[2].complete and not progress[3].complete,
        "facts update three quest objectives; combat remains")
    check(session.set_battle_spatial_mode("FREE") and session.begin_encounter(),
        "story-to-battle route enters real FREE continuous map")
    var options: Dictionary = session.encounter_options()
    check(options.get("map_definition_path","") == MAP_PATH
        and options.get("spatial_mode","") == "FREE",
        "encounter consumes its authored map and spatial mode")
    if not options.is_empty():
        var battle = Model.new()
        battle.reset(2424,0,"r24_mist_sword",options)
        check(battle.state.outcome == "playing" and battle.cards.load_error.is_empty()
            and battle.cards.definitions.has("r24_mist_follow"),
            "unchanged BattleModel accepts native recruit, deck and derived skill")
        if battle.state.outcome == "playing":
            var actor = battle.state.get_actor(0)
            check(actor.school_id == "r24_mist_sword"
                and actor.learned_schools.has("r24_mist_sword"),
                "battle equipped the newly registered native school")
            var total: int = 0
            for uid in actor.hand + actor.draw_pile + actor.discard_pile:
                if str(battle.cards.instance(str(uid)).get("definition_id","")) in ["r24_mist_veil","r24_mist_cut"]:
                    total += 1
            check(total == 12, "12-card starting deck consists exclusively of two base skills")
            var original_attack: int = int(actor.stats.attack)
            check(battle.statuses.add(0,"r24_mist_edge") and actor.stats.attack == original_attack,
                "conditional buff does not activate without its status")
            check(battle.statuses.add(0,"r24_dew_guard")
                and actor.stats.attack == original_attack + 3,
                "second buff activates precisely when the matching status appears")
            battle.statuses.remove(0,"r24_dew_guard")
            check(actor.stats.attack == original_attack,
                "conditional bonus retracts on status removal")
            battle.statuses.remove(0,"r24_mist_edge")
            var source_uid: String = battle.cards.create_instance(actor,"r24_mist_veil","hand")
            for _turn in range(24):
                if battle.state.active_id == 0 and battle.state.mode == "ACTION": break
                var active: int = int(battle.state.active_id)
                if active < 0 or battle.state.mode != "ACTION": break
                var advanced: Dictionary = battle.submit(battle.request("END_ACTION",active))
                if not bool(advanced.get("success",false)): break
                if battle.state.animation_pending:
                    battle.acknowledge_animation(battle.state.animation_ticket)
            check(battle.state.active_id == 0 and battle.state.mode == "ACTION",
                "new recruit receives actual CTB action authority")
            var outcome: Dictionary = battle.submit(battle.request("PLAY_CARD",0,
                {"card_uid":source_uid,"usage_id":"veil"}))
            check(bool(outcome.get("success",false))
                and actor.statuses.has("r24_dew_guard") and actor.statuses.has("r24_mist_edge"),
                "base form applies both authored buffs through real combat")
            var generated: bool = false
            for uid in actor.hand:
                var instance: Dictionary = battle.cards.instance(str(uid))
                if str(instance.get("definition_id","")) == "r24_mist_follow" and bool(instance.get("generated",false)):
                    generated = true
            check(generated, "base form creates an authoritative derived physical card")
    check(session.report_battle("victory",0), "native encounter clears via same reward transaction")
    check(bool(session.quest_status("r24_fog_pass_quest").get("complete",false))
        and session.character("r24_lan_chen") != null,
        "victory closes all four quest objectives and preserves recruited character")
    print("R24_CONTENT_CLOSURE_PASS failures=",failures)
    session.free()
    quit(0 if failures == 0 else 1)
