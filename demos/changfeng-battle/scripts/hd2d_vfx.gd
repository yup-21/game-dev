extends RefCounted
## Original 3D wuxia VFX. Pure presentation driven by BattleModel events.
## No RNG, damage, status or hit logic lives here.
var host: Node3D
var camera: Camera3D
var bursts: Array = []

func _init(parent: Node3D, view: Camera3D) -> void:
    host = parent
    camera = view

func _material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.no_depth_test = false
    return mat

func _slash_mesh(radius: float, thickness: float) -> ImmediateMesh:
    var mesh := ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
    for i in range(25):
        var t: float = float(i) / 24.0
        var theta: float = lerpf(-2.55, 0.55, t)
        var width: float = thickness * sin(t * PI)
        var x: float = cos(theta)
        var y: float = sin(theta)
        mesh.surface_add_vertex(Vector3(x * (radius - width), y * (radius - width), 0))
        mesh.surface_add_vertex(Vector3(x * (radius + width), y * (radius + width), 0))
    mesh.surface_end()
    return mesh

func _spawn(pos: Vector3, kind: String, color: Color, duration: float, size: float) -> void:
    if host == null:
        return
    var root := Node3D.new()
    root.name = "WuxiaVFX_" + kind
    root.position = pos + Vector3(0, 1.0, 0)
    host.add_child(root)
    if camera != null:
        root.look_at(camera.global_position, Vector3.UP)
    var instance := MeshInstance3D.new()
    if kind == "slash" or kind == "combo":
        instance.mesh = _slash_mesh(size, 0.13 if kind == "slash" else 0.22)
    else:
        var sphere := SphereMesh.new()
        sphere.radius = size
        sphere.height = size * 2.0
        instance.mesh = sphere
    instance.material_override = _material(color)
    root.add_child(instance)
    bursts.append({"node": root, "mesh": instance, "duration": duration, "left": duration,
        "kind": kind, "color": color})
    if bursts.size() > 32:
        var oldest: Dictionary = bursts.pop_front()
        if is_instance_valid(oldest.node):
            oldest.node.queue_free()

func handle_events(events: Array, actor_nodes: Dictionary) -> void:
    for event in events:
        var kind := str(event.get("type", ""))
        var source := int(event.get("actor_id", -1))
        var target := int(event.get("defender_id", event.get("target_id", -1)))
        match kind:
            "ATTACK_DECLARED":
                if actor_nodes.has(source):
                    _spawn(actor_nodes[source].global_position, "slash",
                        Color(0.70, 0.97, 0.92, 0.78), 0.45, 1.15)
            "COMBO_TRIGGERED":
                if actor_nodes.has(source):
                    _spawn(actor_nodes[source].global_position, "combo",
                        Color(1.00, 0.78, 0.38, 0.90), 0.70, 1.45)
            "HP_DAMAGED", "DAMAGE", "SCORCH_TICK":
                var victim: int = target if actor_nodes.has(target) else source
                if actor_nodes.has(victim):
                    _spawn(actor_nodes[victim].global_position, "impact",
                        Color(1.0, 0.36, 0.27, 0.60), 0.32, 0.38)
            "SHIELD", "INTERCEPT_JUDGED":
                if actor_nodes.has(source):
                    _spawn(actor_nodes[source].global_position, "guard",
                        Color(0.35, 0.88, 0.73, 0.40), 0.38, 0.62)
            "ATTACK_MISSED":
                if actor_nodes.has(target):
                    _spawn(actor_nodes[target].global_position, "evade",
                        Color(0.70, 0.90, 1.0, 0.28), 0.33, 0.42)

func update(delta: float) -> void:
    for i in range(bursts.size() - 1, -1, -1):
        var burst: Dictionary = bursts[i]
        var node: Node3D = burst.node
        if not is_instance_valid(node):
            bursts.remove_at(i)
            continue
        burst.left = maxf(0.0, float(burst.left) - delta)
        var ratio: float = float(burst.left) / maxf(0.01, float(burst.duration))
        var elapsed: float = 1.0 - ratio
        node.scale = Vector3.ONE * (0.7 + elapsed * 0.75)
        node.position.y += delta * 0.13
        var instance: MeshInstance3D = burst.mesh
        var mat: StandardMaterial3D = instance.material_override as StandardMaterial3D
        var tint: Color = burst.color
        tint.a *= ratio * ratio
        mat.albedo_color = tint
        if burst.left <= 0.0:
            node.queue_free()
            bursts.remove_at(i)
        else:
            bursts[i] = burst

func clear() -> void:
    for burst in bursts:
        if is_instance_valid(burst.node):
            burst.node.queue_free()
    bursts.clear()
