extends RefCounted
## Source-frame JOINT FIT, not an unmeasured, hand-authored motion approximation.
## Follows the exact silhouette landmarks from source_frame_landmarks_v1.json.
## No edits to universal body proportions, no artwork attachment and no
## assumption that detached boots in the source attack frames are valid feet.

const DATA := "res://prototypes/shen_rig_first/source_frame_landmarks_v1.json"
const SCALE := 0.75
const ORIGIN := Vector2(245.0, 470.0)
const CORE_LINKS := [
    ["Pelvis", "Waist"], ["Waist", "Chest"], ["Chest", "Neck"], ["Neck", "Head"],
    ["FrontShoulder", "FrontElbow"], ["FrontElbow", "FrontWrist"],
    ["FrontWrist", "FrontHand"],
    ["RearShoulder", "RearElbow"], ["RearElbow", "RearWrist"],
    ["RearWrist", "RearHand"],
    ["FrontHip", "FrontKnee"], ["FrontKnee", "FrontAnkle"],
    ["FrontAnkle", "FrontFoot"],
    ["RearHip", "RearKnee"], ["RearKnee", "RearAnkle"],
    ["RearAnkle", "RearFoot"],
]
const CORE_JOINTS := [
    "Pelvis","Waist","Chest","Neck","Head",
    "FrontShoulder","FrontElbow","FrontWrist","FrontHand",
    "RearShoulder","RearElbow","RearWrist","RearHand",
    "FrontHip","FrontKnee","FrontAnkle","FrontFoot",
    "RearHip","RearKnee","RearAnkle","RearFoot",
]


static func reference_data() -> Dictionary:
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
    return value if value is Dictionary else {}


static func frame(data: Dictionary, name: String) -> Dictionary:
    for candidate in data.get("frames", []):
        if str(candidate["name"]) == name:
            return candidate
    return {}


static func point_in_world(reference_point: Array) -> Vector2:
    return (Vector2(float(reference_point[0]), float(reference_point[1])) - ORIGIN) * SCALE


static func targets_for(frame_data: Dictionary) -> Dictionary:
    var result := {}
    for point_name in frame_data["points"]:
        result[str(point_name)] = point_in_world(frame_data["points"][point_name])
    # A hidden center-spine landmark; this is an explicit interpolation, NOT
    # an observable joint from the painted silhouette.
    result["Waist"] = result["pelvis"].lerp(result["chest"], 0.51)
    result["Pelvis"] = result["pelvis"]
    result["Chest"] = result["chest"]
    result["Neck"] = result["neck"]
    result["Head"] = result["head"]
    return result


static func _collect_bones(node: Node, bones: Dictionary) -> void:
    for child in node.get_children():
        if child is Bone2D:
            bones[child.name] = child
            _collect_bones(child, bones)


static func _aim(skeleton: Skeleton2D, parent: Bone2D,
        child: Bone2D, destination: Vector2) -> void:
    if child.position.length() < 0.001:
        return
    var desired_global := skeleton.to_global(destination)
    var toward: Vector2 = desired_global - parent.global_position
    if toward.length() < 0.001:
        return
    parent.global_rotation = toward.angle() - child.position.angle()


static func apply(scene: Node2D, reference: Dictionary) -> Dictionary:
    scene.show_bind_pose()
    var skeleton: Skeleton2D = scene.get_node("Skeleton2D")
    var bones := {}
    _collect_bones(skeleton, bones)
    var target := targets_for(reference)
    var pelvis: Bone2D = bones["Pelvis"]
    # Only the pelvis is translated; the world foot/actor Root remains fixed.
    pelvis.position = target["Pelvis"]

    for link in CORE_LINKS:
        var name: String = link[0]
        var child_name: String = link[1]
        _aim(skeleton, bones[name], bones[child_name], target[child_name])

    # The body bones drive the handle, but the blade direction is determined
    # from the source art when it is legible (attack 7/8 blade is ambiguous).
    var grip: Marker2D = bones["FrontHand"].get_node("WeaponSocket") as Marker2D
    var tip: Marker2D = grip.get_node("WeaponTip") as Marker2D
    if target.has("SwordGrip") and target.has("SwordBlade"):
        var dir: Vector2 = target["SwordBlade"] - target["SwordGrip"]
        if dir.length() >= 25.0:
            var blade_world := dir.angle()
            grip.global_rotation = blade_world - tip.position.angle()

    var errors: Dictionary = {}
    var scored: Array[float] = []
    var low: Array = reference.get("low_confidence", [])
    for name in target:
        if name == "Waist" or name == "SwordBlade" or name == "SwordGrip":
            continue
        if not bones.has(name):
            continue
        var actual: Vector2 = skeleton.to_local(bones[name].global_position)
        var deviation := actual.distance_to(target[name])
        errors[name] = snappedf(deviation, 0.01)
        if not low.has(name):
            scored.append(deviation)
    var total := 0.0
    var maximum := 0.0
    for value in scored:
        total += value
        maximum = maxf(maximum, value)
    var source_quality := "partially_occluded" if low.size() >= 8 else "usable"
    var grip_current: Vector2 = skeleton.to_local(grip.global_position)
    var tip_current: Vector2 = skeleton.to_local(tip.global_position)
    var grip_error := -1.0
    var tip_error := -1.0
    if target.has("SwordGrip"):
        grip_error = snappedf(grip_current.distance_to(target["SwordGrip"]), 0.01)
    if target.has("SwordBlade"):
        tip_error = snappedf(tip_current.distance_to(target["SwordBlade"]), 0.01)
    return {
        "name": reference["name"],
        "source_frame": reference["source_frame"],
        "scored_joints": scored.size(),
        "mean_error_px": snappedf(total / maxf(1.0, float(scored.size())), 0.01),
        "max_error_px": snappedf(maximum, 0.01),
        "errors": errors,
        "low_confidence": low,
        "source_quality": source_quality,
        "reference_landmarks_world": target,
        "root_still_fixed": skeleton.position == Vector2(800.0, 730.0),
        "weapon_grip_world": grip_current,
        "weapon_tip_world": tip_current,
        "weapon_grip_error_px": grip_error,
        "weapon_tip_error_px": tip_error,
    }
