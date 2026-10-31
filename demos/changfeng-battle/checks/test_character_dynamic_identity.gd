extends SceneTree
## Actor slot IDs and independent native character cards never drive presentation identity.
const Registry = preload("res://scripts/character_registry.gd")
const Scenario = preload("res://scripts/scenario_director.gd")
const Model = preload("res://scripts/battle_model.gd")
const Art = preload("res://scripts/hd2d_art_catalog.gd")
const Manifest = preload("res://scripts/content/content_manifest.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("R41_IDENTITY: " + label)

func _run() -> void:
    var registry = Registry.new()
    check(registry.load_error.is_empty(), "native character registry loads")
    var hero: Dictionary = registry.get_profile("shen_changfeng")
    var pursuer: Dictionary = registry.get_profile("pursuer_captain")
    var encounter: Dictionary = {
        "id":"r41_dynamic_duel","seed":2026,"schools":{},
        "combatants":[
            {"id":71,"name":hero.name,"character_id":hero.id,
                "team_id":0,"controller":"PLAYER","cell":[6,4]},
            {"id":72,"name":pursuer.name,"character_id":pursuer.id,
                "team_id":1,"controller":"AI","cell":[8,4]}
        ]
    }
    var director = Scenario.new()
    check(director.load_error.is_empty() and director._register_entry(encounter),
        "native encounter validation accepts relocated combatant IDs")
    var opts: Dictionary = director.battle_options("r41_dynamic_duel")
    check(opts.get("character_ids",{}).get(71,"") == "shen_changfeng",
        "actor slot 71 resolves hero identity")
    var battle = Model.new()
    battle.reset(2026,-1,"tingfeng",opts)
    var actor = battle.state.get_actor(71)
    check(battle.state.outcome=="playing" and actor != null,
        "relocated 1v1 battle starts")
    if actor != null:
        check(actor.character_id=="shen_changfeng" and actor.school_id==hero.school_id,
            "runtime identity survives arbitrary slot")
    check(Art.sheet_for_character("shen_changfeng")==Art.sheet_for_actor(0)
        and Art.avatar_for_character("shen_changfeng")!=null,
        "art binding comes from character ID, not actor slot")

    # Inspector-authored resource cards are also accepted from other manifests.
    var manifest = Manifest.new()
    var extra_hero: WuxiaCharacterDefinition = load(
        "res://data/native/characters/shen_changfeng.tres").duplicate()
    extra_hero.content_id = "r41_guest_hero"
    extra_hero.display_name = "测试侠客"
    extra_hero.battle_actor_id = -1
    var extra_pursuer: WuxiaCharacterDefinition = load(
        "res://data/native/characters/pursuer_captain.tres").duplicate()
    extra_pursuer.content_id = "r41_guest_enemy"
    extra_pursuer.display_name = "测试追兵"
    extra_pursuer.battle_actor_id = -1
    manifest.characters.append(extra_hero)
    manifest.characters.append(extra_pursuer)
    var path: String = "user://r41_identity_fixture.tres"
    check(ResourceSaver.save(manifest, path) == OK, "native authoring fixture saved")
    var added = Registry.new(path)
    check(added.load_error.is_empty() and added.profiles.size()==2,
        "new character cards validate through production registry")
    var dynamic_options: Dictionary = added.battle_options([],
        {81:"r41_guest_hero",82:"r41_guest_enemy"})
    check(dynamic_options.get("character_ids",{}).size()==2,
        "new cards materialize without actor ID or source code bindings")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("R41_IDENTITY_PASS failures=",failures)
    quit(1 if failures else 0)
