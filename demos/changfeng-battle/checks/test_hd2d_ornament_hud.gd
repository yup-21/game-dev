extends SceneTree
## Art and geometry regression. This test must never change combat state.
const SCENE_PATH := "res://battle_hd2d.tscn"
const ART_DIR := "res://assets/ui/ornaments/"
var checks := 0
var failures := 0

func _check(ok: bool, reason: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("ORNAMENT_HUD: " + reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for file in ["chapter_filagree.svg", "hand_fan_tray.svg", "portrait_frame.svg",
        "card_frame.svg", "ctb_rail.svg", "ctb_marker_frame.svg"]:
        var texture := load(ART_DIR + file) as Texture2D
        _check(texture != null and texture.get_width() > 0 and texture.get_height() > 0,
            "missing imported decorative texture: " + file)
    var packed := load(SCENE_PATH) as PackedScene
    _check(packed != null, "battle scene cannot load")
    if packed == null:
        quit(1)
        return
    var battle: Node = packed.instantiate()
    root.add_child(battle)
    await process_frame
    await process_frame
    var hud := battle.get_node_or_null("WuxiaCombatHUD/UnifiedHUD") as Control
    _check(hud != null, "HUD missing")
    if hud == null:
        quit(1)
        return
    var tray := hud.get_node_or_null("HandStage") as Control
    _check(tray != null and tray.size.y <= 260.0, "fan tray covers too much battlefield")
    var hand := battle.get("card_actions") as HBoxContainer
    _check(hand != null, "original interactive hand container missing")
    if hand != null:
        # Keep real Button cards so existing keyboard, mouse and legality paths work.
        var cards: Array[Button] = []
        for child in hand.get_children():
            if child is Button and not child.is_queued_for_deletion():
                cards.append(child)
                _check(child.has_meta("card_uid"), "fan contains a non-card Button")
        _check(cards.size() >= 2, "fan needs at least two cards for geometry check")
        battle.call("_layout_fan_cards")
        if cards.size() >= 2:
            _check(cards[0].rotation_degrees < cards[-1].rotation_degrees,
                "fan does not spread from left to right")
            _check(absf(cards[0].rotation_degrees) <= 11.6 and
                absf(cards[-1].rotation_degrees) <= 11.6,
                "fan rotation exceeds compact readable angles")
        _check(hand.get_parent() is ScrollContainer,
            "fan no longer supports long-hand horizontal scrolling")
    var rail := hud.get_node_or_null("ChargeRail") as Control
    _check(rail != null, "CTB rail was lost")
    if rail != null:
        for actor in battle.get("snap").get("actors", []):
            var marker := rail.get_node_or_null("Charge_%d" % int(actor.id))
            _check(marker != null and marker.get_node_or_null("Rim") != null,
                "CTB actor missing filigree marker")
    var roster := hud.get_node_or_null("FloatingRoster") as Control
    _check(roster != null and roster.find_child("PortraitFrame", true, false) != null,
        "party portraits have no reusable frame")
    var previous_revision := int(battle.get("model").snapshot(0).get("revision", -1))
    await process_frame
    _check(int(battle.get("model").snapshot(0).get("revision", -2)) == previous_revision,
        "ornament layout must not advance CTB or combat rules")
    print("ORNAMENT_HUD_RESULT checks=%d failures=%d" % [checks, failures])
    battle.queue_free()
    await process_frame
    quit(1 if failures > 0 else 0)
