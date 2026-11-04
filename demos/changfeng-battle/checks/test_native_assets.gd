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
        "legacy 6x4 animation sheet remains supported")
    var flexible: Dictionary = assets.record("r27_gu_sheet")
    flexible["id"] = "r22_flexible_atlas_contract"
    flexible["owner_character_id"] = ""
    flexible["columns"] = 3
    flexible["rows"] = 8
    check(assets._register(flexible), "new pose_sheet registry accepts divisible 3x8 atlas")
    var hero_card: WuxiaCharacterDefinition = load("res://data/native/characters/shen_changfeng.tres")
    check(Art.portrait_for_character("shen_changfeng") == hero_card.portrait
        and Art.uses_supplied_sheet_for_character("river_messenger"),
        "art facade prefers the live native character card by ID")
    var factory = Factory.new()
    var old_spec: Dictionary = factory.assets.record("r22_shen_portrait")
    var conflicting_spec: Dictionary = old_spec.duplicate(true)
    conflicting_spec["path"] = "res://assets/imported/characters/escort_elder/portraits/portrait_escort_elder_fullbody_v01.png"
    factory.assets.definitions["r22_shen_portrait"] = conflicting_spec
    var factory_uses_card: bool = factory.presentation_assets("shen_changfeng").get("portrait") == hero_card.portrait
    factory.assets.definitions["r22_shen_portrait"] = old_spec
    check(factory.load_error.is_empty() and factory_uses_card,
        "CharacterFactory ignores conflicting historical portrait registrations")
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
    var animated_asset: Dictionary = assets.record("r22_vfx_probe")
    animated_asset["id"] = "r22_animated_probe"
    animated_asset["event_kind"] = "ATTACK_DECLARED"
    animated_asset["columns"] = 2
    animated_asset["rows"] = 1
    animated_asset["frame_indices"] = PackedInt32Array([0, 1])
    var animated_registry = Assets.new()
    check(animated_registry._register(animated_asset), "VFX accepts frame-sequenced native atlas")
    var animated_canvas := Node2D.new()
    root.add_child(animated_canvas)
    var animated_vfx = VFX.new(animated_canvas)
    animated_vfx.native_assets = animated_registry
    animated_vfx._spawn_canvas(Vector2(180,200), "slash", Color.WHITE, 0.4, 1.0, "ATTACK_DECLARED")
    var animated_root: Node = animated_canvas.get_child(0) if animated_canvas.get_child_count() > 0 else null
    var animated_sprite: Sprite2D = null
    if animated_root != null:
        animated_sprite = animated_root.get_node_or_null("AuthoredVFX") as Sprite2D
    check(animated_sprite != null and animated_sprite.hframes == 2 and animated_sprite.frame == 0,
        "VFX atlas starts on authored first frame")
    animated_vfx.update(0.35)
    check(animated_sprite != null and animated_sprite.frame == 1,
        "VFX atlas advances through authored frame indices")
    animated_vfx.clear()
    animated_canvas.free()
    var rejected = Assets.new()
    var fake: Dictionary = assets.record("r22_temple_scene")
    fake["id"] = "r22_not_approved"
    fake["status"] = "approved"
    check(not rejected._register(fake) and not rejected.load_error.is_empty(),
        "unverified rights cannot be promoted to approved")
    print("R22_NATIVE_ASSETS_PASS failures=",failures)
    quit(0 if failures == 0 else 1)
