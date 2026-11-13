"""Build a renderer project from reviewed rig parts and authored motion targets."""
import argparse
from hashlib import sha256
import json
import math
from pathlib import Path
import shutil
import sys
from tempfile import TemporaryDirectory

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_workflow import ID, digest, save, validate_parts


CHAINS = [
    ("nose", "neck", "left_hip", "right_hip", "neck"),
    *((f"{side}_shoulder", f"{side}_elbow", f"{side}_wrist") for side in ("left", "right")),
    *((f"{side}_hip", f"{side}_knee", f"{side}_ankle") for side in ("left", "right")),
    ("left_shoulder", "neck", "right_shoulder"),
]


def validate_point(value, label):
    if (not isinstance(value, list) or len(value) != 2
            or any(type(n) not in (int, float) or not math.isfinite(n) for n in value)):
        raise ValueError(f"{label} 需要有效的二维坐标")


def load_actions(path):
    raw = path.read_bytes()
    doc = json.loads(raw.decode("utf-8-sig"))
    canvas, origin = doc["canvas"], doc["logical_origin"]
    validate_point(origin, "logical_origin")
    if (canvas not in ([328, 256], [384, 288]) or
            not all(type(n) is int and 0 <= n < size for n, size in zip(origin, canvas))):
        raise ValueError(f"{path} 需要原生画布和统一整数根点")
    groups = doc.get("action_groups")
    if not groups:
        groups = [doc]
    frames = doc["frames"]
    if not frames or doc["frame_count"] != len(frames):
        raise ValueError(f"{path} 的动作总帧数不匹配")
    offset = elapsed = 0
    seen = set()
    for group in groups:
        action, count = group["action_id"], group["frame_count"]
        if not ID.fullmatch(action) or action in seen or type(count) is not int or count < 2:
            raise ValueError(f"{path} 的动作 ID 重复、不合法或不足两帧：{action}")
        seen.add(action)
        batch = frames[offset:offset + count]
        if len(batch) != count or type(group["loop"]) is not bool:
            raise ValueError(f"{action} 的分组帧数或循环字段不匹配")
        timing = 0
        normalized = []
        frame_ids = set()
        for index, frame in enumerate(batch):
            fid, duration = frame["id"], frame["duration_ms"]
            if (not isinstance(fid, str) or not fid or fid in frame_ids
                    or frame.get("action_id", action) != action
                    or frame.get("facing", "right") != "right"
                    or frame.get("logical_origin", origin) != origin
                    or frame.get("loop", group["loop"]) != group["loop"]
                    or frame.get("end_contract", group.get("end_contract")) != group.get("end_contract")
                    or frame.get("action_frame_index", index) != index
                    or frame.get("action_time_ms", timing) != timing
                    or frame["time_ms"] != elapsed + timing
                    or type(duration) is not int or duration <= 0):
                raise ValueError(f"{action} 第 {index + 1} 帧的分组、朝向或时序不匹配")
            frame_ids.add(fid)
            joints = frame["authored_keypoints_coco18"]
            for joint in {joint for chain in CHAINS for joint in chain}:
                validate_point(joints[joint], f"{fid}/{joint}")
            for side in ("left", "right"):
                foot = frame["support_foot_geometry"][side]
                for marker in ("heel", "toe"):
                    validate_point(foot[marker], f"{fid}/{side}/{marker}")
                if foot["heel"] == foot["toe"]:
                    raise ValueError(f"{fid} 的 {side} 鞋跟和鞋尖须分开")
            weapon = frame["weapon_geometry"]
            for marker in ("grip", "tip"):
                validate_point(weapon[marker], f"{fid}/weapon/{marker}")
            if weapon["grip"] == weapon["tip"]:
                raise ValueError(f"{fid} 的握点和剑尖须分开")
            normalized.append(dict(frame, action_id=action, frame_index=index,
                                   action_frame_index=index, time_ms=timing, action_time_ms=timing))
            timing += duration
        if timing != group["duration_ms"]:
            raise ValueError(f"{action} 的总时长与帧时长不匹配")
        result = dict(doc)
        for field in ("action_groups", "action_count", "continuous_animation", "timeline_note"):
            result.pop(field, None)
        result.update(action_id=action, name=group.get("label") or doc.get("name") or action,
                      duration_ms=timing, frame_count=count, loop=group["loop"],
                      end_contract=group.get("end_contract"), frames=normalized,
                      source_motion_sha256=sha256(raw).hexdigest())
        if "loop_frame_ids" in group:
            result["loop_frame_ids"] = group["loop_frame_ids"]
        offset += count
        elapsed += timing
        yield action, result
    if offset != len(frames) or elapsed != doc["duration_ms"]:
        raise ValueError(f"{path} 的动作分组未完整覆盖帧序或时序")


def draw_preview(path, motions):
    cell_width, cell_height = 154, 132
    columns = 6
    rows = sum(math.ceil(len(motion["frames"]) / columns) for motion in motions.values())
    image = Image.new("RGB", (columns * cell_width, rows * cell_height), "#202733")
    draw = ImageDraw.Draw(image)
    row = 0
    for action, motion in motions.items():
        width, height = motion["canvas"]
        scale = min((cell_width - 12) / width, (cell_height - 28) / height)
        for index, frame in enumerate(motion["frames"]):
            x = (index % columns) * cell_width + 6
            y = (row + index // columns) * cell_height + 19

            def xy(point):
                return x + scale * point[0], y + scale * point[1]

            draw.text((x, y - 16), f"{action} {index + 1} · {frame['time_ms']}ms", fill="#e8edf4")
            ox, oy = xy(motion["logical_origin"])
            draw.line((x, oy, x + width * scale, oy), fill="#596579")
            draw.ellipse((ox - 2, oy - 2, ox + 2, oy + 2), fill="#dee8f3")
            joints = frame["authored_keypoints_coco18"]
            for chain in CHAINS:
                draw.line([xy(joints[name]) for name in chain], fill="#77dce7", width=2)
            for side in ("left", "right"):
                foot = frame["support_foot_geometry"][side]
                draw.line([xy(foot["heel"]), xy(foot["toe"])], fill="#7fe0a4", width=2)
            weapon = frame["weapon_geometry"]
            draw.line([xy(weapon["grip"]), xy(weapon["tip"])], fill="#ffc171", width=2)
        row += math.ceil(len(motion["frames"]) / columns)
    image.save(path)


def build(parts, motion, output, character_id, display_name, action_filter):
    if not ID.fullmatch(character_id) or not display_name.strip():
        raise ValueError("请输入小写角色 ID 和显示名称")
    parts, motion = parts.resolve(strict=True), motion.resolve(strict=True)
    output = output.resolve()
    if output.exists():
        raise ValueError(f"输出工程已存在：{output}")
    sources = sorted(motion.glob("*/motion.json")) if motion.is_dir() else [motion]
    motions = {}
    for source in sources:
        for action, data in load_actions(source):
            if action in motions:
                raise ValueError(f"存在多个 {action} 动作源")
            motions[action] = data
    selected = list(dict.fromkeys(action_filter or motions))
    if not selected or set(selected) - motions.keys():
        raise ValueError("没有匹配的动作；请选择有效动作 ID")
    motions = {action: motions[action] for action in selected}
    if len({(tuple(m["canvas"]), tuple(m["logical_origin"])) for m in motions.values()}) != 1:
        raise ValueError("同一角色的动作必须共用画布和根点")
    hashes = validate_parts(parts.parent, parts)
    output.parent.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=output.parent) as temp:
        staged = Path(temp) / "project"
        staged.mkdir()
        for source, expected in hashes.items():
            relative = source.relative_to(parts.parent)
            if relative.parts[0] in {"project.json", "report.json", "skeleton_preview.png", "motion"}:
                raise ValueError(f"部件文件占用了工程保留路径：{relative}")
            target = staged / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            if digest(target) != expected:
                raise ValueError(f"复制期间部件文件发生变化：{source}")
        for action, data in motions.items():
            target = staged / "motion" / action / "motion.json"
            target.parent.mkdir(parents=True)
            save(target, data)
        save(staged / "project.json", {
            "schema_version": 1, "character_id": character_id, "display_name": display_name,
            "parts": parts.name, "motion_dir": "motion",
            "actions": {action: data["name"] for action, data in motions.items()},
        })
        save(staged / "report.json", {
            "status": "candidate", "preview_kind": "authored_joint_targets",
            "parts_sha256": hashes[parts],
            "frame_count": sum(data["frame_count"] for data in motions.values()),
            "actions": {action: {key: data[key] for key in ("frame_count", "duration_ms", "loop", "source_motion_sha256")}
                        for action, data in motions.items()},
        })
        draw_preview(staged / "skeleton_preview.png", motions)
        staged.rename(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for arg in ("parts", "motion", "output"):
        parser.add_argument(f"--{arg}", type=Path, required=True)
    parser.add_argument("--character-id", required=True)
    parser.add_argument("--display-name", required=True)
    parser.add_argument("--action", action="append")
    args = parser.parse_args()
    try:
        build(args.parts, args.motion, args.output, args.character_id, args.display_name, args.action)
    except (OSError, KeyError, TypeError, ValueError) as error:
        parser.exit(1, f"无法生成 2D 骨架工程：{error}\n")
