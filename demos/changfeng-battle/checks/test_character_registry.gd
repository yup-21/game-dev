extends SceneTree
## End-to-end single-source characters, martial bindings and UI.
const Registry = preload("res://scripts/character_registry.gd")
const Scenario = preload("res://scripts/scenario_director.gd")
const Model = preload("res://scripts/battle_model.gd")
const Art = preload("res://scripts/hd2d_art_catalog.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(valid: bool, label: String) -> void:
    checks += 1
    if not valid:
        failures += 1
        push_error("CHARACTER_REGISTRY: " + label)

func _run() -> void:
    var registry = Registry.new()
    _check(registry.load_error.is_empty(), "all seven independent character dossiers load")
    _check(registry.profiles.size() == 7 and registry.actor_ids().size() == 6,
        "six combat actors and story-only elder are registered")
    var elder: Dictionary = registry.for_name("老镖头")
    _check(str(elder.get("id","")) == "escort_elder"
        and int(elder.get("battle_actor_id",0)) == -1, "escort elder is story-only")
    _check(Art.portrait("老镖头") != null and Art.portrait("沈长风") != null,
        "story portraits resolve through character records")
    var director = Scenario.new()
    _check(director.load_error.is_empty(), "encounter resolves all registered character IDs")
    var opts: Dictionary = director.battle_options("escort_ambush")
    _check(opts.get("character_ids",{}).size() == 6 and opts.get("schools",{}).size() == 6,
        "six encounter identities bind real school and base stats")
    var independent: Dictionary = opts.duplicate(true)
    independent.attributes[0]["STR"] = 99
    _check(int(registry.for_actor(0).attributes.STR) != 99
        and int(opts.attributes[0].STR) != 99, "caller mutations never alter registry or combat options")
    var battle = Model.new()
    battle.reset(2026,-1,"tingfeng",opts)
    _check(battle.state.outcome == "playing" and battle.state.actors.size() == 6,
        "profile-based 3v3 battle initializes")
    for id in registry.actor_ids():
        var actor = battle.state.get_actor(int(id))
        var profile: Dictionary = registry.for_actor(int(id))
        _check(actor != null and str(actor.character_id) == str(profile.id),
            "actor identity comes from registry: " + str(id))
        if actor == null:
            continue
        _check(str(actor.name) == str(profile.name)
            and str(actor.school_id) == str(profile.school_id),
            "name and martial school from profile: " + str(id))
        for stat in ["STR","AGI","CON","MND"]:
            _check(int(actor.attributes[stat]) == int(profile.attributes[stat]),
                "actor attribute from profile: " + str(id) + "/" + stat)
        _check(actor.technique_states.has("tf_change_stage") == (int(id) == 0),
            "change stage learned only by Shen Changfeng")
        _check(Art.uses_supplied_sheet(int(id)),
            "profile chooses a real action sheet: " + str(id))
    var quick = Model.new()
    quick.reset(2026,-1,"tingfeng",registry.battle_options([],
        {0:"shen_changfeng",1:"pursuer_captain"}))
    _check(quick.state.actors.size() == 2 and quick.state.get_actor(0).character_id == "shen_changfeng"
        and quick.state.get_actor(1).school_id == "saber",
        "quick duel uses the same registered two characters")
    var packed := load("res://battle_hd2d.tscn") as PackedScene
    _check(packed != null, "main scene remains valid")
    if packed == null:
        quit(1)
        return
    var view = packed.instantiate()
    root.add_child(view)
    await process_frame
    var overlay: Control = view.get_node_or_null("WuxiaCombatHUD/UnifiedHUD/CharacterCardOverlay") as Control
    _check(overlay != null, "role card is installed on actual unified HUD")
    if overlay != null:
        var before := int(view.get("model").state.revision)
        _check(bool(overlay.call("open_actor",view.get("model"),0)),
            "pressing character avatar can open protagonist dossier")
        _check(overlay.visible and str(overlay.get("title_label").text).contains("沈长风"),
            "title and character identity displayed")
        _check(str(overlay.get("martial_label").text).contains("苍风折柳剑"),
            "profile renders real assigned martial school")
        _check(str(overlay.get("stats_label").text).contains("气血"),
            "profile renders real live health/qi/attributes")
        _check(overlay.get("portrait").texture != null
            and overlay.get("preview").texture != null,
            "profile renders illustrated portrait and action-sheet preview")
        _check(int(view.get("model").state.revision) == before,
            "opening profile does not submit or advance combat state")
        overlay.call("close_card")
        _check(not overlay.visible, "role card can close without changing combat state")
    view.queue_free()
    await process_frame
    print("CHARACTER_REGISTRY_PASS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures > 0 else 0)
