extends RefCounted
## R8: owns the painted battlefield, actor sprites, and visual movement paths.
## BattleModel still owns positions; these nodes only interpolate committed events.
const IllustratedMap = preload("res://scripts/illustrated_battle_map.gd")
const ArtCatalog = preload("res://scripts/hd2d_art_catalog.gd")
const Facing = preload("res://scripts/actor_facing.gd")

var camera: Camera2D
var illustrated_map: CanvasLayer
var actor_nodes: Dictionary = {}
var visual_cells: Dictionary = {}
var movement_paths: Dictionary = {}
var continuous_paths: Dictionary = {}

func build(host: Node2D, story_encounter: bool, map_path: String,
        actors: Array, animation_driver: Variant) -> void:
    camera = Camera2D.new()
    camera.name = "BattleCamera2D"
    camera.position = Vector2.ZERO
    host.add_child(camera)
    camera.make_current()
    illustrated_map = IllustratedMap.new(story_encounter, map_path)
    host.add_child(illustrated_map)
    for actor in actors:
        add_actor(actor, animation_driver)

func add_actor(actor: Dictionary, animation_driver: Variant) -> void:
    if illustrated_map == null:
        return
    var id := int(actor.id)
    if actor_nodes.has(id):
        return
    var character_id: String = str(actor.get("character_id",""))
    var enemy: bool = int(actor.get("team_id",0)) != 0
    var sheet: Texture2D = ArtCatalog.sheet_for_character(character_id,enemy) if not character_id.is_empty() else ArtCatalog.sheet_for_actor(id,enemy)
    var sprite: Sprite2D = illustrated_map.add_actor(actor,sheet)
    sprite.set_meta("faces_left_unflipped", ArtCatalog.sheet_faces_left_for_character(character_id) if not character_id.is_empty() else ArtCatalog.sheet_faces_left(id))
    actor_nodes[id] = illustrated_map.actors[id]
    visual_cells[id] = Vector2i(actor.cell)
    animation_driver.register_actor(id, sprite,
        Vector2i(actor.get("facing", Vector2i.RIGHT)))

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
            role.visible = float(actor.hp) > 0
            role.z_index = clampi(roundi(role.position.y / 20.0), 0, 100)
    return moving

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

func paths_pending() -> bool:
    return not movement_paths.is_empty() or not continuous_paths.is_empty()

func to_battle_point(screen: Vector2) -> Vector2:
    return illustrated_map.to_battle_point(screen)
