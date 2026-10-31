extends SceneTree
## R22: asset Resource registry, authoring QA and runtime art injection.
const Native = preload("res://scripts/content/content_registry.gd")
const Assets = preload("res://scripts/asset_registry.gd")
const Factory = preload("res://scripts/character_factory.gd")
const Art = preload("res://scripts/hd2d_art_catalog.gd")
const VFX = preload("res://scripts/battle_vfx_2d.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        printerr("R22_ASSET_FAIL: " + label)

func _run() -> void:
    var native = Native.new()
    check(native.load_error.is_empty() and native.entries("asset").size() >= 4,
        "all four native asset definitions loaded by explicit references")
    var assets = Assets.new()
    check(assets.load_error.is_empty(), "runtime asset resolver validates imports")
    var portrait: Texture2D = assets.texture_for_character("shen_changfeng","portrait")
    check(portrait != null and portrait.get_width() >= 128,
        "portrait stable binding resolves imported Texture2D")
    var sheet: Texture2D = assets.texture_for_character("river_messenger","pose_sheet")
    check(sheet != null and sheet.get_width() % 6 == 0 and sheet.get_height() % 4 == 0,
        "6x4 animation sheet contract validates")
    check(Art.portrait_for_character("shen_changfeng") == portrait
        and Art.uses_supplied_sheet_for_character("river_messenger"),
        "original art facade reads the native registry by character ID")
    var factory = Factory.new()
    check(factory.load_error.is_empty()
        and factory.presentation_assets("shen_changfeng").get("portrait") == portrait,
        "CharacterFactory resolves art without modifying actor rules")
    check(assets.record("r22_vfx_probe").get("status") == "candidate"
        and assets.record("r22_vfx_probe").get("rights") == "owner_review_required",
        "candidate asset is explicitly not certified approved")
    var canvas := Node2D.new()
    root.add_child(canvas)
    var vfx = VFX.new(canvas)
    vfx._spawn_canvas(Vector2(180,200),"r22_probe",Color.WHITE,0.4,1.0)
    var art_node: Node = canvas.get_child(0) if canvas.get_child_count() > 0 else null
    check(art_node != null and art_node.get_node_or_null("AuthoredVFX") is Sprite2D,
        "event key binds authored VFX Texture2D without resolver/UI hardcoding")
    vfx.clear()
    canvas.free()
    var rejected = Assets.new()
    var fake: Dictionary = assets.record("r22_temple_scene")
    fake["id"] = "r22_not_approved"
    fake["status"] = "approved"
    check(not rejected._register(fake) and not rejected.load_error.is_empty(),
        "unverified rights cannot be promoted to approved")
    print("R22_NATIVE_ASSETS_PASS failures=",failures)
    quit(0 if failures == 0 else 1)
