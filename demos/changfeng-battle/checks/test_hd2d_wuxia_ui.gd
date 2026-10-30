extends SceneTree
## Original wuxia UI smoke test: assets, actual hand buttons and model linkage.
## Run after editor --import: godot --headless --path demos/changfeng-battle --script res://checks/test_hd2d_wuxia_ui.gd
const CardUI = preload("res://scripts/hd2d_card_ui.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("WUXIA_UI: " + reason)
    quit(1)

func _run() -> void:
    var atlas: Texture2D = load("res://assets/ui/technique_art_atlas_v1.png")
    if atlas == null or atlas.get_size() != Vector2(1536, 1024):
        _fail("card art atlas must be 1536x1024 (4x2)")
        return
    for asset_path in [
        "res://assets/ui/jade_panel_frame.svg",
        "res://assets/ui/jade_card_filagree.svg",
        "res://assets/ui/jade_seal.svg"]:
        var art: Texture2D = load(asset_path)
        if art == null or art.get_width() == 0:
            _fail("cannot import UI vector " + asset_path)
            return

    var sample := CardUI.make_card("test-uid", "tf_probe", "探锋式", "探锋·试探",
        {"qi": 1.0, "hp": 0.0}, false)
    if sample.text.find("探锋式 · 探锋·试探") != 0:
        _fail("card input text contract changed")
        return
    if sample.get_child_count() < 5:
        _fail("illustration or labels missing from card")
        return
    var distinct := CardUI.illustration("tf_sunder", "断岳式") as AtlasTexture
    var first := CardUI.illustration("tf_probe", "探锋式") as AtlasTexture
    if first == null or distinct == null or first.region == distinct.region:
        _fail("two different techniques are mapped to one atlas cell")
        return
    sample.free()

    var scene: Node3D = load("res://battle_hd2d.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var hand: HFlowContainer = scene.get("card_actions")
    var utilities: VBoxContainer = scene.get("command_actions")
    if hand == null or utilities == null:
        _fail("new martial hand / utility panel is not installed")
        return
    if hand.get_child_count() == 0:
        _fail("no playable illustrated card displayed")
        return
    var any_card := false
    for child in hand.get_children():
        if child is Button and child.has_meta("card_uid"):
            if child.get_child_count() < 5 or child.text.is_empty():
                _fail("button lost visual child art or input text")
                return
            any_card = true
    if not any_card:
        _fail("all legal martial cards are missing")
        return
    var labels: Dictionary = scene.get("roster_labels")
    var bars: Dictionary = scene.get("roster_bars")
    var snapshot: Dictionary = scene.get("model").snapshot(0)
    if labels.size() != snapshot.get("actors", []).size() or bars.size() != labels.size():
        _fail("roster no longer represents the full actor list")
        return
    for actor in snapshot.get("actors", []):
        var id := int(actor.id)
        var values: Dictionary = bars[id]
        var hp: ProgressBar = values["hp"]
        if absf(hp.value - float(actor.hp)) > 0.01:
            _fail("HP meter diverged from model state for actor %d" % id)
            return
    # Pure presentation tests: BattleModel must remain authoritative.
    if scene.get("model").snapshot(0).get("revision", -1) != snapshot.get("revision", -2):
        _fail("rendering the hand mutated authoritative model revision")
        return
    print("WUXIA_UI_PASS atlas + 3 vector assets + interactive hand + roster + authority")
    quit(0)
