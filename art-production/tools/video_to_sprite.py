#!/usr/bin/env python3
"""Offline video-frame -> candidate atlas workflow. Never edits Godot Resources.

Requirements: Pillow; ffmpeg for extract; rembg CLI when --rembg is used.
All root motion and contact data are reviewable offline evidence, not gameplay state.
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import re
import shutil
import subprocess
from pathlib import Path

from PIL import Image

ACTIONS = ("idle", "move", "attack", "guard", "hit", "evade",
           "skill", "combo", "defeat")
MAX_ATLAS_SIDE = 16384
MAX_ATLAS_PIXELS = 90_000_000


def fail(message: str) -> None:
    raise ValueError(message)


def prepare_output(path: Path) -> None:
    if path.exists():
        fail(f"Output already exists; choose a new candidate version: {path}")
    path.mkdir(parents=True)


def frame_paths(folder: Path) -> list[Path]:
    if not folder.is_dir():
        fail(f"Missing frames directory: {folder}")
    paths = [p for p in folder.iterdir()
             if p.is_file() and p.suffix.lower() == ".png"]
    paths.sort(key=lambda p: (re.sub(r"\d+", "", p.name),
                              tuple(int(n) for n in re.findall(r"\d+", p.name)),
                              p.name))
    if not paths:
        fail(f"No PNG frames in {folder}")
    if len(paths) > 256:
        fail("One action can contain at most 256 frames")
    return paths


def read_png(path: Path) -> Image.Image:
    with Image.open(path) as source:
        image = source.convert("RGBA")
        extrema = image.getchannel("A").getextrema()
    if extrema[0] == 255:
        fail(f"Frame has no transparent pixels; remove the video background first: {path}")
    if image.getchannel("A").getbbox() is None:
        fail(f"Frame has no visible subject: {path}")
    return image


def csv_index(path: Path, count: int, required: set[str],
              action: str) -> dict[int, dict[str, str]]:
    result: dict[int, dict[str, str]] = {}
    with path.open("r", encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        if not reader.fieldnames or not required.issubset(set(reader.fieldnames)):
            fail(f"{path} needs columns {sorted(required)}")
        for row in reader:
            if row.get("action") and row["action"] != action:
                fail(f"{path}: mismatched action {row['action']}")
            try:
                number = int(row["frame"])
            except (ValueError, TypeError) as exc:
                raise ValueError(f"{path}: invalid frame index") from exc
            if number < 0 or number >= count or number in result:
                fail(f"{path}: invalid or duplicate zero-based frame {number}")
            result[number] = row
    if set(result) != set(range(count)):
        fail(f"{path}: requires exactly one annotation for each frame 0..{count-1}")
    return result


def read_anchors(images: list[Image.Image], names: list[str],
                 action: str, path: Path | None) -> list[dict]:
    rows = (csv_index(path, len(images), {"frame", "x", "y", "reviewed"}, action)
            if path else {})
    result = []
    for index, image in enumerate(images):
        bbox = image.getchannel("A").getbbox()
        assert bbox is not None
        row = rows.get(index)
        if row:
            x, y = int(row["x"]), int(row["y"])
            if not (0 <= x < image.width and 0 <= y < image.height):
                fail(f"{names[index]}: contact point outside the source frame")
            reviewed = row["reviewed"].strip() == "1"
            anchor_type = row.get("anchor_type", "other") or "other"
        else:
            # Visual silhouette lowest pixel is an UNREVIEWED suggestion, not a real planted foot.
            x, y = (bbox[0] + bbox[2] - 1) // 2, bbox[3] - 1
            reviewed, anchor_type = False, "auto_bbox_bottom_unreviewed"
        edge = bbox[0] == 0 or bbox[1] == 0 or bbox[2] == image.width or bbox[3] == image.height
        result.append({"frame": index, "source": names[index],
                       "anchor": [x, y], "anchor_type": anchor_type,
                       "contact_reviewed": reviewed, "source_touches_edge": edge})
    return result


def read_motion(action: str, count: int, path: Path | None) -> list[dict]:
    rows = (csv_index(path, count, {"frame", "root_x", "root_y", "reviewed"}, action)
            if path else {})
    result = []
    for index in range(count):
        row = rows.get(index)
        if row:
            x, y = float(row["root_x"]), float(row["root_y"])
            if not math.isfinite(x) or not math.isfinite(y):
                fail(f"Nonfinite root motion for frame {index}")
            reviewed = row["reviewed"].strip() == "1"
        else:
            x, y, reviewed = 0.0, 0.0, False
        result.append({"root_motion": [x, y], "motion_reviewed": reviewed})
    return result


def layout(images: list[Image.Image], anchors: list[tuple[int, int]],
           columns: int, margin: int) -> tuple[Image.Image, list[Image.Image], list[int]]:
    if not images or len(images) != len(anchors):
        fail("Frame/anchor count mismatch")
    if not 1 <= columns <= 64 or not 0 <= margin <= 512:
        fail("Columns must be 1..64; margin must be 0..512")
    left = top = right = bottom = 0
    for image, (ax, ay) in zip(images, anchors):
        bbox = image.getchannel("A").getbbox()
        if bbox is None:
            fail("Blank animation frame")
        left = max(left, ax - bbox[0])
        top = max(top, ay - bbox[1])
        right = max(right, bbox[2] - ax)
        bottom = max(bottom, bbox[3] - ay)
    width, height = left + right + 2 * margin, top + bottom + 2 * margin
    rows = math.ceil(len(images) / columns)
    if width * columns > MAX_ATLAS_SIDE or height * rows > MAX_ATLAS_SIDE or \
            width * height * columns * rows > MAX_ATLAS_PIXELS:
        fail("Atlas exceeds 16384px per axis or 90M pixels; split the batch")
    target = (margin + left, margin + top)
    atlas = Image.new("RGBA", (width * columns, height * rows))
    aligned = []
    for index, (image, (ax, ay)) in enumerate(zip(images, anchors)):
        bbox = image.getchannel("A").getbbox()
        assert bbox is not None
        frame = Image.new("RGBA", (width, height))
        patch = image.crop(bbox)
        frame.alpha_composite(patch, (target[0] + bbox[0] - ax,
                                      target[1] + bbox[1] - ay))
        check = frame.getchannel("A").getbbox()
        assert check is not None
        assert check[0] >= margin and check[1] >= margin
        assert check[2] <= width - margin and check[3] <= height - margin
        atlas.alpha_composite(frame, ((index % columns) * width,
                                       (index // columns) * height))
        aligned.append(frame)
    return atlas, aligned, [target[0], target[1]]


def write_json(path: Path, obj: dict) -> None:
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def report_for(frames: list[dict], motion_action: bool = False) -> dict:
    key = lambda f: f.get("action", "") + "#" + str(f["frame"]) if f.get("action") else f["frame"]
    pending_contacts = [key(f) for f in frames if not f["contact_reviewed"]]
    pending_motion = [key(f) for f in frames if not f["motion_reviewed"] and
                      (motion_action or f.get("action") in ("attack", "evade", "skill", "combo"))]
    clipped = [key(f) for f in frames if f["source_touches_edge"]]
    return {
        "status": "candidate",
        "manual_review_required": True,
        "unreviewed_contacts": pending_contacts,
        "unreviewed_root_motion": pending_motion,
        "source_edge_warnings": clipped,
        "notes": [
            "A bbox-bottom guess is not a physically verified support foot.",
            "Source boundary contact may mean a cut sword, foot, or robe; pixels cannot be recovered.",
            "Root motion is offline source-pixel data; the Godot runtime does not consume this JSON.",
            "Inspect identity, one-handed weapon, transitions, loop seam, foot skating and GUI before in-use."
        ],
    }


def extract(args: argparse.Namespace) -> None:
    video, output = Path(args.video), Path(args.output)
    if not video.is_file():
        fail(f"Missing video: {video}")
    if not 1 <= args.fps <= 60:
        fail("fps must be in 1..60")
    if shutil.which("ffmpeg") is None:
        fail("ffmpeg executable is required")
    if args.rembg and shutil.which("rembg") is None:
        fail("rembg CLI is required for --rembg")
    prepare_output(output)
    raw = output / "source_frames"
    raw.mkdir()
    command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin",
               "-n", "-i", str(video), "-vf", f"fps={args.fps:g}",
               "-start_number", "0", str(raw / "frame_%04d.png")]
    subprocess.run(command, check=True)
    frame_paths(raw)
    if args.rembg:
        subprocess.run(["rembg", "p", str(raw), str(output / "alpha_frames")],
                       check=True)
    print(f"Extracted to {raw}; remove background if needed, then annotate and pack.")


def pack(args: argparse.Namespace) -> None:
    if args.action not in ACTIONS:
        fail(f"Unknown runtime action: {args.action}")
    if not 1 <= args.fps <= 60:
        fail("fps must be in 1..60")
    if args.loop and args.action not in ("idle", "move"):
        fail("Only idle and move may loop in WuxiaActorAnimationClip")
    paths = frame_paths(Path(args.frames))
    images = [read_png(p) for p in paths]
    frames = read_anchors(images, [p.name for p in paths], args.action,
                          Path(args.anchors) if args.anchors else None)
    motions = read_motion(args.action, len(images),
                          Path(args.motion) if args.motion else None)
    for frame, motion in zip(frames, motions):
        frame.update(motion)
    atlas, aligned, target = layout(
        images, [tuple(f["anchor"]) for f in frames], args.columns, args.margin)
    output = Path(args.output)
    prepare_output(output)
    aligned_dir = output / "aligned"
    aligned_dir.mkdir()
    for index, frame in enumerate(aligned):
        frame.save(aligned_dir / f"frame_{index:04d}.png")
    atlas.save(output / "atlas.png")
    aligned[0].save(output / "preview.gif", save_all=True,
                    append_images=aligned[1:], duration=round(1000 / args.fps),
                    loop=0, disposal=2, optimize=False)
    with (output / "foot_annotations.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(("action", "frame", "x", "y", "reviewed", "source_edge_flag", "anchor_type"))
        for f in frames:
            writer.writerow((args.action, f["frame"], *f["anchor"],
                             int(f["contact_reviewed"]), int(f["source_touches_edge"]),
                             f["anchor_type"]))
    with (output / "root_motion.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(("action", "frame", "root_x", "root_y", "reviewed"))
        for f in frames:
            writer.writerow((args.action, f["frame"], *f["root_motion"],
                             int(f["motion_reviewed"])))
    contract = {"schema": "video_sprite_candidate_v1", "status": "candidate",
                "kind": "action", "action": args.action, "fps": args.fps,
                "loop": args.loop, "source_directory": str(args.frames),
                "atlas_columns": args.columns,
                "atlas_rows": math.ceil(len(frames) / args.columns),
                "cell_size": list(aligned[0].size), "contact_target": target,
                "frames": frames}
    write_json(output / "frame_contract.json", contract)
    write_json(output / "qa_report.json",
               report_for(frames, args.action in ("attack", "evade", "skill", "combo")))
    print(f"Candidate {args.action}: {len(frames)} frames, cell {aligned[0].size}, {output}")


def assemble(args: argparse.Namespace) -> None:
    if not args.inputs:
        fail("Supply at least one --input directory")
    images: list[Image.Image] = []
    anchors: list[tuple[int, int]] = []
    all_frames: list[dict] = []
    clips: dict[str, dict] = {}
    for item in args.inputs:
        folder = Path(item)
        contract = json.loads((folder / "frame_contract.json").read_text(encoding="utf-8"))
        action = contract["action"]
        if contract.get("schema") != "video_sprite_candidate_v1" or \
                contract.get("kind") != "action" or action not in ACTIONS or action in clips:
            fail(f"Invalid or duplicate action candidate: {folder}")
        paths = frame_paths(folder / "aligned")
        if len(paths) != len(contract["frames"]):
            fail(f"{folder}: frame metadata mismatch")
        start = len(images)
        for path, frame in zip(paths, contract["frames"]):
            images.append(read_png(path))
            anchors.append(tuple(contract["contact_target"]))
            all_frames.append({**frame, "action": action, "atlas_index": len(all_frames)})
        clips[action] = {"frames": list(range(start, len(images))),
                         "fps": contract["fps"], "loop": contract["loop"]}
    if len(images) > 64 * 64:
        fail("WuxiaActorAnimationProfile allows at most 4096 atlas cells")
    missing = [action for action in ACTIONS if action not in clips]
    if args.require_complete and missing:
        fail(f"Nine runtime actions required; missing {missing}")
    atlas, aligned, target = layout(images, anchors, args.columns, args.margin)
    output = Path(args.output)
    prepare_output(output)
    atlas.save(output / "atlas.png")
    contract = {"schema": "video_sprite_candidate_v1", "kind": "combined_atlas",
                "status": "candidate", "atlas_columns": args.columns,
                "atlas_rows": math.ceil(len(images) / args.columns),
                "cell_size": list(aligned[0].size), "contact_target": target,
                "actions": clips, "missing_runtime_actions": missing,
                "frames": all_frames}
    write_json(output / "frame_contract.json", contract)
    write_json(output / "qa_report.json", report_for(all_frames))
    print(f"Combined {len(images)} frames, {len(clips)} actions; missing {missing}.")
    print("Copy atlas/clip mappings to a native .tres via the existing Godot importer; no runtime binding changed.")


def make_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    ex = commands.add_parser("extract", help="Decode MP4 with FFmpeg; optionally batch-rembg")
    ex.add_argument("--video", required=True)
    ex.add_argument("--output", required=True)
    ex.add_argument("--fps", type=float, default=12)
    ex.add_argument("--rembg", action="store_true")
    ex.set_defaults(func=extract)
    pa = commands.add_parser("pack", help="Align one transparent action and export candidate atlas")
    pa.add_argument("--frames", required=True)
    pa.add_argument("--output", required=True)
    pa.add_argument("--action", required=True, choices=ACTIONS)
    pa.add_argument("--fps", type=float, default=12)
    pa.add_argument("--loop", action="store_true")
    pa.add_argument("--anchors", help="Existing sprite-anchor-editor foot_annotations.csv (zero-based)")
    pa.add_argument("--motion", help="Optional manually reviewed root_motion.csv (source-pixel offsets)")
    pa.add_argument("--columns", type=int, default=8)
    pa.add_argument("--margin", type=int, default=24)
    pa.set_defaults(func=pack)
    co = commands.add_parser("assemble", help="Combine action packs into a Godot-compatible uniform atlas")
    co.add_argument("--input", dest="inputs", action="append", required=True)
    co.add_argument("--output", required=True)
    co.add_argument("--columns", type=int, default=8)
    co.add_argument("--margin", type=int, default=24)
    co.add_argument("--require-complete", action="store_true")
    co.set_defaults(func=assemble)
    return parser


def main() -> None:
    args = make_parser().parse_args()
    try:
        args.func(args)
    except (ValueError, OSError, subprocess.CalledProcessError, KeyError) as exc:
        raise SystemExit(f"Video-to-sprite ERROR: {exc}") from exc


if __name__ == "__main__":
    main()
