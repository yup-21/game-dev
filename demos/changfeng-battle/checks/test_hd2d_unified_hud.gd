extends SceneTree
## Regression for the single borderless battle HUD; run after asset import.
## This check complements the existing input and 3v3 story regressions.
const SCENE_PATH := "res://battle_hd2d.tscn"
var failures := 0
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, description: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("UNIFIED_HUD: " + description)

func _count_framed(node: Node) -> int:
    var total := 1 if node is PanelContainer else 0
    for child in node.get_children():
        total += _count_framed(child)
    return total

func _run() -> void:
    var packed: PackedScene = load(SCENE_PATH) as PackedScene
    _check(packed != null, "HD2D battle scene does not load")
    if packed == null:
        quit(1)
        return
    var battle: Node = packed.instantiate()
    root.add_child(battle)
    await process_frame
    var hud: Control = battle.get_node_or_null("WuxiaCombatHUD/UnifiedHUD") as Control
    _check(hud != null, "missing single unified HUD")
    if hud == null:
        quit(1)
        return
    _check(_count_framed(hud) == 0, "boxed PanelContainers returned to combat HUD")
    for expected in ["ChapterRibbon", "FloatingRoster", "ContextActions", "ChargeRail",
        "HandStage", "HandStage/HandScroll"]:
        _check(hud.get_node_or_null(expected) != null, "missing zone: " + expected)
    var cards: HBoxContainer = battle.get("card_actions") as HBoxContainer
    var commands: VBoxContainer = battle.get("command_actions") as VBoxContainer
    _check(cards != null and commands != null, "card actions and command rail missing")
    if cards != null:
        var scroll := cards.get_parent() as ScrollContainer
        _check(scroll != null and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
            "hand must scroll horizontally")
        var illustrated := 0
        for child in cards.get_children():
            if child is Button and child.has_meta("card_uid"):
                illustrated += 1
                _check(child.get_meta("usage_id") != null, "missing per-usage action metadata")
                _check(child.custom_minimum_size.y >= 184.0, "compact painted card artwork is clipped")
        _check(illustrated > 0, "the opening hand has no playable illustrated cards")
    if commands != null:
        var toggles := 0
        var toggle_button: Button
        for child in commands.get_children():
            if child is Button and child.name == "PitchToggle":
                toggles += 1
                toggle_button = child
        _check(toggles <= 1, "discard choices must be grouped behind one action")
        if toggle_button != null:
            toggle_button.pressed.emit()
            var list := commands.get_node_or_null("PitchChoices")
            _check(list != null and list.get_child_count() > 0,
                "grouped discard menu does not reveal legitimate card choices")
    var roster: Dictionary = battle.get("roster_bars")
    _check(roster.size() == battle.get("snap").get("actors", []).size(),
        "roster must reflect every actor")
    var rail: Control = hud.get_node_or_null("ChargeRail") as Control
    if rail != null:
        _check(float(rail.call("gauge_y", 0.0)) > float(rail.call("gauge_y", 10000.0)),
            "charge track must run upward from 0 to 10000")
        for actor in battle.get("snap").get("actors", []):
            var id := int(actor.id)
            var marker := rail.get_node_or_null("Charge_%d" % id)
            _check(marker != null, "CTB marker missing actor %d" % id)
            _check(marker != null and marker.tooltip_text.contains("集气"),
                "CTB marker missing accessible gauge value")
            var row := hud.get_node_or_null("FloatingRoster/RosterScroll/ActorList/Status_%d" % id)
            _check(row != null and row.visible == (int(actor.get("team_id", 0)) == 0),
                "only allies should occupy the compact left roster")
    var revision_before: int = int(battle.get("snap").get("revision", -1))
    await process_frame
    _check(int(battle.get("model").snapshot(0).get("revision", -1)) == revision_before,
        "building HUD changed battle state")
    print("UNIFIED_HUD_RESULT checks=%d failures=%d" % [checks, failures])
    battle.queue_free()
    await process_frame
    quit(1 if failures > 0 else 0)
