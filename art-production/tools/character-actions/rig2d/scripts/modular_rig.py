"""Read a new, layered profile asset and solve rigid 2D placements."""

from dataclasses import dataclass
from hashlib import sha256
import json
import math
from pathlib import Path

from mathutils import Vector


CORE_PARTS = {
    "torso", "head", "sword",
    *(f"{side}_{part}" for side in ("left", "right")
      for part in ("upper_arm", "forearm", "hand", "thigh", "shin", "foot")),
}
CORE_TORSO_PORTS = {"head", "left_shoulder", "right_shoulder", "left_hip", "right_hip"}


def point(values):
    p = Vector(values)
    if len(p) != 2 or not all(math.isfinite(n) for n in p):
        raise ValueError(f"Expected a finite two-dimensional point, got {values}")
    return p


def angle(v):
    return math.atan2(v.y, v.x)


def clamp(value, low, high):
    return min(high, max(low, value))


def angle_delta(target, reference):
    return (target - reference + math.pi) % (2 * math.pi) - math.pi


def bounded_degrees(value, field, limit):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError(f"{field} must be a finite angle in degrees")
    return math.radians(clamp(value, -limit, limit))


@dataclass(frozen=True)
class Part:
    name: str
    texture: Path
    pivot: Vector
    axis: Vector
    length: float
    ports: dict
    depth: int
    polygon: tuple | None

    @property
    def scale(self):
        return self.length / (self.axis - self.pivot).length


@dataclass(frozen=True)
class Placement:
    part: Part
    target: Vector
    radians: float

    def at(self, texture_point):
        x, y = (texture_point - self.part.pivot) * self.part.scale
        c, s = math.cos(self.radians), math.sin(self.radians)
        return self.target + point((c * x - s * y, s * x + c * y))

    def port(self, name):
        return self.at(self.part.ports[name])


def directed(part, root, target_angle):
    return Placement(part, root, target_angle - angle(part.axis - part.pivot))


def solve_chain(root, requested, authored_middle, first, second, fallback_bend):
    """Resolve fixed-length IK toward the authored joint, retaining the side near straight."""
    delta = requested - root
    distance = delta.length
    direction = delta.normalized() if distance else point((1, 0))
    epsilon = min(0.10, first * 0.25, second * 0.25)
    reach = clamp(distance, abs(first - second) + epsilon, first + second - epsilon)
    endpoint = root + direction * reach
    along = (reach * reach + first * first - second * second) / (2 * reach)
    across = math.sqrt(max(0, first * first - along * along))
    normal = point((-direction.y, direction.x))
    authored_offset = (authored_middle - root).dot(normal)
    bend = fallback_bend if abs(authored_offset) <= 1.0 else 1 if authored_offset > 0 else -1
    middle = root + along * direction + bend * across * normal
    return middle, endpoint, bend


def load_manifest(path):
    doc = json.loads(path.read_text("utf-8"))
    if (doc.get("schema_version"), doc.get("source_kind"), doc.get("view"), doc.get("facing")) != (
            1, "generated_orthographic_modular_art", "orthographic_90", "right"):
        raise ValueError("Use the new orthographic profile art manifest")
    directory = path.resolve().parent
    provenance = doc["generated_atlas"]
    atlas = (directory / provenance["path"]).resolve(strict=True)
    if not atlas.is_relative_to(directory) or sha256(atlas.read_bytes()).hexdigest() != provenance["sha256"]:
        raise ValueError("Generated atlas location or SHA256 changed")
    parts = {}
    depths = set()
    for item in doc["parts"]:
        name = item["name"]
        path = (directory / item["texture"]).resolve(strict=True)
        pivot, axis = point(item["pivot"]), point(item["axis"])
        length = float(item["length_px"])
        depth = item["depth"]
        if not path.is_relative_to(directory) or path.suffix.lower() != ".png":
            raise ValueError(f"Part {name} must use a PNG under this manifest directory")
        if name in parts or depth in depths or length <= 0 or not math.isfinite(length) or (axis - pivot).length < 0.01:
            raise ValueError(f"Invalid, duplicate or zero-length part: {name}")
        polygon = tuple(point(p) for p in item["polygon"]) if "polygon" in item else None
        if polygon is not None and len(polygon) < 3:
            raise ValueError(f"Part {name} has an incomplete polygon")
        parts[name] = Part(name, path, pivot, axis, length,
                           {key: point(value) for key, value in item.get("ports", {}).items()},
                           depth, polygon)
        depths.add(depth)
    if missing := CORE_PARTS - parts.keys():
        raise ValueError(f"Missing profile parts: {sorted(missing)}")
    if missing := CORE_TORSO_PORTS - parts["torso"].ports.keys():
        raise ValueError(f"Missing torso mounts: {sorted(missing)}")
    for side in ("left", "right"):
        if "ankle" not in parts[f"{side}_foot"].ports:
            raise ValueError(f"Missing {side} boot ankle")
    accessories = {item["part"]: item for item in doc.get("accessories", [])}
    cuffs = doc.get("elbow_cuffs", {})
    overlaps = doc.get("shoulder_overlaps", {})
    ankles = doc.get("ankle_overlays", {})
    toes = doc.get("toe_overlays", {})
    tassel = doc.get("sword_tassel")
    attachments = [*accessories, *(item["part"] for item in cuffs.values()),
                   *(item["part"] for item in overlaps.values()),
                   *(item["part"] for item in ankles.values()),
                   *(item["part"] for item in toes.values())]
    if tassel is not None:
        attachments.append(tassel["part"])
        if tassel["sword_port"] not in parts["sword"].ports:
            raise ValueError("Sword tassel has no matching sword mount")
    if len(set(attachments)) != len(attachments) or parts.keys() - CORE_PARTS != set(attachments):
        raise ValueError("Every non-body layer needs exactly one declared mount")
    for item in accessories.values():
        parent = item.get("parent", "torso")
        if parent not in ("torso", "head") or item["port"] not in parts[parent].ports:
            raise ValueError("Accessory has no matching body port")
    for side, item in cuffs.items():
        weight = item["forearm_weight"]
        if side not in ("left", "right") or not 0 <= weight <= 1:
            raise ValueError("Elbow cuff needs a valid side and blend weight in 0..1")
    for side, item in overlaps.items():
        if side not in ("left", "right") or not 0 <= item["arm_weight"] <= 1:
            raise ValueError("Shoulder overlap needs a valid side and blend weight in 0..1")
    for side, item in ankles.items():
        if side not in ("left", "right") or item["part"] not in parts:
            raise ValueError("Ankle overlay needs a valid side and texture part")
    for side, item in toes.items():
        if side not in ("left", "right") or item["part"] not in parts:
            raise ValueError("Toe overlay needs a valid side and texture part")
        shoe, tip = parts[f"{side}_foot"], parts[item["part"]]
        # Both polygons are cut from the same atlas. They must have identical
        # texture scale so that the seam is closed when the toe is relaxed.
        if abs(shoe.scale - tip.scale) > 0.0001:
            raise ValueError(f"{side} toe overlay must match the shoe's texture scale")
    if any(doc["bend"][f"{side}_{chain}"] not in (-1, 1)
           for side in ("left", "right") for chain in ("arm", "leg")):
        raise ValueError("Every arm and leg bend direction must be -1 or 1")
    return doc, parts


def solve_frame(frame, doc, parts, previous_bends, grip_velocity_x=0.0):
    joints = {name: point(xy) for name, xy in frame["authored_keypoints_coco18"].items()}
    hips = (joints["left_hip"] + joints["right_hip"]) / 2
    if "rig_pelvis_px" in frame:
        hips = point(frame["rig_pelvis_px"])
    spine = joints["neck"] - hips
    requested_lean = frame.get("rig_torso_lean_degrees", math.degrees(math.atan2(spine.x, -spine.y)))
    if not math.isfinite(requested_lean):
        raise ValueError("Torso tilt must be finite")
    action = frame.get("action_id")
    limit = {"defeat": 100, "idle": 13}.get(action, 24)
    if abs(requested_lean) > limit:
        raise ValueError(f"{action} torso tilt {requested_lean}° exceeds ±{limit}°")
    lean = math.radians(requested_lean)
    head_counter = bounded_degrees(frame.get("rig_head_counter_degrees", 0), "rig_head_counter_degrees", 10)
    hem_follow = frame.get("rig_hem_follow_torso", 0)
    if not isinstance(hem_follow, (int, float)) or not 0 <= hem_follow <= 1:
        raise ValueError("rig_hem_follow_torso must be in [0, 1]")
    torso = Placement(parts["torso"], hips, lean)
    placed = {"torso": torso, "head": Placement(parts["head"], torso.port("head"), lean + head_counter)}
    diagnostics = {"torso_rotation_degrees": math.degrees(lean),
                   "head_counter_rotation_degrees": math.degrees(head_counter),
                   "rig_pelvis_px": list(hips), "head_mount_px": list(torso.port("head")),
                   "chain_fit": {}}
    if "scalp" in parts["head"].ports:
        diagnostics["scalp_proxy_px"] = list(placed["head"].port("scalp"))
    feet_center = (joints["left_ankle"] + joints["right_ankle"]) / 2
    cloth_sway = clamp((feet_center.x - hips.x) * 0.003, -0.06, 0.06)
    secondary = frame.get("rig_secondary_degrees", {})
    hem_headings = frame.get("rig_secondary_heading_degrees", {})
    if hem_headings and (action != "defeat" or set(hem_headings) - {"front_hem", "back_hem"}):
        raise ValueError("Absolute cloth headings apply only to defeat hem layers")
    diagnostics["secondary_angles_degrees"] = {}
    for item in doc.get("accessories", []):
        name = item["part"]
        parent = placed[item.get("parent", "torso")]
        authored_sway = bounded_degrees(secondary.get(name, 0), f"rig_secondary_degrees.{name}", 8)
        lean_gain = item.get("lean_gain", 1)
        if name in {"front_hem", "back_hem"}:
            lean_gain += (1 - lean_gain) * hem_follow
        accessory_angle = lean * lean_gain + cloth_sway * item.get("sway_gain", 0) + authored_sway
        if name in hem_headings:
            accessory_angle = bounded_degrees(hem_headings[name], f"rig_secondary_heading_degrees.{name}", 110)
        placed[name] = Placement(parts[name], parent.port(item["port"]), accessory_angle)
        diagnostics["secondary_angles_degrees"][name] = math.degrees(accessory_angle)

    def fit(name, root, target, middle_name, first, second):
        authored_middle = joints[middle_name]
        fallback = previous_bends.get(name, doc["bend"][name])
        middle, endpoint, bend = solve_chain(root, target, authored_middle, first, second, fallback)
        previous_bends[name] = bend
        diagnostics["chain_fit"][name] = {
            "authored_joint_px": list(authored_middle), "solved_joint_px": list(middle),
            "joint_error_px": (middle - authored_middle).length,
            "requested_endpoint_px": list(target), "solved_endpoint_px": list(endpoint),
            "reach_correction_px": (endpoint - target).length, "bend": bend,
        }
        return middle, endpoint

    toe_angles = frame.get("rig_toe_flex_degrees", {})
    if not isinstance(toe_angles, dict) or set(toe_angles) - {"left", "right"}:
        raise ValueError("rig_toe_flex_degrees must contain only left/right angles")
    diagnostics["toe_flex_degrees"] = {}
    diagnostics["toe_contact_error_px"] = {}
    for side in ("left", "right"):
        heel_toe = frame["support_foot_geometry"][side]
        heel, toe = point(heel_toe["heel"]), point(heel_toe["toe"])
        foot = directed(parts[f"{side}_foot"], heel, angle(toe - heel))
        tip_part = None
        tip_pose = None
        tip_info = doc.get("toe_overlays", {}).get(side)
        if tip_info is not None:
            tip_part = parts[tip_info["part"]]
            flex = bounded_degrees(toe_angles.get(side, 0),
                                   f"rig_toe_flex_degrees.{side}", 28)
            joint = foot.at(tip_part.pivot)
            tip_pose = Placement(tip_part, joint, foot.radians + flex)
            if heel_toe["contact"] == "toe":
                # The authored toe is the stance contact. Allow the heel to
                # rise as the metatarsal joint bends; do not drag the toe.
                shift = toe - tip_pose.at(tip_part.axis)
                foot = Placement(foot.part, foot.target + shift, foot.radians)
                tip_pose = Placement(tip_part, joint + shift, tip_pose.radians)
            diagnostics["toe_flex_degrees"][side] = math.degrees(flex)
        requested = foot.port("ankle")
        hip = torso.port(f"{side}_hip")
        thigh, shin = parts[f"{side}_thigh"], parts[f"{side}_shin"]
        knee, ankle = fit(f"{side}_leg", hip, requested, f"{side}_knee", thigh.length, shin.length)
        correction = ankle - requested
        placed[thigh.name] = directed(thigh, hip, angle(knee - hip))
        placed[shin.name] = directed(shin, knee, angle(ankle - knee))
        # Use the final foot target; toe contact is exact unless fixed-length
        # IK required a documented reach correction.
        placed[foot.part.name] = Placement(foot.part, foot.target + correction, foot.radians)
        if tip_pose is not None:
            placed[tip_part.name] = Placement(tip_part, tip_pose.target + correction,
                                             tip_pose.radians)
            if heel_toe["contact"] == "toe":
                error = (placed[tip_part.name].at(tip_part.axis) - toe).length
                diagnostics["toe_contact_error_px"][side] = error
        ankle_overlay = doc.get("ankle_overlays", {}).get(side)
        if ankle_overlay is not None:
            # The boot shaft remains aligned with the shin while the cropped
            # shoe/toe piece may roll independently around heel/toe contact.
            shaft = parts[ankle_overlay["part"]]
            placed[shaft.name] = directed(shaft, ankle, angle(knee - ankle))
        diagnostics[f"{side}_boot_reach_correction_px"] = correction.length

    weapon = frame["weapon_geometry"]
    grip, tip = point(weapon["grip"]), point(weapon["tip"])
    weapon_angle = angle(tip - grip)
    diagnostics["wrist_angles_degrees"] = {}
    diagnostics["elbow_cuff_angles_degrees"] = {}
    diagnostics["shoulder_offsets_px"] = {}
    diagnostics["shoulder_overlap_angles_degrees"] = {}
    shoulder_offsets = frame.get("rig_shoulder_offset_px", {})
    if not isinstance(shoulder_offsets, dict) or set(shoulder_offsets) - {"left", "right"}:
        raise ValueError("rig_shoulder_offset_px must contain only left/right offsets")
    right_wrist_offset = bounded_degrees(frame.get("rig_right_hand_offset_degrees", 0),
                                        "rig_right_hand_offset_degrees", 12)
    for side in ("left", "right"):
        mount = torso.port(f"{side}_shoulder")
        offset = point(shoulder_offsets.get(side, (0, 0)))
        if offset.length > 6.001:
            raise ValueError(f"{side} shoulder offset exceeds 6 px")
        c, s = math.cos(lean), math.sin(lean)
        offset = point((c * offset.x - s * offset.y, s * offset.x + c * offset.y))
        shoulder = mount + offset
        diagnostics["shoulder_offsets_px"][side] = list(offset)
        upper, fore, hand = (parts[f"{side}_{name}"] for name in ("upper_arm", "forearm", "hand"))
        if side == "right":
            hand_angle = weapon_angle + math.radians(doc["sword_hand_axis_offset_degrees"]) + right_wrist_offset
            axis = point((math.cos(hand_angle), math.sin(hand_angle)))
            requested = grip - axis * hand.length
        else:
            requested = joints[f"{side}_wrist"]
        elbow, wrist = fit(f"{side}_arm", shoulder, requested, f"{side}_elbow", upper.length, fore.length)
        upper_angle = angle(elbow - shoulder)
        fore_angle = angle(wrist - elbow)
        placed[upper.name] = directed(upper, shoulder, upper_angle)
        placed[fore.name] = directed(fore, elbow, fore_angle)
        overlap = doc.get("shoulder_overlaps", {}).get(side)
        if overlap is not None:
            layer = parts[overlap["part"]]
            rest_angle = angle(layer.axis - layer.pivot) + lean
            heading = rest_angle + overlap["arm_weight"] * angle_delta(upper_angle, rest_angle)
            placed[layer.name] = directed(layer, mount, heading)
            diagnostics["shoulder_overlap_angles_degrees"][side] = math.degrees(heading)
        cuff = doc.get("elbow_cuffs", {}).get(side)
        if cuff is not None:
            cuff_angle = fore_angle + (1 - cuff["forearm_weight"]) * angle_delta(upper_angle, fore_angle)
            layer = parts[cuff["part"]]
            placed[layer.name] = directed(layer, elbow, cuff_angle)
            diagnostics["elbow_cuff_angles_degrees"][side] = math.degrees(cuff_angle)
        hand_request = None
        if side == "left":
            hand_angle = fore_angle
            if "rig_left_hand_angle_degrees" in frame:
                hand_request = frame["rig_left_hand_angle_degrees"]
                # Validate the authored world heading before taking the shortest wrist rotation.
                if isinstance(hand_request, bool) or not isinstance(hand_request, (int, float)) or not math.isfinite(hand_request):
                    raise ValueError("rig_left_hand_angle_degrees must be a finite absolute heading")
                delta = angle_delta(math.radians(hand_request % 360), fore_angle)
                hand_angle += clamp(delta, math.radians(-35), math.radians(35))
        diagnostics["wrist_angles_degrees"][side] = {
            "forearm": math.degrees(fore_angle), "hand": math.degrees(hand_angle),
            "relative_extension": math.degrees(angle_delta(hand_angle, fore_angle)),
            "authored_hand": hand_request,
        }
        if side == "right":
            diagnostics["wrist_angles_degrees"][side]["applied_offset"] = math.degrees(right_wrist_offset)
        placed[hand.name] = directed(hand, wrist, hand_angle)
        if side == "right":
            actual_grip = placed[hand.name].at(hand.axis)
            sword = directed(parts["sword"], actual_grip, weapon_angle)
            placed["sword"] = sword
            diagnostics["sword_grip_error_px"] = (actual_grip - grip).length
            diagnostics["rendered_sword_grip"] = list(actual_grip)
            diagnostics["rendered_sword_tip"] = list(sword.at(sword.part.axis))
        else:
            diagnostics["left_wrist_reach_correction_px"] = (wrist - requested).length
    tassel = doc.get("sword_tassel")
    if tassel is not None:
        sway = clamp(grip_velocity_x * 0.65, math.radians(-18), math.radians(18))
        if "rig_tassel_sway_degrees" in frame:
            sway = bounded_degrees(frame["rig_tassel_sway_degrees"], "rig_tassel_sway_degrees", 18)
        heading = math.pi / 2 + sway
        layer = parts[tassel["part"]]
        placed[layer.name] = directed(layer, placed["sword"].port(tassel["sword_port"]), heading)
        diagnostics["secondary_angles_degrees"][layer.name] = math.degrees(heading)
    return placed, diagnostics

