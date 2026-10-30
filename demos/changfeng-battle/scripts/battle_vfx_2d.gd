extends RefCounted
## Pure Sprite2D/CanvasItem effects. This class never mutates combat state.
var canvas: Node2D
var bursts: Array = []

func _init(painted_layer: Node2D) -> void:
    canvas = painted_layer

func _spawn_canvas(position: Vector2, kind: String, tint: Color,
        duration: float, size: float) -> void:
    if canvas==null: return
    var root:=Node2D.new()
    root.name="WuxiaVFX2D_"+kind
    root.position=position+Vector2(0.0,-82.0)
    root.z_index=150
    canvas.add_child(root)
    var arc:=Line2D.new()
    arc.name="MartialStroke"
    arc.antialiased=true
    arc.width=5.0*size
    arc.default_color=tint
    arc.begin_cap_mode=Line2D.LINE_CAP_ROUND
    arc.end_cap_mode=Line2D.LINE_CAP_ROUND
    var points:=PackedVector2Array()
    var count:=22
    if kind in ["slash","combo"]:
        for i in range(count+1):
            var t:=float(i)/float(count)
            var angle:=lerpf(-2.30,0.65,t)
            points.append(Vector2(cos(angle)*55.0*size,sin(angle)*36.0*size))
    elif kind in ["guard","evade"]:
        for i in range(count+1):
            var t:=float(i)/float(count)
            var angle:=t*TAU
            points.append(Vector2(cos(angle)*36.0*size,sin(angle)*20.0*size))
    else:
        for i in range(9):
            var angle:=TAU*float(i)/8.0
            var length:=25.0*size if i%2==0 else 9.0*size
            points.append(Vector2(cos(angle)*length,sin(angle)*length))
    arc.points=points
    root.add_child(arc)
    if kind in ["slash","combo"]:
        var secondary:=Line2D.new()
        secondary.antialiased=true
        secondary.width=15.0*size
        var glow: Color=tint
        glow.a*=0.22
        secondary.default_color=glow
        secondary.points=points
        root.add_child(secondary)
    bursts.append({"node":root,"duration":duration,"left":duration,
        "kind":kind,"color":tint,"canvas":true})
    if bursts.size()>32:
        var oldest: Dictionary=bursts.pop_front()
        if is_instance_valid(oldest.node): oldest.node.queue_free()

func handle_events(events: Array, actor_nodes: Dictionary) -> void:
    for event in events:
        var kind := str(event.get("type", ""))
        var source := int(event.get("actor_id", -1))
        var target := int(event.get("defender_id", event.get("target_id", -1)))
        match kind:
            "ATTACK_DECLARED":
                if actor_nodes.has(source):
                    _spawn_canvas(actor_nodes[source].position, "slash",
                        Color(0.70, 0.97, 0.92, 0.78), 0.45, 1.15)
            "COMBO_TRIGGERED":
                if actor_nodes.has(source):
                    _spawn_canvas(actor_nodes[source].position, "combo",
                        Color(1.00, 0.78, 0.38, 0.90), 0.70, 1.45)
            "HP_DAMAGED", "DAMAGE", "SCORCH_TICK":
                var victim: int = target if actor_nodes.has(target) else source
                if actor_nodes.has(victim):
                    _spawn_canvas(actor_nodes[victim].position, "impact",
                        Color(1.0, 0.36, 0.27, 0.60), 0.32, 0.38)
            "SHIELD", "INTERCEPT_JUDGED":
                if actor_nodes.has(source):
                    _spawn_canvas(actor_nodes[source].position, "guard",
                        Color(0.35, 0.88, 0.73, 0.40), 0.38, 0.62)
            "ATTACK_MISSED":
                if actor_nodes.has(target):
                    _spawn_canvas(actor_nodes[target].position, "evade",
                        Color(0.70, 0.90, 1.0, 0.28), 0.33, 0.42)

func update(delta: float) -> void:
    for i in range(bursts.size() - 1, -1, -1):
        var burst: Dictionary = bursts[i]
        var painted: Node2D = burst.node as Node2D
        if not is_instance_valid(painted):
            bursts.remove_at(i)
            continue
        burst.left = maxf(0.0, float(burst.left) - delta)
        var ratio: float = float(burst.left) / maxf(0.01, float(burst.duration))
        var elapsed: float = 1.0 - ratio
        painted.scale = Vector2.ONE * (0.7 + elapsed * 0.8)
        painted.position.y -= delta * 10.0
        painted.modulate.a = ratio * ratio
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
