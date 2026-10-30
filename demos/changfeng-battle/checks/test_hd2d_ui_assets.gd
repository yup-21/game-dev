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
    _check(actions is HFlowContainer and actions.get_parent() is ScrollContainer,
        "card hand container not wired to scroll panel")
    var painted_buttons := 0
    if actions != null:
        for child in actions.get_children():
            if child is Button and child.has_meta("card_uid"):
                painted_buttons += 1
                _check(child.get_child_count() > 0 and child.get_child(0) is TextureRect
                    and (child.get_child(0) as TextureRect).texture != null,
                    "legal card button missing illustrated texture")
    _check(painted_buttons > 0, "no playable illustrated cards")
    _check(scene.get("roster_bars").size() == scene.get("snap").get("actors", []).size(),
        "roster meter count does not match actors")
    _check(scene.get("model") != null, "original battle model was not retained")
    print("WUXIA_UI_RESULT checks=%d failures=%d painted=%d" % [
        checks, failures, painted_buttons])
    scene.queue_free()
    await process_frame
    quit(0 if failures == 0 else 1)
