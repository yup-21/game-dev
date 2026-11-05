extends SceneTree
## Structural regression for editor-authored presentation scenes.
const PATHS := [
    "res://scenes/actors/battle_actor.tscn",
    "res://scenes/actors/story_role.tscn",
    "res://scenes/actors/story_npc.tscn",
    "res://scenes/story/interaction_point.tscn",
    "res://scenes/vfx/combat_burst.tscn",
    "res://scenes/ui/battle_hud.tscn",
    "res://scenes/ui/character_card.tscn",
    "res://scenes/ui/battle_card.tscn",
    "res://scenes/ui/ctb_rail.tscn",
    "res://scenes/ui/ctb_marker.tscn",
    "res://scenes/native_authoring_workbench.tscn",
    "res://battle_hd2d.tscn",
    "res://opening.tscn",
    "res://demo_result.tscn",
    "res://prototypes/pingjiang_25d/pingjiang_25d_validation.tscn"
]
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _load_scene(path: String) -> Node:
    var packed: PackedScene = load(path) as PackedScene
    _require(packed != null, "Unloaded PackedScene: " + path)
    return packed.instantiate() if packed != null else null

func _run() -> void:
    for path in PATHS:
        var scene: Node = _load_scene(path)
        if scene != null:
            scene.free()

    var battle: Node = _load_scene("res://battle_hd2d.tscn")
    _require(battle.get_node_or_null("WuxiaCombatHUD/UnifiedHUD/HandStage/HandScroll/CardActions") != null,
        "The battle HUD must be an editable scene instance")
    _require(battle.get_node_or_null("BattleCamera2D") is Camera2D,
        "The battle camera must be an authored Camera2D")
    _require(battle.get_node_or_null("BattleAmbience") is AudioStreamPlayer,
        "The battle ambience must be an authored audio slot")
    _require(battle.get_node_or_null("WuxiaCombatHUD/UnifiedHUD/ChargeRail/RailPainting") is TextureRect,
        "The CTB rail art must be editable")
    battle.free()

    var actor: Node = _load_scene("res://scenes/actors/battle_actor.tscn")
    _require(actor.get_node_or_null("ActionSprite/NativeSpriteAnimation") is AnimationPlayer,
        "Battle actor must own an AnimationPlayer")
    _require(actor.get_node_or_null("InteractionArea/FootprintCollider") is CollisionShape2D,
        "Battle actor must expose its footprint")
    actor.free()

    var story_role: Node = _load_scene("res://scenes/actors/story_role.tscn")
    var existing: AnimationPlayer = story_role.get_node("BodySprite/NativeSpriteAnimation")
    _require(story_role.configure("shen_changfeng"), "Story sprite cannot bind live animation Resource")
    _require(story_role.get_node("BodySprite/NativeSpriteAnimation") == existing,
        "Profile import must reuse the authored AnimationPlayer")
    _require(existing.has_animation("idle"), "Story sprite idle animation was not assembled")
    story_role.free()

    var burst: Node = _load_scene("res://scenes/vfx/combat_burst.tscn")
    _require(burst.get_node_or_null("MartialStroke") is Line2D and
        burst.get_node_or_null("AuthoredVFX") is Sprite2D and
        burst.get_node_or_null("BurstAudio") is AudioStreamPlayer2D,
        "VFX scene must expose native line, atlas and audio nodes")
    burst.free()

    var card: Node = _load_scene("res://scenes/ui/battle_card.tscn")
    _require(card.get_node_or_null("Painting") is TextureRect and
        card.get_node_or_null("Title") is Label and card.get_node_or_null("Cost") is Label,
        "Card images, title and costs must be native editable nodes")
    card.free()

    var interaction: Node = _load_scene("res://scenes/story/interaction_point.tscn")
    interaction.interaction_id = &"qa_fire"
    var fired: Array = []
    interaction.interaction_requested.connect(func(id): fired.append(id))
    root.add_child(interaction)
    interaction.request_interaction()
    _require(fired.size() == 1 and fired[0] == &"qa_fire",
        "The interaction scene must emit its configured native signal")
    interaction.queue_free()
    await process_frame

    var opening: Node = _load_scene("res://opening.tscn")
    _require(opening.get_node_or_null("NativeMenuUI/MenuControls/Start") is Button,
        "Opening title menu must be an editable native Button tree")
    _require(opening.get_node_or_null("CinematicOverlay/CinematicAnimations") is AnimationPlayer,
        "Opening cutscene must have editable animation tracks")
    _require(opening.get_node_or_null("ForegroundOcclusionClip/ForegroundOcclusion") is TextureRect,
        "Opening occlusion must be editable")
    _require(opening.get_node_or_null("StoryCharacters") is Node2D,
        "Opening roles must have an editable stage")
    opening.free()

    var result: Node = _load_scene("res://demo_result.tscn")
    _require(result.get_node_or_null("ResultUI/ResultPanel/PrimaryAction") is Button,
        "Result UI buttons must be editor-authored")
    result.free()

    var prototype: Node = _load_scene("res://prototypes/pingjiang_25d/pingjiang_25d_validation.tscn")
    _require(prototype.get_node_or_null("Street/TexturedRoad") is MeshInstance3D and
        prototype.get_node_or_null("Street/RoadCollider/CollisionShape3D") is CollisionShape3D,
        "2.5D streets and collisions must be authored resources")
    _require(prototype.get_node_or_null("Street/SideFacade_W_N/FacadePlane") is MeshInstance3D and
        prototype.get_node_or_null("Player/ActorSprite") is Sprite3D,
        "2.5D facades and the player must be editable nodes")
    prototype.free()

    var workbench: Node = _load_scene("res://scenes/native_authoring_workbench.tscn")
    root.add_child(workbench)
    await process_frame
    _require(workbench.get_node_or_null("StoryNPC/BodySprite") is Sprite2D,
        "Workbench must show an editable NPC")
    _require(workbench.get_node_or_null("InteractionPoint/ReachCollider") is CollisionShape2D,
        "Workbench must expose native interaction bounds")
    workbench.queue_free()
    await process_frame

    for failure in failures:
        push_error("NATIVE_AUTHORING: " + failure)
    print("NATIVE_AUTHORING_%s scenes=%d failures=%d" % [
        "PASS" if failures.is_empty() else "FAIL", PATHS.size(), failures.size()])
    quit(0 if failures.is_empty() else 1)
