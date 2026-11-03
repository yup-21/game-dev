extends RefCounted
## Pure Sprite2D/CanvasItem effects. This class never mutates combat state.
const Assets = preload("res://scripts/asset_registry.gd")
var canvas: Node2D
var bursts: Array = []
var skill_scenes: Array = []
var native_assets = Assets.new()

func _init(painted_layer: Node2D) -> void:
    canvas = painted_layer

# Procedural fallback for events without approved VFX textures.
# Every burst owns its nodes; no battle state or global camera is modified.
func _spawn_canvas(position: Vector2, kind: String, tint: Color,
        duration: float, size: float, source_event: String = "") -> void:
    if canvas == null:
        return
    var root := Node2D.new()
    root.name = "WuxiaVFX2D_" + kind
    root.position = position + Vector2(0.0, -82.0)
    root.z_index = 150
    canvas.add_child(root)

    var stroke := Line2D.new()
    stroke.name = "MartialStroke"
    stroke.antialiased = true
    stroke.width = (6.0 if kind in ["slash", "combo"] else 3.0) * size
    stroke.default_color = tint
    stroke.begin_cap_mode = Line2D.LINE_CAP_ROUND
    stroke.end_cap_mode = Line2D.LINE_CAP_ROUND
    root.add_child(stroke)

    var glow := Line2D.new()
    glow.name = "SoftGlow"
    glow.antialiased = true
    glow.width = stroke.width * 3.4
    var glow_tint := tint
    glow_tint.a *= 0.24
    glow.default_color = glow_tint
    root.add_child(glow)

    var path := PackedVector2Array()
    var count := 28
    for i in range(count + 1):
        var t := float(i) / float(count)
        var angle := lerpf(-2.3, 0.65, t)
        if kind in ["slash", "combo"]:
            path.append(Vector2(cos(angle) * 57.0 * size,
                sin(angle) * 40.0 * size))
        else:
            angle = t * TAU
            path.append(Vector2(cos(angle) * 36.0 * size,
                sin(angle) * 25.0 * size))
    if kind in ["slash", "combo"]:
        # A second, offset cut distinguishes combo from a single attack.
        if kind == "combo":
            var echo := Line2D.new()
            echo.name = "ComboEcho"
            echo.antialiased = true
            echo.width = 2.5 * size
            echo.default_color = Color(1.0, 0.95, 0.76, 0.85)
            echo.points = path
            echo.position = Vector2(12.0, -12.0) * size
            root.add_child(echo)
    else:
        stroke.points = path
        glow.points = path
        # Short radial shards, not a permanent star-shaped outline.
        if kind in ["impact", "shatter", "guard"]:
            var shard_count := 12 if kind == "shatter" else 8
            for i in range(shard_count):
                var angle := TAU * float(i) / float(shard_count)
                var direction := Vector2(cos(angle), sin(angle))
                var shard := Line2D.new()
                shard.name = "Shard"
                shard.antialiased = true
                shard.width = (2.5 if kind == "shatter" else 1.8) * size
                shard.default_color = tint.lightened(0.35)
                shard.points = PackedVector2Array([
                    direction * 12.0 * size,
                    direction * (29.0 if kind == "shatter" else 22.0) * size
                ])
                root.add_child(shard)

    # Authored transparent textures remain the preferred production art.
    var lookup: String = source_event if not source_event.is_empty() and not native_assets.record_for_event(source_event).is_empty() else kind
    var authored_spec: Dictionary = native_assets.record_for_event(lookup)
    var authored: Texture2D = native_assets.texture_for_event(lookup)
    var authored_frames: PackedInt32Array = authored_spec.get("frame_indices", PackedInt32Array())
    if authored != null:
        var sprite := Sprite2D.new()
        sprite.name = "AuthoredVFX"
        sprite.texture = authored
        sprite.hframes = int(authored_spec.get("columns", 1))
        sprite.vframes = int(authored_spec.get("rows", 1))
        if not authored_frames.is_empty():
            sprite.frame = authored_frames[0]
        var longest := maxf(float(authored.get_width()) / float(sprite.hframes),
            float(authored.get_height()) / float(sprite.vframes))
        sprite.scale = Vector2.ONE * (100.0 * size / maxf(longest, 1.0))
        root.add_child(sprite)
    bursts.append({"node": root, "duration": duration, "left": duration,
        "kind": kind, "path": path, "size": size, "vfx_frames": authored_frames})
    if bursts.size() > 32:
        var oldest: Dictionary = bursts.pop_front()
        if is_instance_valid(oldest.node):
            oldest.node.queue_free()

## The optional skill slot loads a regular Godot PackedScene. A finite visual
## lifetime is enforced even if the authored scene does not free itself.
func _spawn_skill_scene(path: String, position: Vector2) -> bool:
    if path.is_empty() or not path.begins_with("res://") or not ResourceLoader.exists(path):
        return false
    var packed: PackedScene = ResourceLoader.load(path) as PackedScene
    if packed == null or canvas == null:
        return false
    var node: Node = packed.instantiate()
    if not node is Node2D:
        node.free()
        return false
    var visual := node as Node2D
    visual.position = position
    visual.z_index = 151
    canvas.add_child(visual)
    skill_scenes.append({"node": visual, "left": 1.5})
    return true


func handle_events(events: Array, actor_nodes: Dictionary) -> void:
    for event in events:
        var kind := str(event.get("type", ""))
        var source := int(event.get("actor_id", -1))
        var target := int(event.get("defender_id", event.get("target_id", -1)))
        var authored_vfx: bool = false
        if kind in ["ATTACK_DECLARED", "ACTION_PRESENTATION"] and actor_nodes.has(source):
            authored_vfx = _spawn_skill_scene(str(event.get("vfx_path", "")),
                actor_nodes[source].position)
        if kind == "ACTION_PRESENTATION" or (kind == "ATTACK_DECLARED" and authored_vfx):
            continue
        match kind:
            "ATTACK_DECLARED":
                if actor_nodes.has(source):
                    _spawn_canvas(actor_nodes[source].position, "slash",
                        Color(0.70, 0.97, 0.92, 0.78), 0.45, 1.15, kind)
            "COMBO_TRIGGERED":
                if actor_nodes.has(source):
                    _spawn_canvas(actor_nodes[source].position, "combo",
                        Color(1.00, 0.78, 0.38, 0.90), 0.70, 1.45, kind)
            "HP_DAMAGED", "DAMAGE", "SCORCH_TICK":
                var victim: int = target if actor_nodes.has(target) else source
                if actor_nodes.has(victim):
                    _spawn_canvas(actor_nodes[victim].position, "impact",
                        Color(1.0, 0.36, 0.27, 0.60), 0.32, 0.38, kind)
            "SHIELD", "INTERCEPT_JUDGED":
                if actor_nodes.has(source):
                    _spawn_canvas(actor_nodes[source].position, "guard",
                        Color(0.35, 0.88, 0.73, 0.40), 0.38, 0.62, kind)
            "ATTACK_MISSED":
                if actor_nodes.has(target):
                    _spawn_canvas(actor_nodes[target].position, "evade",
                        Color(0.70, 0.90, 1.0, 0.28), 0.33, 0.42, kind)
            "POSTURE_BROKEN":
                # The event actor is the staggered target, not the attacker.
                if actor_nodes.has(source):
                    _spawn_canvas(actor_nodes[source].position, "shatter",
                        Color(1.0, 0.75, 0.26, 0.92), 0.58, 1.45, kind)
            "CHAIN_LINK_CANCELED":
                # Cosmetic counter signal; the resolver has already committed it.
                if actor_nodes.has(source):
                    _spawn_canvas(actor_nodes[source].position, "guard",
                        Color(0.65, 0.86, 1.0, 0.70), 0.40, 0.85, kind)

func update(delta: float) -> void:
    for i in range(skill_scenes.size() - 1, -1, -1):
        var entry: Dictionary = skill_scenes[i]
        var node: Node = entry.node
        if not is_instance_valid(node):
            skill_scenes.remove_at(i)
            continue
        entry.left = float(entry.left) - maxf(0.0, delta)
        if float(entry.left) <= 0.0:
            node.queue_free()
            skill_scenes.remove_at(i)
        else:
            skill_scenes[i] = entry
    for i in range(bursts.size() - 1, -1, -1):
        var burst: Dictionary = bursts[i]
        var painted: Node2D = burst.node as Node2D
        if not is_instance_valid(painted):
            bursts.remove_at(i)
            continue
        burst.left = maxf(0.0, float(burst.left) - delta)
        var progress: float = 1.0 - float(burst.left) / maxf(0.01, float(burst.duration))
        var kind: String = str(burst.kind)
        var vfx_frames: PackedInt32Array = burst.get("vfx_frames", PackedInt32Array())
        if not vfx_frames.is_empty():
            var authored_sprite: Sprite2D = painted.get_node_or_null("AuthoredVFX") as Sprite2D
            if authored_sprite != null:
                authored_sprite.frame = vfx_frames[mini(int(progress * vfx_frames.size()), vfx_frames.size() - 1)]
        var stroke: Line2D = painted.get_node("MartialStroke") as Line2D
        var glow: Line2D = painted.get_node("SoftGlow") as Line2D
        if kind in ["slash", "combo"]:
            # Sweep the tip quickly, then let the trail disperse.
            var sweep := clampf(progress / 0.56, 0.0, 1.0)
            var path: PackedVector2Array = burst.path
            var visible_count := maxi(2, int(ceil(sweep * float(path.size()))))
            var first := maxi(0, visible_count - 11)
            var segment := PackedVector2Array()
            for j in range(first, mini(visible_count, path.size())):
                segment.append(path[j])
            stroke.points = segment
            glow.points = segment
            painted.rotation = -0.12 * (1.0 - sweep)
        else:
            var pulse := sin(minf(progress / 0.55, 1.0) * PI * 0.5)
            painted.scale = Vector2.ONE * (0.64 + 0.65 * pulse)
            if kind == "evade":
                painted.position.x += delta * 38.0
                painted.scale.x *= 0.8
        var fade_start := 0.46 if kind in ["slash", "combo"] else 0.22
        var fade := clampf((1.0 - progress) / (1.0 - fade_start), 0.0, 1.0)
        painted.modulate.a = fade * fade
        if burst.left <= 0.0:
            painted.queue_free()
            bursts.remove_at(i)
        else:
            bursts[i] = burst

func clear() -> void:
    for burst in bursts:
        if is_instance_valid(burst.node):
            burst.node.queue_free()
    bursts.clear()
    for entry in skill_scenes:
        if is_instance_valid(entry.node):
            entry.node.queue_free()
    skill_scenes.clear()
