extends SceneTree
## Godot 4.x integration checks for original art and its runtime HUD consumers.
## Run after --editor --import --quit using the project directory.
const CardArt = preload("res://scripts/hd2d_card_art.gd")
const UITheme = preload("res://scripts/hd2d_ui_theme.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error("WUXIA_UI_FAIL: " + message)

func _run() -> void:
    for id in ["tf_probe", "tf_sunder", "tf_step", "tf_guard", "tf_change",
        "wind_final", "taixu_breath", "blood_burn"]:
        var texture := CardArt.for_card({"definition_id": id})
        _check(texture != null and texture.get_size() in [Vector2(240, 320), Vector2(384, 512)],
            "card art missing or wrong dimensions: " + id)
    _check(CardArt.SEAL != null and CardArt.SEAL.get_size() == Vector2(128, 128),
        "jade emblem not imported")
    var scene := load("res://battle_hd2d.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var actions = scene.get("card_actions")
    _check(actions is HBoxContainer and actions.get_parent() is ScrollContainer,
        "card hand has no horizontal scroll")
    var painted_buttons := 0
    if actions != null:
        for child in actions.get_children():
            if child is Button and child.has_meta("card_uid"):
                painted_buttons += 1
                var has_art := false
                for layer in child.get_children():
                    if layer is TextureRect and layer.texture != null:
                        has_art = true
                        break
                _check(has_art, "legal card button missing a painted illustration")
    _check(painted_buttons > 0, "no playable illustrated cards")
    var bars: Dictionary = scene.get("roster_bars")
    var actor_count: int = scene.get("snap").get("actors", []).size()
    _check(bars.size() == actor_count, "roster bar count does not match actors")
    for actor_id in bars.keys():
        var pair: Dictionary = bars[actor_id]
        _check(pair.has("hp") and pair.has("qi"), "HP/Qi meter missing for actor %d" % actor_id)
    var scroll: ScrollContainer = actions.get_parent() as ScrollContainer
    _check(scroll != null and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
        "card hand is not horizontally scrollable")
    _check(scene.get("model") != null, "original battle model was not retained")
    print("WUXIA_UI_RESULT checks=%d failures=%d painted=%d" % [
        checks, failures, painted_buttons])
    scene.queue_free()
    await process_frame
    quit(0 if failures == 0 else 1)
