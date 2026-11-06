extends RefCounted
## R8: owns the painted battlefield, actor sprites, and visual movement paths.
## BattleModel still owns positions; these nodes only interpolate committed events.
const IllustratedMapScene = preload("res://scenes/maps/illustrated_battle_map.tscn")
const ArtCatalog = preload("res://scripts/hd2d_art_catalog.gd")
const Facing = preload("res://scripts/actor_facing.gd")
const VisualScale = preload("res://scripts/actor_visual_scale.gd")
const CombatScale = preload("res://scripts/combat_scale.gd")
const ViewportShift = preload("res://scripts/world_viewport_offset.gd")

var camera: Camera2D
var scroll_offset: Vector2 = Vector2.ZERO
var map_world_size: Vector2 = ViewportShift.VIEWPORT_SIZE
var follow_actor_id: int = -1
var illustrated_map: CanvasLayer
var actor_nodes: Dictionary = {}
var visual_cells: Dictionary = {}
var movement_paths: Dictionary = {}
var continuous_paths: Dictionary = {}
var defeated_actors: Dictionary = {}

func build(host: Node2D, story_encounter: bool, map_path: String,
        actors: Array, animation_driver: Variant) -> void:
    camera = host.get_node_or_null("BattleCamera2D") as Camera2D
    if camera == null:
        camera = Camera2D.new()
        camera.name = "BattleCamera2D"
        host.add_child(camera)
    camera.make_current()
    illustrated_map = host.get_node_or_null("IllustratedBattleMap") as CanvasLayer
    if illustrated_map == null:
        # Non-battle test hosts still get exactly the same editor-authored map.
        illustrated_map = IllustratedMapScene.instantiate()
        host.add_child(illustrated_map)
    illustrated_map.configure(map_path)
    if illustrated_map.bake != null and illustrated_map.bake.error.is_empty():
        map_world_size = illustrated_map.bake.viewport_size
    for actor in actors:
        if follow_actor_id < 0 and int(actor.get("team_id", 0)) == 0:
            follow_actor_id = int(actor.id)
        add_actor(actor, animation_driver)
    refresh_scroll()

func add_actor(actor: Dictionary, animation_driver: Variant) -> void:
    if illustrated_map == null:
        return
    var id := int(actor.id)
    if actor_nodes.has(id):
        return
    var character_id: String = str(actor.get("character_id",""))
    var enemy: bool = int(actor.get("team_id",0)) != 0
    var profile: WuxiaActorAnimationProfile = ArtCatalog.animation_profile_for_character(character_id)
    var sheet: Texture2D = profile.idle_atlas() if profile != null else (
        ArtCatalog.sheet_for_character(character_id, enemy) if not character_id.is_empty()
        else ArtCatalog.sheet_for_actor(id, enemy))
    var sprite: Sprite2D = illustrated_map.add_actor(actor, sheet)
    if profile != null:
        sprite.hframes = profile.idle_columns()
        sprite.vframes = profile.idle_rows()
        sprite.offset = profile.feet_offset
        sprite.scale = profile.actor_scale
    var idle_frame: int = 0
    if profile != null and profile.native_frames == null:
        var idle_clip: WuxiaActorAnimationClip = profile.clip_for("idle")
        if idle_clip != null and not idle_clip.frames.is_empty():
            idle_frame = int(idle_clip.frames[0])
    VisualScale.fit(sprite, profile.actor_scale if profile != null else sprite.scale,
        CombatScale.actor_height_pixels(), profile.feet_adjust if profile != null else Vector2.ZERO,
        idle_frame, profile.auto_fit_height if profile != null else true)
    sprite.set_meta("faces_left_unflipped", profile.faces_left_unflipped if profile != null
        else (ArtCatalog.sheet_faces_left_for_character(character_id) if not character_id.is_empty()
        else ArtCatalog.sheet_faces_left(id)))
    actor_nodes[id] = illustrated_map.actors[id]
    visual_cells[id] = Vector2i(actor.cell)
    animation_driver.register_actor(id, sprite,
        Vector2i(actor.get("facing", Vector2i.RIGHT)), profile)

func queue_motion_events(events: Array) -> void:
    for event in events:
        match str(event.get("type", "")):
            "MOVE":
                var id := int(event.get("actor_id", -1))
                if actor_nodes.has(id):
                    continuous_paths.erase(id)
                    visual_cells[id] = Vector2i(event.get("from", Vector2i.ZERO))
                    movement_paths[id] = event.get("path", []).duplicate()
            "MOVE_FREE":
                var id := int(event.get("actor_id", -1))
                if actor_nodes.has(id):
                    movement_paths.erase(id)
                    var steps: Array = []
                    for point in event.get("path", PackedVector2Array()):
                        steps.append(Vector2(point))
                    if not steps.is_empty():
                        steps.pop_front()
                    if not steps.is_empty():
                        continuous_paths[id] = steps

func tick(delta: float, snapshot: Dictionary, animation_driver: Variant) -> Dictionary:
    var moving: Dictionary = {}
    for actor in snapshot.get("actors", []):
        var id := int(actor.id)
        if not actor_nodes.has(id):
            continue
        var node: Node2D = actor_nodes[id]
        if continuous_paths.has(id):
            var free_steps: Array = continuous_paths[id]
            var next_position: Vector2 = Vector2(free_steps[0])
            if node.position.distance_to(next_position) <= 1.0:
                free_steps.pop_front()
            else:
                var heading: Vector2 = next_position - node.position
                animation_driver.set_facing(id, Facing.from_delta(
                    Vector2i(roundi(heading.x), roundi(heading.y)),
                    animation_driver.facing_for(id)))
                node.position = node.position.move_toward(next_position, delta * 160.0)
                if node.position.distance_to(next_position) <= 1.0:
                    node.position = next_position
                    free_steps.pop_front()
            if free_steps.is_empty():
                continuous_paths.erase(id)
                visual_cells[id] = Vector2i(actor.cell)
            else:
                continuous_paths[id] = free_steps
            moving[id] = continuous_paths.has(id)
            continue
        var path: Array = movement_paths.get(id, [])
        var destination: Vector2 = Vector2(actor.get("position",
            illustrated_map.point_for_cell(Vector2i(actor.cell))))
        if not path.is_empty():
            var step := Vector2i(path[0])
            animation_driver.set_facing(id, Facing.from_delta(
                step - Vector2i(visual_cells.get(id, actor.cell)),
                animation_driver.facing_for(id)))
            destination = illustrated_map.point_for_cell(step)
        node.position = node.position.move_toward(destination, delta * 160.0)
        var walking := node.position.distance_to(destination) > 1.0
        if not walking and not path.is_empty():
            node.position = destination
            visual_cells[id] = Vector2i(path.pop_front())
            if path.is_empty():
                movement_paths.erase(id)
            else:
                movement_paths[id] = path
        moving[id] = walking or not path.is_empty()
    for actor in snapshot.get("actors", []):
        var id := int(actor.id)
        var role: Node2D = actor_nodes.get(id, null)
        if role != null:
            if float(actor.hp) <= 0.0 and not defeated_actors.has(id):
                defeated_actors[id] = true
                animation_driver.enqueue_defeat(id)
            # Keep the visible body: defeat holds its final pose until reset.
            role.visible = true
            role.z_index = clampi(roundi(role.position.y / 20.0), 0, 100)
    refresh_scroll()
    return moving

## The offset moves the entire painted CanvasLayer; the fixed HUD is untouched.
## Horizontal and vertical oversized maps share exactly the same calculation.
func refresh_scroll() -> void:
    var followed: Node2D = actor_nodes.get(follow_actor_id, null)
    if followed == null:
        scroll_offset = Vector2.ZERO
        return
    scroll_offset = ViewportShift.world_offset(followed.position, map_world_size)

func snap_to_authority(actors: Array, animation_driver: Variant) -> void:
    movement_paths.clear()
    continuous_paths.clear()
    for actor in actors:
        var id := int(actor.id)
        if not actor_nodes.has(id):
            continue
        actor_nodes[id].position = Vector2(actor.position)
        visual_cells[id] = Vector2i(actor.cell)
        animation_driver.set_facing(id, Vector2i(actor.facing))
    refresh_scroll()

func paths_pending() -> bool:
    return not movement_paths.is_empty() or not continuous_paths.is_empty()

func to_battle_point(screen: Vector2) -> Vector2:
    return illustrated_map.to_battle_point(screen)
