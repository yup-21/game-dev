extends Node
## The in-memory source of truth across chapters, battle snapshots and rewards.
## Combat authority remains in BattleModel; initial party loadouts come from character cards.
const ScenarioDirector = preload("res://scripts/scenario_director.gd")
const ChapterCatalog = preload("res://scripts/chapter_catalog.gd")
const CharacterRuntime = preload("res://scripts/character_runtime.gd")
const CharacterFactory = preload("res://scripts/character_factory.gd")
const InventoryRuntime = preload("res://scripts/inventory_runtime.gd")
const StoryEvents = preload("res://scripts/story_event_executor.gd")
const SceneRouter = preload("res://scripts/chapter_scene_router.gd")
const Quests = preload("res://scripts/quest_runtime.gd")
const QUICK_ENCOUNTER_ID := "r40_quick_duel"
const PROLOGUE_WAVES := {
    "wave1_ready":"prologue_scout_wave1",
    "wave2_ready":"prologue_scout_wave2",
    "lookout_ready":"prologue_lookout"
}
const PROLOGUE_VICTORIES := {
    "prologue_scout_wave1":"wave1_cleared",
    "prologue_scout_wave2":"wave2_cleared",
    "prologue_lookout":"lookout_cleared"
}
const PROLOGUE_TRANSITIONS := {
    "explore":["healing", "failure"],
    "roadside_retry":["healing", "failure"],
    "failure":["roadside_retry"],
    "healing":["wave1_ready"],
    "wave1_cleared":["wave2_ready"],
    "wave2_cleared":["lookout_ready"],
    "lookout_cleared":["escaped"]
}
var director = ScenarioDirector.new()
var chapters = ChapterCatalog.new()
var quests = Quests.new()
var phase: String = "menu"
var chapter_id: String = ""
var choices: Array = []
var flags: Dictionary = {}
## Non-equippable story clues; actual consumables and equipment live on characters.
var items: Dictionary = {}
var characters: Dictionary = {}
var cleared_encounters: Dictionary = {}
var encounter_id: String = ""
var battle_outcome: String = ""
var winning_team: int = -1
var battle_spatial_mode: String = "GRID"
var prologue_active: bool = false
var prologue_stage: String = ""

func start_new_game(entry_chapter_id: String = "") -> void:
    var first: String = chapters.first_chapter_id() if entry_chapter_id.is_empty() else entry_chapter_id
    if chapters.get_chapter(first).is_empty(): return
    phase = "story"
    chapter_id = first
    choices.clear()
    flags.clear()
    items.clear()
    characters.clear()
    cleared_encounters.clear()
    encounter_id = ""
    battle_outcome = ""
    winning_team = -1
    prologue_active = false
    prologue_stage = ""
    var chapter: Dictionary = chapter_definition()
    var factory = CharacterFactory.new()
    for actor in director.encounter(str(chapter.get("encounter_id",""))).get("combatants",[]):
        if int(actor.get("team_id",-1)) != 0 or bool(actor.get("recruit_at_story",false)):
            continue
        var id: String = str(actor.get("character_id",""))
        if not id.is_empty() and not characters.has(id):
            var character = factory.create_runtime(id)
            if character != null:
                characters[id] = character

## The new playable prologue uses native exploration maps and a staged chase.
## Legacy chapter resources remain readable for historical test/demo entries.
func activate_prologue_chase() -> bool:
    if phase != "story" or chapter_id != "rain_escort_prologue":
        return false
    if director.encounter("prologue_scout_wave1").is_empty():
        return false
    prologue_active = true
    prologue_stage = "explore"
    return true

func set_prologue_stage(next_stage: String) -> bool:
    if not prologue_active or phase != "story" or next_stage not in PROLOGUE_TRANSITIONS.get(prologue_stage, []):
        return false
    prologue_stage = next_stage
    return true

func begin_prologue_wave() -> bool:
    if not prologue_active or phase != "story":
        return false
    var selected: String = str(PROLOGUE_WAVES.get(prologue_stage, ""))
    if selected.is_empty() or director.encounter(selected).is_empty():
        return false
    if selected == "prologue_lookout" and not bool(flags.get("obtained_fragment", false)):
        return false
    for actor in director.encounter(selected).get("combatants", []):
        if int(actor.get("team_id", -1)) == 0 and not characters.has(str(actor.get("character_id", ""))):
            return false
    phase = "battle"
    encounter_id = selected
    battle_outcome = ""
    winning_team = -1
    prologue_stage = prologue_stage.trim_suffix("_ready") + "_battle"
    return true

## Quick combat bypasses story progression, not encounter loading.
func start_quick_battle() -> bool:
    var quick: Dictionary = director.encounter(QUICK_ENCOUNTER_ID)
    if quick.is_empty():
        return false
    var factory = CharacterFactory.new()
    var staged: Dictionary = {}
    for actor in quick.get("combatants", []):
        if int(actor.get("team_id",-1)) != 0:
            continue
        var id: String = str(actor.get("character_id",""))
        var runtime = factory.create_runtime(id)
        if runtime == null:
            return false
        staged[id] = runtime
    characters = staged
    phase = "quick_battle"
    chapter_id = ""
    encounter_id = QUICK_ENCOUNTER_ID
    battle_outcome = ""
    winning_team = -1
    return true

func quest_status(id: String) -> Dictionary:
    return quests.status(id,flags,items,cleared_encounters)

func chapter_definition() -> Dictionary:
    return chapters.get_chapter(chapter_id)

func character(id: String):
    return characters.get(id,null)

func scene_for(next_phase: String) -> String:
    return SceneRouter.path_for(next_phase)

func record_choice(node_id: String, option_id: int) -> void:
    if phase != "story":
        return
    choices.append({"chapter_id":chapter_id,"node_id":node_id,"option":option_id})

func apply_story_events(events: Array) -> bool:
    if phase != "story":
        return false
    var staged: Dictionary = StoryEvents.prepare(events,flags,items,characters)
    if not bool(staged.get("ok",false)):
        return false
    _adopt(staged)
    return true

func _adopt(staged: Dictionary) -> void:
    flags = staged.flags
    items = staged.items
    characters = staged.characters

func begin_encounter(id: String = "") -> bool:
    if phase != "story":
        return false
    var chapter: Dictionary = chapter_definition()
    var expected: String = str(chapter.get("encounter_id",""))
    var selected: String = expected if id.is_empty() else id
    if selected != expected or director.encounter(selected).is_empty():
        return false
    if not StoryEvents.meets(chapter.get("requirements",[]),flags):
        return false
    for actor in director.encounter(selected).get("combatants",[]):
        if int(actor.get("team_id",-1)) == 0:
            var persistent_id: String = str(actor.get("character_id",""))
            if not characters.has(persistent_id):
                return false
    phase = "battle"
    encounter_id = selected
    battle_outcome = ""
    winning_team = -1
    return true

func encounter_options() -> Dictionary:
    if phase not in ["battle", "quick_battle"]:
        return {}
    var builds: Dictionary = {}
    for character_id in characters:
        builds[str(character_id)] = characters[character_id].battle_build()
    var options: Dictionary = director.battle_options(encounter_id,builds)
    if prologue_active and PROLOGUE_VICTORIES.has(encounter_id):
        # A fragment grants the already-supported native insight passive only
        # during the final lookout encounter; no combat rule is duplicated.
        var passives: Dictionary = options.get("passives", {}).duplicate(true)
        var hero_passives: Dictionary = passives.get(0, {}).duplicate(true)
        hero_passives["insight"] = 2 if encounter_id == "prologue_lookout" and \
            bool(flags.get("fragment_insight_unlocked", false)) else 0
        passives[0] = hero_passives
        options["passives"] = passives
    options["spatial_mode"] = battle_spatial_mode
    return options

func set_battle_spatial_mode(next_mode: String) -> bool:
    if next_mode not in ["GRID","FREE"]:
        return false
    battle_spatial_mode = next_mode
    return true

func encounter_seed() -> int:
    return int(director.encounter(encounter_id).get("seed",2026))

func report_battle(outcome: String, team: int, battle_inventories: Dictionary = {}) -> bool:
    if phase != "battle" or outcome not in ["victory","defeat","draw"]:
        return false
    var staged_characters: Dictionary = characters.duplicate()
    if not battle_inventories.is_empty():
        var roster: Dictionary = {}
        for actor in director.encounter(encounter_id).get("combatants",[]):
            roster[int(actor.id)] = actor
        for actor_id in battle_inventories:
            if not actor_id is int or not roster.has(actor_id):
                return false
            if int(roster[actor_id].get("team_id",-1)) != 0:
                return false
        for actor in roster.values():
            if int(actor.get("team_id",-1)) != 0:
                continue
            var id: String = str(actor.get("character_id",""))
            if not characters.has(id) or not battle_inventories.has(int(actor.id)):
                return false
            var incoming: Variant = battle_inventories[int(actor.id)]
            if not incoming is Dictionary or not incoming.get("stacks") is Dictionary:
                return false
            var original: Dictionary = characters[id].inventory.snapshot()
            ## Combat may spend stacks, not swap gear, forge UIDs or reroll affixes.
            if incoming.get("instances") != original.instances or incoming.get("equipped") != original.equipped or incoming.get("next_uid") != original.next_uid:
                return false
            var merged: Dictionary = original.duplicate(true)
            merged["stacks"] = incoming.get("stacks",{}).duplicate(true)
            var staged_inventory = InventoryRuntime.new(characters[id].inventory.catalog)
            if not staged_inventory.restore(merged):
                return false
            var cloned = CharacterRuntime.new(id)
            if not cloned.restore(characters[id].snapshot()):
                return false
            cloned.inventory = staged_inventory
            staged_characters[id] = cloned
    var chapter: Dictionary = chapter_definition()
    var first_clear: bool = outcome == "victory" and team == 0 and not cleared_encounters.has(encounter_id)
    var is_prologue_wave: bool = prologue_active and PROLOGUE_VICTORIES.has(encounter_id)
    var rewards: Array = [] if is_prologue_wave else (chapter.get("victory_events",[]) if first_clear else (chapter.get("defeat_events",[]) if outcome != "victory" else []))
    var staged: Dictionary = StoryEvents.prepare(rewards,flags,items,staged_characters)
    if not bool(staged.get("ok",false)):
        return false
    _adopt(staged)
    if first_clear:
        cleared_encounters[encounter_id] = true
    battle_outcome = outcome
    winning_team = team
    if is_prologue_wave and first_clear:
        prologue_stage = str(PROLOGUE_VICTORIES[encounter_id])
        flags[prologue_stage] = true
        phase = "story"
    else:
        phase = "aftermath"
    return true

func retry_encounter() -> bool:
    if phase != "aftermath" or encounter_id.is_empty():
        return false
    phase = "battle"
    battle_outcome = ""
    winning_team = -1
    return true

func can_advance_chapter() -> bool:
    var next_id: String = str(chapter_definition().get("next_chapter_id",""))
    return phase == "aftermath" and battle_outcome == "victory" and winning_team == 0 and not next_id.is_empty() and not chapters.get_chapter(next_id).is_empty()

func advance_chapter() -> bool:
    if not can_advance_chapter():
        return false
    chapter_id = str(chapter_definition().next_chapter_id)
    phase = "story"
    encounter_id = ""
    battle_outcome = ""
    winning_team = -1
    return true

func finish_demo() -> bool:
    if phase != "aftermath":
        return false
    phase = "complete"
    return true

func return_to_menu() -> void:
    phase = "menu"
    chapter_id = ""
    prologue_active = false
    prologue_stage = ""
