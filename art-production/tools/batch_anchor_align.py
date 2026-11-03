#!/usr/bin/env python3
"""Batch candidate-only, anchor-aligned sprite atlas builder for five combat actors.

    python -m pip install Pillow
    python art-production/tools/batch_anchor_align.py --all
    python art-production/tools/batch_anchor_align.py --all --annotations art-production/candidates/2026-11-03/actor_anchors

No per-frame resize, removal of image content, invented tween frames or runtime writes.
Estimated anchors are NEVER marked reviewed. Review the CSV, then rerun with
--annotations ... --require-reviewed before a candidate can be considered for approval.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from collections import OrderedDict
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ACTORS = (
    "pursuer_captain",
    "gu_qingshuang",
    "green_wanderer",
    "black_blade",
    "night_assassin",
)
ACTIONS = OrderedDict((
    ("idle", (1,)), ("move", (2, 3, 4, 5)),
    ("attack", (6, 7, 8)), ("guard", (9, 10)),
    ("hit", (11, 12)), ("evade", (13, 14, 15)),
    ("skill", (16, 17, 18)), ("combo", (19, 20, 21)),
    ("defeat", (22, 23)),
))
FPS = {"idle": 9, "move": 12, "attack": 14, "guard": 10, "hit": 12,
       "evade": 14, "skill": 14, "combo": 15, "defeat": 10}
SOURCE_DIR = ROOT / "art-production/candidates/2026-11-01"
OUTPUT_DIR = ROOT / "art-production/candidates/2026-11-03"
GRID_COLS, GRID_ROWS = 6, 4
ALPHA_THRESHOLD = 1
DEFAULT_PADDING = 24


@dataclass(frozen=True)
class Anchor:
    x: int
    y: int
    kind: str = "estimated"
    reviewed: bool = False
    root_dx: int = 0
    root_dy: int = 0


def action_for(index: int) -> tuple[str, int]:
    for action, ids in ACTIONS.items():
        if index in ids:
            return action, ids.index(index)
    if index == 0:
        return "unused", 0  # alternate view; never loop it as idle
    raise ValueError(f"Frame index not in animation profile: {index}")


def source_path(actor: str) -> Path:
    return SOURCE_DIR / actor / f"sprite_{actor}_atlas_aligned_v03.png"


def image_bbox(frame: Image.Image) -> tuple[int, int, int, int]:
    mask = frame.getchannel("A").point(
        lambda alpha: 255 if alpha >= ALPHA_THRESHOLD else 0
    )
    result = mask.getbbox()
    if result is None:
        raise ValueError("Blank source frame cannot be packed")
    return result


def split_frames(atlas: Image.Image) -> list[Image.Image]:
    if atlas.width % GRID_COLS or atlas.height % GRID_ROWS:
        raise ValueError("Source atlas dimensions do not divide into 6 x 4")
    width, height = atlas.width // GRID_COLS, atlas.height // GRID_ROWS
    if width < 1 or height < 1:
        raise ValueError("Empty source atlas")
    return [
        atlas.crop(((i % GRID_COLS) * width, (i // GRID_COLS) * height,
                    (i % GRID_COLS + 1) * width, (i // GRID_COLS + 1) * height))
        for i in range(GRID_COLS * GRID_ROWS)
    ]


def estimate_anchor(frame: Image.Image, action: str, phase: int) -> Anchor:
    """Safe initial guess for editing; NOT a planted-foot or anatomy detector."""
    left, top, right, bottom = image_bbox(frame)
    alpha = frame.getchannel("A")
    band_top = max(top, bottom - 5)
    pixels = alpha.load()
    xs = [x for y in range(band_top, bottom) for x in range(left, right)
          if pixels[x, y] >= 64]
    x = round(sum(xs) / len(xs)) if xs else (left + right) // 2
    contact = "body_estimate" if action == "defeat" and phase >= 1 else "sole_estimate"
    return Anchor(x, bottom - 1, contact)


def read_annotations(path: Path | None, actor: str) -> dict[int, Anchor]:
    if path is None:
        return {}
    csv_path = path / f"{actor}.csv"
    if not csv_path.exists():
        csv_path = path / actor / f"{actor}.csv"
    if not csv_path.exists():
        return {}
    result: dict[int, Anchor] = {}
    with csv_path.open(encoding="utf-8-sig", newline="") as handle:
        for item in csv.DictReader(handle):
            if not item.get("action") or item.get("frame") is None:
                raise ValueError(f"{csv_path}: action and local frame are required")
            name = item["action"]
            phase = int(item["frame"])
            if item.get("atlas_index", "").strip():
                index = int(item["atlas_index"])
            elif name in ACTIONS and 0 <= phase < len(ACTIONS[name]):
                index = ACTIONS[name][phase]
            else:
                raise ValueError(f"{csv_path}: invalid action/local frame: {name}:{phase}")
            action, actual_phase = action_for(index)
            if name != action or phase != actual_phase or index in result:
                raise ValueError(f"{csv_path}: mismatched or repeated frame {index}")
            reviewed = item.get("reviewed", "0").strip().lower() in ("1", "true", "yes")
            dx, dy = int(item.get("root_dx") or 0), int(item.get("root_dy") or 0)
            if (dx or dy) and not reviewed:
                raise ValueError(f"{actor}:{index}: root motion requires a reviewed point")
            result[index] = Anchor(
                int(item["x"]), int(item["y"]), item.get("anchor_type", "foot"),
                reviewed, dx, dy,
            )
    return result


def collect(frames: list[Image.Image], annotations: Mapping[int, Anchor]):
    if len(frames) != GRID_COLS * GRID_ROWS:
        raise ValueError("Each legacy actor must have 24 frames")
    items = []
    for index, frame in enumerate(frames):
        action, phase = action_for(index)
        bbox = image_bbox(frame)
        anchor = annotations.get(index, estimate_anchor(frame, action, phase))
        if not (0 <= anchor.x < frame.width and 0 <= anchor.y < frame.height):
            raise ValueError(f"{index}: anchor is outside source cell")
        if anchor.root_dx or anchor.root_dy:
            if not anchor.reviewed:
                raise ValueError(f"{index}: unreviewed root motion")
        touches_edge = (bbox[0] == 0 or bbox[1] == 0 or
                        bbox[2] == frame.width or bbox[3] == frame.height)
        items.append({
            "frame": index, "action": action, "phase": phase,
            "bbox": bbox, "anchor": anchor, "source_edge_warning": touches_edge,
        })
    return items


def geometry(items: list[dict], padding: int) -> tuple[int, int, int, int]:
    if padding < 1:
        raise ValueError("Padding must be >= 1 pixel")
    # All extents are relative to each frame's annotated contact point.
    left = min(item["bbox"][0] - item["anchor"].x + item["anchor"].root_dx
               for item in items)
    right = max(item["bbox"][2] - item["anchor"].x + item["anchor"].root_dx
                for item in items)
    top = min(item["bbox"][1] - item["anchor"].y + item["anchor"].root_dy
              for item in items)
    bottom = max(item["bbox"][3] - item["anchor"].y + item["anchor"].root_dy
                 for item in items)
    point_x, point_y = padding - left, padding - top
    width = math.ceil((point_x + right + padding) / 8) * 8
    height = math.ceil((point_y + bottom + padding) / 8) * 8
    return width, height, point_x, point_y


def repack(frames: list[Image.Image], items: list[dict], padding: int):
    width, height, target_x, target_y = geometry(items, padding)
    atlas = Image.new("RGBA", (GRID_COLS * width, GRID_ROWS * height))
    placements = []
    for item in items:
        index, anchor = item["frame"], item["anchor"]
        x = target_x - anchor.x + anchor.root_dx
        y = target_y - anchor.y + anchor.root_dy
        left, top, right, bottom = item["bbox"]
        margin = min(x + left, y + top, width - x - right, height - y - bottom)
        if margin < padding:
            raise AssertionError(f"Frame {index} violates transparent border: {margin}")
        if x < -frames[index].width or y < -frames[index].height:
            raise AssertionError("Invalid placement")
        # Paste the original RGBA bytes; DO NOT scale, interpolate or alpha-flatten.
        crop = frames[index].crop((left, top, right, bottom))
        atlas.paste(crop, ((index % GRID_COLS) * width + x + left,
                           (index // GRID_COLS) * height + y + top))
        placements.append({
            "index": index, "action": item["action"], "phase": item["phase"],
            "anchor_source": [anchor.x, anchor.y],
            "anchor_target": [target_x + anchor.root_dx, target_y + anchor.root_dy],
            "anchor_type": anchor.kind, "reviewed": anchor.reviewed,
            "root_motion": [anchor.root_dx, anchor.root_dy],
            "min_margin": margin, "source_edge_warning": item["source_edge_warning"],
        })
    return atlas, (width, height), placements


def write_gifs(atlas: Image.Image, cell: tuple[int, int], output: Path, actor: str):
    width, height = cell
    for action, indices in ACTIONS.items():
        images = []
        for index in indices:
            tile = atlas.crop(((index % GRID_COLS) * width,
                               (index // GRID_COLS) * height,
                               (index % GRID_COLS + 1) * width,
                               (index // GRID_COLS + 1) * height))
            # The guide is drawn ONLY into preview copies, never into the atlas.
            backdrop = Image.new("RGBA", tile.size, (33, 39, 47, 255))
            backdrop.alpha_composite(tile)
            images.append(backdrop.convert("RGB"))
        images[0].save(
            output / f"preview_{actor}_{action}.gif", save_all=True,
            append_images=images[1:], duration=round(1000 / FPS[action]),
            loop=0, optimize=False,
        )


def process_actor(actor: str, output_root: Path, annotation_root: Path | None,
                  padding: int, require_reviewed: bool, gifs: bool = True):
    if actor not in ACTORS:
        raise ValueError(f"Unknown actor {actor}")
    source = source_path(actor)
    with Image.open(source) as image:
        frames = split_frames(image.convert("RGBA"))
    annotations = read_annotations(annotation_root, actor)
    items = collect(frames, annotations)
    outstanding = [i["frame"] for i in items
                   if i["action"] != "unused" and not i["anchor"].reviewed]
    if require_reviewed and outstanding:
        raise ValueError(f"{actor}: {len(outstanding)} unreviewed anchors: {outstanding}")
    atlas, cell, placements = repack(frames, items, padding)
    out = output_root / actor
    out.mkdir(parents=True, exist_ok=True)
    png_name = f"sprite_{actor}_atlas_anchor_v06.png"
    atlas.save(out / png_name, "PNG", optimize=True)
    with (out / f"{actor}.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(("action", "frame", "atlas_index", "x", "y", "anchor_type",
                         "reviewed", "root_dx", "root_dy", "source_edge_warning"))
        for entry in placements:
            # Keep source slot 0 intact but omit it from the review CSV:
            # the native idle clip starts at atlas index 1. Frame is local to
            # its action, atlas_index is the absolute 6x4 source slot.
            if entry["action"] == "unused":
                continue
            writer.writerow((entry["action"], entry["phase"], entry["index"],
                             *entry["anchor_source"], entry["anchor_type"],
                             int(entry["reviewed"]), *entry["root_motion"],
                             int(entry["source_edge_warning"])))
    report = {
        "actor": actor, "status": "candidate",
        "source": str(source.relative_to(ROOT) if source.is_relative_to(ROOT) else source),
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "atlas": png_name, "atlas_columns": GRID_COLS, "atlas_rows": GRID_ROWS,
        "cell_size": cell, "target_anchor": list(geometry(items, padding)[2:]),
        "minimum_margin": min(x["min_margin"] for x in placements),
        "unreviewed_frames": outstanding,
        "source_edge_frames": [x["index"] for x in placements
                               if x["source_edge_warning"]],
        "actions": {name: list(indices) for name, indices in ACTIONS.items()},
        "frames": placements,
        "limitations": [
            "23 assigned legacy poses and one unused alternate-view frame; no in-betweens authored",
            "Auto-estimated contacts are not human-verified planted feet",
            "RGBA repack does not repair source-clipped weapons or sleeves",
            "Root motion zero unless a reviewer supplies a nonzero displacement",
            "Not connected to runtime WuxiaActorAnimationProfile",
        ],
    }
    (out / "frame_review.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    if gifs:
        write_gifs(atlas, cell, out, actor)
    print(f"{actor}: {len(placements)} original frames / 9 actions, "
          f"cell={cell}, unreviewed={len(outstanding)}, "
          f"source-edge={len(report['source_edge_frames'])}; candidate only")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    selector = parser.add_mutually_exclusive_group(required=True)
    selector.add_argument("--all", action="store_true")
    selector.add_argument("--actor", choices=ACTORS)
    parser.add_argument("--output", type=Path, default=OUTPUT_DIR)
    parser.add_argument("--annotations", type=Path,
                        help="Directory holding reviewed per-actor CSV files")
    parser.add_argument("--padding", type=int, default=DEFAULT_PADDING)
    parser.add_argument("--require-reviewed", action="store_true")
    parser.add_argument("--no-gif", action="store_true")
    args = parser.parse_args()
    selected = ACTORS if args.all else (args.actor,)
    for actor in selected:
        process_actor(actor, args.output, args.annotations, args.padding,
                      args.require_reviewed, not args.no_gif)
    print("BATCH_CANDIDATES_GENERATED; no runtime or in-use references changed")


if __name__ == "__main__":
    main()
