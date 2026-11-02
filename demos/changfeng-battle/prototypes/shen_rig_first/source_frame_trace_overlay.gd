extends Node2D
## Three-way pose visual acceptance overlay:
## white/yellow = manually traced source landmarks,
## cyan = actual Godot Bone2D joints, orange/red = fitting residuals.

var skeleton: Skeleton2D
var targets: Dictionary = {}
var uncertain: Array = []
var show_goals := true
var show_bones := true

const LINES := [
    ["Pelvis", "Waist"], ["Waist", "Chest"], ["Chest", "Neck"], ["Neck", "Head"],
    ["Chest", "FrontShoulder"], ["FrontShoulder", "FrontElbow"],
    ["FrontElbow", "FrontWrist"], ["FrontWrist", "FrontHand"],
    ["Chest", "RearShoulder"], ["RearShoulder", "RearElbow"],
    ["RearElbow", "RearWrist"], ["RearWrist", "RearHand"],
    ["Pelvis", "FrontHip"], ["FrontHip", "FrontKnee"],
    ["FrontKnee", "FrontAnkle"], ["FrontAnkle", "FrontFoot"],
    ["Pelvis", "RearHip"], ["RearHip", "RearKnee"],
    ["RearKnee", "RearAnkle"], ["RearAnkle", "RearFoot"],
]

var _bones := {}


func initialize(body: Skeleton2D) -> void:
    skeleton = body
    _collect(body)


func _collect(node: Node) -> void:
    for child in node.get_children():
        if child is Bone2D:
            _bones[child.name] = child
            _collect(child)


func _joint(name: String) -> Vector2:
    var bone: Bone2D = _bones.get(name)
    return skeleton.to_local(bone.global_position) if bone != null else Vector2.ZERO


func _draw() -> void:
    if skeleton == null:
        return
    if show_bones:
        for entry in LINES:
            var p: String = entry[0]
            var q: String = entry[1]
            var line_color := Color(0.10, 0.94, 1.0, 0.92)
            if uncertain.has(p) or uncertain.has(q):
                line_color = Color(0.60, 0.67, 0.72, 0.68)
            draw_line(_joint(p), _joint(q), line_color, 2.3, true)
        for name in _bones:
            if not targets.has(name):
                continue
            draw_circle(_joint(name), 2.4,
                Color(0.10, 0.94, 1.0) if not uncertain.has(name) else Color(0.60, 0.67, 0.72))
        # Weapon is an independent marker chain, not a body bone.
        # Draw its REAL Godot grip and tip, including cases where the
        # source artwork is too damaged to trust the authored sword-tip.
        var hand: Bone2D = _bones.get("FrontHand")
        if hand != null:
            var grip: Marker2D = hand.get_node("WeaponSocket") as Marker2D
            var tip: Marker2D = grip.get_node("WeaponTip") as Marker2D
            var actual_grip: Vector2 = skeleton.to_local(grip.global_position)
            var actual_tip: Vector2 = skeleton.to_local(tip.global_position)
            var weapon_color := Color(0.86, 0.87, 0.90, 0.90)
            if uncertain.has("SwordBlade"):
                weapon_color = Color(0.65, 0.67, 0.70, 0.72)
            draw_line(actual_grip, actual_tip, weapon_color, 2.1, true)
            draw_circle(actual_grip, 3.5, Color(0.95, 0.70, 0.28))
            draw_circle(actual_tip, 2.7, weapon_color)
    if show_goals:
        for name in targets:
            var current: Vector2
            if _bones.has(name):
                current = _joint(name)
            elif name == "SwordGrip" or name == "SwordBlade":
                var hand: Bone2D = _bones.get("FrontHand")
                var marker: Marker2D = hand.get_node("WeaponSocket") as Marker2D
                var tip_marker: Marker2D = marker.get_node("WeaponTip") as Marker2D
                current = skeleton.to_local(marker.global_position) if name == "SwordGrip" else skeleton.to_local(tip_marker.global_position)
            else:
                continue
            var goal: Vector2 = targets[name]
            var low_confidence := uncertain.has(name)
            var cross_color := Color(0.96, 0.70, 0.18) if low_confidence else Color(1.0, 0.35, 0.50)
            draw_line(goal + Vector2(-3, 0), goal + Vector2(3, 0), cross_color, 1.1)
            draw_line(goal + Vector2(0, -3), goal + Vector2(0, 3), cross_color, 1.1)
            if not low_confidence and current.distance_to(goal) > 2.0:
                draw_line(current, goal, Color(1.0, 0.34, 0.30, 0.85), 1.2, true)
