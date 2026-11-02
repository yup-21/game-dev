extends RefCounted
## Human-only key poses. Derived from the character's authored atlas:
## idle frame 1, walk frames 2–5, sword attack frames 6–8.
## No sprite positions or cosmetic bones are required for this motion source.
## All coordinates below are 200px-actor-local, +X facing right, +Y down.

const LEG_REST := {
    "Front": {
        "hip": Vector2(12.0, -95.0),
        "knee": Vector2(19.0, -55.0),
        "ankle": Vector2(18.0, -15.0),
        "toe": Vector2(29.0, 0.0),
    },
    "Rear": {
        "hip": Vector2(-12.0, -95.0),
        "knee": Vector2(-18.0, -53.0),
        "ankle": Vector2(-18.0, -15.0),
        "toe": Vector2(-8.0, 0.0),
    },
}

# Eight sample poses include the loop seam (last point = first point).
const WALK_TIMES := [0.0, 0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80]
const WALK_BOB := [7.0, 5.0, 8.0, 4.0, 7.0, 5.0, 8.0, 4.0, 7.0]
const WALK_PELVIS_X := [-1.0, 0.0, 2.0, 3.0, 1.0, -2.0, -1.0, 0.0, -1.0]
const FRONT_TOE_X := [35.0, 31.0, 27.0, 20.0, 15.0, 18.0, 27.0, 35.0, 35.0]
const FRONT_LIFT := [0.0, 0.0, 0.0, 0.0, 0.0, 8.0, 7.0, 0.0, 0.0]
const REAR_TOE_X := [-19.0, -17.0, -5.0, 2.0, 2.0, -3.0, -11.0, -19.0, -19.0]
const REAR_LIFT := [0.0, 8.0, 8.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

# Preparation / pull-back / drive / impact / follow-through / settle.
const ATTACK_TIMES := [0.0, 0.12, 0.24, 0.36, 0.43, 0.57, 0.76]
const ATTACK_BOB := [4.0, 7.0, 10.0, 8.0, 4.0, 6.0, 4.0]
const ATTACK_PELVIS_X := [0.0, -3.0, -6.0, 8.0, 14.0, 7.0, 0.0]
const ATTACK_FRONT_X := [29.0, 28.0, 30.0, 40.0, 42.0, 35.0, 29.0]
const ATTACK_FRONT_LIFT := [0.0, 0.0, 4.0, 6.0, 0.0, 0.0, 0.0]
const ATTACK_REAR_X := [-8.0, -10.0, -14.0, -13.0, -11.0, -10.0, -8.0]


static func _animation(length: float, looped: bool) -> Animation:
    var result := Animation.new()
    result.length = length
    result.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
    return result


static func _track(owner: Node, animation: Animation, target: Node2D,
        property_name: String, keys: Array, cubic: bool = true) -> void:
    if target == null:
        push_error("SHEN_MOTION_V2: null target for " + property_name)
        return
    var idx := animation.add_track(Animation.TYPE_VALUE)
    animation.track_set_path(idx, NodePath(str(owner.get_path_to(target)) + ":" + property_name))
    animation.value_track_set_update_mode(idx, Animation.UPDATE_CONTINUOUS)
    animation.track_set_interpolation_type(idx,
        Animation.INTERPOLATION_CUBIC if cubic else Animation.INTERPOLATION_LINEAR)
    for pair in keys:
        animation.track_insert_key(idx, float(pair[0]), pair[1])


static func _angles(owner: Node, animation: Animation, bones: Dictionary,
        bone_name: String, samples: Array, times: Array) -> void:
    var keys: Array = []
    for i in range(times.size()):
        keys.append([times[i], deg_to_rad(float(samples[i]))])
    _track(owner, animation, bones.get(bone_name), "rotation", keys)


static func _ornament(owner: Node, animation: Animation, decorations: Dictionary,
        bone_name: String, degrees: Array, times: Array) -> void:
    if not decorations.has(bone_name):
        return
    _angles(owner, animation, decorations, bone_name, degrees, times)


static func _leg_angles(prefix: String, toe_x: float, lift: float,
        pelvis_bob: float, pelvis_dx: float) -> Vector3:
    # 2-bone IK in the authored rest-pose coordinate frame.
    # Keep heel/toe at or above the floor, with a level foot through stance.
    var rest: Dictionary = LEG_REST[prefix]
    var hip: Vector2 = rest["hip"] + Vector2(pelvis_dx, pelvis_bob)
    var knee_rest: Vector2 = rest["knee"]
    var ankle_rest: Vector2 = rest["ankle"]
    var foot_offset: Vector2 = rest["toe"] - ankle_rest
    var ankle_goal := Vector2(toe_x - foot_offset.x,
        -foot_offset.y - maxf(lift, 0.0))
    var v1: Vector2 = knee_rest - rest["hip"]
    var v2: Vector2 = ankle_rest - knee_rest
    var l1 := v1.length()
    var l2 := v2.length()
    var delta: Vector2 = ankle_goal - hip
    var distance := clampf(delta.length(), absf(l1-l2)+0.01, l1+l2-0.01)
    var along: Vector2 = delta.normalized() if delta.length() > 0.001 else Vector2.DOWN
    var projection: float = (distance*distance + l1*l1 - l2*l2) / (2.0 * distance)
    var perpendicular_height := sqrt(maxf(0.0, l1*l1 - projection*projection))
    # Knee bends forward (+X) as in the original right-facing character frames.
    var side := Vector2(-along.y, along.x)
    var knee_goal := hip + along * projection - side * perpendicular_height
    var theta1 := (knee_goal - hip).angle() - v1.angle()
    var theta2 := (ankle_goal - knee_goal).angle() - v2.angle()
    return Vector3(theta1, theta2-theta1, -theta2)


static func _grounded_legs(owner: Node, animation: Animation, bones: Dictionary,
        times: Array, bob: Array, pelvis_x: Array, toe_front: Array, lift_front: Array,
        toe_rear: Array, lift_rear: Array) -> void:
    var pelvis_keys: Array = []
    for i in range(times.size()):
        pelvis_keys.append([times[i], Vector2(float(pelvis_x[i]), -100.0 + float(bob[i]))])
    _track(owner, animation, bones["Pelvis"], "position", pelvis_keys, false)
    for group in ["Front", "Rear"]:
        var hip_keys: Array = []
        var knee_keys: Array = []
        var ankle_keys: Array = []
        for i in range(times.size()):
            var x: float = float(toe_front[i]) if group == "Front" else float(toe_rear[i])
            var lift: float = float(lift_front[i]) if group == "Front" else float(lift_rear[i])
            var ik := _leg_angles(group, x, lift, float(bob[i]), float(pelvis_x[i]))
            hip_keys.append([times[i], ik.x])
            knee_keys.append([times[i], ik.y])
            ankle_keys.append([times[i], ik.z])
        # Use linear interpolation for IK: cubic overshoot can sink a toe below 0.
        _track(owner, animation, bones[group+"Hip"], "rotation", hip_keys, false)
        _track(owner, animation, bones[group+"Knee"], "rotation", knee_keys, false)
        _track(owner, animation, bones[group+"Ankle"], "rotation", ankle_keys, false)


static func idle(owner: Node, bones: Dictionary, decorations: Dictionary) -> Animation:
    var a := _animation(1.3, true)
    var times := [0.0, 0.325, 0.65, 0.975, 1.30]
    _angles(owner, a, bones, "Waist", [0.0, -1.0, 0.1, 0.7, 0.0], times)
    _angles(owner, a, bones, "Chest", [-0.7, 0.6, 1.2, 0.0, -0.7], times)
    _angles(owner, a, bones, "Neck", [0.6, -0.3, -0.5, 0.0, 0.6], times)
    _angles(owner, a, bones, "FrontShoulder", [0.0, -0.4, -0.8, -0.3, 0.0], times)
    _angles(owner, a, bones, "RearShoulder", [0.0, 0.2, 0.5, 0.1, 0.0], times)
    _ornament(owner, a, decorations, "HairTip", [2.0, 0.5, -2.3, -0.1, 2.0], times)
    _ornament(owner, a, decorations, "CoatBackTip", [0.0, 0.8, -0.8, 0.0, 0.0], times)
    _ornament(owner, a, decorations, "CoatFrontTip", [-0.7, 0.0, 0.9, 0.2, -0.7], times)
    return a


static func walk(owner: Node, bones: Dictionary, decorations: Dictionary) -> Animation:
    var a := _animation(0.80, true)
    _grounded_legs(owner, a, bones, WALK_TIMES, WALK_BOB, WALK_PELVIS_X,
        FRONT_TOE_X, FRONT_LIFT, REAR_TOE_X, REAR_LIFT)
    _angles(owner, a, bones, "Waist", [12, 10, 8, 11, 12, 10, 8, 11, 12], WALK_TIMES)
    _angles(owner, a, bones, "Chest", [7, 9, 11, 8, 7, 9, 11, 8, 7], WALK_TIMES)
    _angles(owner, a, bones, "Neck", [-5, -4, -6, -5, -5, -4, -6, -5, -5], WALK_TIMES)
    _angles(owner, a, bones, "FrontShoulder", [-48, -54, -61, -52, -46, -38, -49, -53, -48], WALK_TIMES)
    _angles(owner, a, bones, "RearShoulder", [25, 32, 42, 35, 25, 20, 33, 32, 25], WALK_TIMES)
    _angles(owner, a, bones, "FrontElbow", [60, 69, 73, 65, 60, 55, 62, 66, 60], WALK_TIMES)
    _angles(owner, a, bones, "RearElbow", [-57, -62, -68, -62, -57, -49, -58, -63, -57], WALK_TIMES)
    _ornament(owner, a, decorations, "HairTip", [5, 7, 4, -2, -5, -6, -3, 2, 5], WALK_TIMES)
    _ornament(owner, a, decorations, "CoatFrontTip", [5, 7, 2, -3, -5, -7, -2, 2, 5], WALK_TIMES)
    _ornament(owner, a, decorations, "CoatBackTip", [-5, -7, -2, 3, 5, 7, 2, -2, -5], WALK_TIMES)
    return a


static func attack(owner: Node, bones: Dictionary, decorations: Dictionary,
        weapon_socket: Marker2D) -> Animation:
    var a := _animation(0.76, false)
    _grounded_legs(owner, a, bones, ATTACK_TIMES, ATTACK_BOB, ATTACK_PELVIS_X,
        ATTACK_FRONT_X, ATTACK_FRONT_LIFT, ATTACK_REAR_X,
        [0, 0, 0, 0, 0, 0, 0])
    _angles(owner, a, bones, "Waist", [0, -4, -9, 6, 12, 4, 0], ATTACK_TIMES)
    _angles(owner, a, bones, "Chest", [0, -7, -17, 10, 20, 8, 0], ATTACK_TIMES)
    _angles(owner, a, bones, "Neck", [0, 2, 6, -2, -6, -2, 0], ATTACK_TIMES)
    _angles(owner, a, bones, "FrontShoulder", [0, -14, -37, 20, 43, 15, 0], ATTACK_TIMES)
    _angles(owner, a, bones, "FrontElbow", [0, 15, 47, -15, -38, -12, 0], ATTACK_TIMES)
    _angles(owner, a, bones, "FrontWrist", [0, -7, -19, 9, 22, 5, 0], ATTACK_TIMES)
    _angles(owner, a, bones, "RearShoulder", [0, 8, 14, -4, -9, -3, 0], ATTACK_TIMES)
    _angles(owner, a, bones, "RearElbow", [0, -7, -17, 7, 9, 3, 0], ATTACK_TIMES)
    _track(owner, a, weapon_socket, "rotation",
        [[0.0, 0.0], [0.12, deg_to_rad(-10.0)], [0.24, deg_to_rad(-32.0)],
        [0.36, deg_to_rad(9.0)], [0.43, deg_to_rad(38.0)],
        [0.57, deg_to_rad(12.0)], [0.76, 0.0]], false)
    _ornament(owner, a, decorations, "HairTip", [0, -4, -11, 6, 13, 6, 0], ATTACK_TIMES)
    _ornament(owner, a, decorations, "CoatFrontTip", [0, 5, 11, -8, -14, -6, 0], ATTACK_TIMES)
    _ornament(owner, a, decorations, "CoatBackTip", [0, -5, -11, 7, 13, 6, 0], ATTACK_TIMES)
    return a
