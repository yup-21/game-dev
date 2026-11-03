#!/usr/bin/env python3
"""Build v07 motion-interpolation candidates from PR #108's v06 atlases.

The original keyframes are copied losslessly. New frames use bidirectional
optical flow and ALWAYS require visual review; they are not hand-drawn poses.
No native .tres or in-use resource is changed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

from batch_anchor_align import ACTORS, ACTIONS, FPS, OUTPUT_DIR

COLS = 8
EXTRA = 32
MIN_MARGIN = 24
MAX_FLOW = 18.0


def rgba_from_cell(atlas: Image.Image, index: int, size: tuple[int, int]) -> np.ndarray:
    width, height = size
    tile = atlas.crop((
        index % 6 * width, index // 6 * height,
        (index % 6 + 1) * width, (index // 6 + 1) * height,
    ))
    result = np.zeros((height + 2 * EXTRA, width + 2 * EXTRA, 4), dtype=np.uint8)
    result[EXTRA:EXTRA + height, EXTRA:EXTRA + width] = np.asarray(tile)
    return result


def flow_gray(rgba: np.ndarray) -> np.ndarray:
    alpha = rgba[:, :, 3:4].astype(np.float32) / 255.0
    rgb = rgba[:, :, :3].astype(np.float32) * alpha + 30.0 * (1.0 - alpha)
    return cv2.cvtColor(np.uint8(np.clip(rgb, 0, 255)), cv2.COLOR_RGB2GRAY)


def tween_half(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """One optical-flow guess midway between two existing keyed poses."""
    if a.shape != b.shape or a.dtype != np.uint8 or b.dtype != np.uint8:
        raise ValueError("Interpolation requires equal-size uint8 RGBA cells")
    if np.array_equal(a, b):
        return a.copy()

    gray_a, gray_b = flow_gray(a), flow_gray(b)
    args = (None, 0.5, 3, 21, 3, 5, 1.2, 0)
    forward = cv2.calcOpticalFlowFarneback(gray_a, gray_b, *args)
    backward = cv2.calcOpticalFlowFarneback(gray_b, gray_a, *args)
    np.clip(forward, -MAX_FLOW, MAX_FLOW, out=forward)
    np.clip(backward, -MAX_FLOW, MAX_FLOW, out=backward)
    yy, xx = np.mgrid[:a.shape[0], :a.shape[1]].astype(np.float32)
    aw = cv2.remap(a, xx - forward[:, :, 0] * 0.5,
                   yy - forward[:, :, 1] * 0.5,
                   cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT,
                   borderValue=(0, 0, 0, 0)).astype(np.float32)
    bw = cv2.remap(b, xx - backward[:, :, 0] * 0.5,
                   yy - backward[:, :, 1] * 0.5,
                   cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT,
                   borderValue=(0, 0, 0, 0)).astype(np.float32)
    aa = aw[:, :, 3:4] / 255.0
    ba = bw[:, :, 3:4] / 255.0
    opacity = 0.5 * (aa + ba)
    premult = 0.5 * (aw[:, :, :3] * aa + bw[:, :, :3] * ba)
    rgb = np.divide(premult, opacity,
                    out=np.zeros_like(premult), where=opacity > 1e-6)
    return np.concatenate((
        np.uint8(np.clip(np.rint(rgb), 0, 255)),
        np.uint8(np.clip(np.rint(opacity * 255), 0, 255)),
    ), axis=2)


def alpha_margin(frame: np.ndarray) -> int:
    ys, xs = np.nonzero(frame[:, :, 3])
    if not len(xs):
        raise ValueError("Empty animation frame")
    height, width = frame.shape[:2]
    return int(min(xs.min(), ys.min(), width - 1 - xs.max(),
                   height - 1 - ys.max()))


def silhouette_iou(a: np.ndarray, b: np.ndarray) -> float:
    ma, mb = a[:, :, 3] >= 96, b[:, :, 3] >= 96
    union = np.logical_or(ma, mb).sum()
    return float(np.logical_and(ma, mb).sum() / union) if union else 1.0


def compose_action(
    action: str, ids: list[int], keyed: dict[int, np.ndarray],
    v06_by_index: dict[int, dict],
) -> tuple[list[np.ndarray], list[dict]]:
    if not ids:
        raise ValueError(f"{action}: no source keys")
    frames: list[np.ndarray] = []
    entries: list[dict] = []
    is_loop = action == "move"
    for offset, index in enumerate(ids):
        frames.append(keyed[index].copy())
        entries.append({
            "kind": "original_key", "source_index": index,
            "reviewed_contact": bool(v06_by_index[index]["reviewed"]),
            "needs_visual_review": not bool(v06_by_index[index]["reviewed"]),
        })
        next_offset = (offset + 1) % len(ids)
        if offset == len(ids) - 1 and not is_loop:
            continue
        neighbor = ids[next_offset]
        halfway = tween_half(keyed[index], keyed[neighbor])
        iou = silhouette_iou(keyed[index], keyed[neighbor])
        detached = bool(v06_by_index[index]["detached_islands"] or
                        v06_by_index[neighbor]["detached_islands"])
        frames.append(halfway)
        entries.append({
            "kind": "optical_flow_candidate",
            "between": [index, neighbor], "fraction": 0.5,
            "silhouette_iou": round(iou, 4),
            "detached_fragment_source": detached,
            "manual_redraw_priority": bool(detached or iou < 0.6),
            "reviewed_contact": False, "needs_visual_review": True,
        })
    return frames, entries


def preview_gif(frames: list[np.ndarray], path: Path, fps: int, loop: bool):
    previews = []
    for frame in frames:
        pic = Image.fromarray(frame, "RGBA")
        base = Image.new("RGBA", pic.size, (33, 39, 47, 255))
        base.alpha_composite(pic)
        previews.append(base.convert("RGB"))
    options = dict(save_all=True, append_images=previews[1:],
                   duration=max(20, round(1000 / fps)),
                   disposal=2, optimize=False)
    if loop:
        options["loop"] = 0
    previews[0].save(path, format="GIF", **options)


def process_actor(actor: str, input_root: Path, output_root: Path) -> dict:
    if actor not in ACTORS:
        raise ValueError(f"Unknown actor {actor}")
    source_folder = input_root / actor
    source_path = source_folder / f"sprite_{actor}_atlas_anchor_v06.png"
    review = json.loads((source_folder / "frame_review.json").read_text(encoding="utf-8"))
    if review["actor"] != actor or review["atlas"] != source_path.name:
        raise ValueError(f"{actor}: v06 review metadata disagrees with atlas")
    size = tuple(review["cell_size"])
    if len(size) != 2 or min(size) < 1:
        raise ValueError(f"{actor}: invalid v06 cell geometry")
    with Image.open(source_path) as file:
        source = file.convert("RGBA")
    if source.size != (6 * size[0], 4 * size[1]):
        raise ValueError(f"{actor}: v06 6x4 source size mismatch")
    by_index = {int(item["index"]): item for item in review["frames"]}
    if len(by_index) != 24:
        raise ValueError(f"{actor}: expected 24 v06 source slots")
    keys = {i: rgba_from_cell(source, i, size) for i in range(24)}

    output_frames: list[np.ndarray] = []
    action_maps: dict[str, dict] = {}
    all_meta: list[dict] = []
    result_folder = output_root / actor
    result_folder.mkdir(parents=True, exist_ok=True)
    for action, original_ids in ACTIONS.items():
        ids = list(original_ids)
        frames, entries = compose_action(action, ids, keys, by_index)
        first = len(output_frames)
        target_fps = max(FPS[action], round(FPS[action] * len(frames) / len(ids)))
        clip = list(range(first, first + len(frames)))
        action_maps[action] = {
            "frames": clip, "original_keys": ids,
            "fps_preview": target_fps, "loop": action in ("idle", "move"),
            "requires_authoring_review": any(e["needs_visual_review"] for e in entries),
        }
        for index, (frame, data) in enumerate(zip(frames, entries)):
            margin = alpha_margin(frame)
            if margin < MIN_MARGIN:
                raise ValueError(f"{actor}:{action}:{index}: margin {margin} < {MIN_MARGIN}")
            all_meta.append(dict(
                index=first + index, action=action, action_frame=index,
                min_margin=margin, **data
            ))
        output_frames.extend(frames)
        preview_gif(frames, result_folder / f"preview_{actor}_{action}_v07.gif",
                    target_fps, action_maps[action]["loop"])

    width, height = keys[0].shape[1], keys[0].shape[0]
    rows = math.ceil(len(output_frames) / COLS)
    atlas = Image.new("RGBA", (COLS * width, rows * height))
    for index, frame in enumerate(output_frames):
        atlas.alpha_composite(Image.fromarray(frame, "RGBA"),
                              ((index % COLS) * width, (index // COLS) * height))
    png = f"sprite_{actor}_atlas_inbetweens_v07.png"
    atlas.save(result_folder / png, "PNG", optimize=True)
    flags = [x["index"] for x in all_meta if x.get("manual_redraw_priority")]
    report = {
        "actor": actor, "status": "candidate / unreviewed",
        "source_v06_atlas": source_path.name,
        "source_v06_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
        "atlas": png, "atlas_columns": COLS, "atlas_rows": rows,
        "cell_size": [width, height], "total_frames": len(output_frames),
        "original_key_count": sum(len(v) for v in ACTIONS.values()),
        "generated_inbetween_count": len(output_frames) - sum(len(v) for v in ACTIONS.values()),
        "actions": action_maps, "frames": all_meta,
        "priority_redraw_indices": flags,
        "limitations": [
            "Interpolated poses use optical flow and are NOT new hand-drawn animation art",
            "All in-between frames require manual visual review; possible ghost swords/limbs",
            "The original idle has one pose; no idle breathing frames were invented",
            "Root motion and planted feet are NOT certified by geometry alone",
            "The v06 disconnected-fragment warnings are retained, not erased",
            "No in-use atlas or native Godot animation profile is changed",
        ],
    }
    (result_folder / "frame_review_v07.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"{actor}: {len(output_frames)} frames, "
          f"{report['generated_inbetween_count']} in-betweens, "
          f"{len(flags)} priority-redraw candidates")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    select = parser.add_mutually_exclusive_group(required=True)
    select.add_argument("--all", action="store_true")
    select.add_argument("--actor", choices=ACTORS)
    parser.add_argument("--input", type=Path, default=OUTPUT_DIR)
    parser.add_argument("--output", type=Path, default=OUTPUT_DIR)
    args = parser.parse_args()
    for actor in (ACTORS if args.all else (args.actor,)):
        process_actor(actor, args.input, args.output)
    print("V07_FLOW_CANDIDATES_GENERATED; visual review pending; in-use unchanged")


if __name__ == "__main__":
    main()
