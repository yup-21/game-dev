"""Build a small, reproducible shoulder and wrist variant of the bundled walk."""
import argparse
from copy import deepcopy
import json
import math
from pathlib import Path

def read(path):
    return json.loads(path.read_text("utf8"))


def save(path, doc):
    path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", "utf8")


def elbow_for(a, b, previous, lengths):
    dx, dy = b[0] - a[0], b[1] - a[1]
    reach = math.hypot(dx, dy)
    first, second = lengths
    if not abs(first - second) + .1 <= reach <= first + second - .1:
        raise ValueError("Shoulder/wrist demo exceeded fixed link reach")
    ux, uy = dx / reach, dy / reach
    axial = (reach**2 + first**2 - second**2) / (2 * reach)
    across = math.sqrt(first**2 - axial**2)
    signed = -(previous[0] - a[0]) * uy + (previous[1] - a[1]) * ux
    across = math.copysign(across, signed)
    return [a[0] + axial * ux - across * uy, a[1] + axial * uy + across * ux]


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--project", type=Path, required=True)
    cli.add_argument("--patch", type=Path, required=True)
    args = cli.parse_args()
    base = args.project.resolve(strict=True).parent
    project = read(args.project)
    parts_output = base / "parts_with_shoulders.json"
    motion_output = base / "walk_shoulder_wrist.json"
    if parts_output.exists() or motion_output.exists():
        cli.error("替代部件或动作文件已存在，请先为试样使用新的项目副本。")
    original = read(base / project["parts"])
    patch = read(args.patch)
    if patch["atlas_sha256"] != original["generated_atlas"]["sha256"]:
        cli.error("肩部叠片 UV 只适用其标注的图集，不能用于其他绘制稿。")
    art = deepcopy(original)
    for part in art["parts"]:
        if polygon := patch["replace_part_polygons_by_name"].get(part["name"]):
            part["polygon"] = polygon
    art["parts"].extend(patch["append_parts"])
    art.update(patch["add_top_level_fields"])
    lengths = {p["name"]: p["length_px"] for p in art["parts"]}
    motion = read(base / project["motion_dir"] / "walk/motion.json")
    motion.update(name="gu_qingshuang_walk_shoulder_wrist_demo",
                  source_kind="arm_revision_example", pose_control=False)
    for frame in motion["frames"]:
        phase = math.tau * frame["time_ms"] / motion["duration_ms"]
        tilt = math.radians(frame["rig_torso_lean_degrees"])
        c, s = math.cos(tilt), math.sin(tilt)
        joints = frame["authored_keypoints_coco18"]
        left_x = 2.4 * math.sin(phase - .38)
        offsets = {"left": [left_x, .9 * math.cos(phase - .38)],
                   "right": [-.75 * left_x, -.7 * math.cos(phase - .38)]}
        wrist = 7 * math.sin(phase - .95)
        frame["rig_shoulder_offset_px"] = offsets
        frame["rig_right_hand_offset_degrees"] = wrist
        blade = frame["weapon_geometry"]
        angle = math.atan2(blade["tip"][1] - blade["grip"][1], blade["tip"][0] - blade["grip"][0])
        grip_axis = angle + math.radians(art["sword_hand_axis_offset_degrees"] + wrist)
        frame["rig_left_hand_angle_degrees"] += 5 * math.sin(phase - 1.05)
        for side in ("left", "right"):
            dx, dy = offsets[side]
            root, elbow, hand = (joints[f"{side}_{key}"] for key in ("shoulder", "elbow", "wrist"))
            root = [root[0] + c * dx - s * dy, root[1] + s * dx + c * dy]
            if side == "left":
                hand = [hand[0] + 3.5 * math.sin(phase - .62), hand[1]]
            else:
                hand = [blade["grip"][0] - math.cos(grip_axis) * lengths["right_hand"],
                        blade["grip"][1] - math.sin(grip_axis) * lengths["right_hand"]]
            middle = elbow_for(root, hand, elbow, (lengths[f"{side}_upper_arm"], lengths[f"{side}_forearm"]))
            for key, value in zip(("shoulder", "elbow", "wrist"), (root, middle, hand)):
                joints[f"{side}_{key}"] = [round(v, 6) for v in value]
        frame.pop("pose", None)
        frame.pop("pose_keypoints", None)
        frame.pop("pose_plan_joints_norm", None)
        frame["pose_control"] = False
    save(parts_output, art)
    save(motion_output, motion)


if __name__ == "__main__":
    main()
