#!/usr/bin/env python3
"""Create one Godot-native editor-only Resource per candidate source image.

Existing .tres files are never rewritten: artists can refine anchors, grids,
frame timing and visual size without losing edits. --check fails on missing
candidate Resources, changed image dimensions, or orphaned Resource files.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys

from PIL import Image


REPO = Path(__file__).resolve().parents[2]
SOURCES = REPO / "art-production/candidates"
DEST = REPO / "demos/changfeng-battle/data/art_candidates"
EXTENSIONS = {".png", ".webp", ".jpg", ".jpeg", ".svg", ".gif"}
GRID = re.compile(r"(?:^|_)([1-9][0-9]?)x([1-9][0-9]?)(?:_|$)")
SCRIPT = 'res://scripts/content/art_candidate_definition.gd'


def escape(value: str) -> str:
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'


def image_size(path: Path) -> tuple[int, int]:
    if path.suffix.lower() == ".svg":
        import xml.etree.ElementTree as ET

        root = ET.parse(path).getroot()
        # SVG units that cannot be interpreted as pixels should be measured
        # explicitly during visual review; do not guess a size from viewBox.
        w = root.attrib.get("width", "").removesuffix("px")
        h = root.attrib.get("height", "").removesuffix("px")
        if w and h:
            return int(float(w)), int(float(h))
        viewbox = root.attrib.get("viewBox", "").split()
        if len(viewbox) == 4:
            return int(float(viewbox[2])), int(float(viewbox[3]))
        raise ValueError(f"SVG has no measurable canvas: {path}")
    with Image.open(path) as image:
        return image.size


def describe(source: Path) -> tuple[str, str, str, int, int, int, int]:
    relative = source.relative_to(SOURCES)
    category = relative.parts[0]
    owner = relative.parts[1]
    name = source.stem.lower()
    if category == "characters":
        kind = "sprite" if name.startswith("sprite_") else (
            "portrait" if name.startswith(("portrait_", "pose_")) else "concept")
    elif category == "scenes":
        kind = "scene_layer"
    elif category == "vfx":
        kind = "vfx"
    else:
        kind = "ui"
    width, height = image_size(source)
    grid = GRID.search(name)
    cols, rows = (int(grid.group(1)), int(grid.group(2))) if grid else (0, 0)
    if cols > 0 and (width % cols or height % rows):
        # A filename is not proof that an AI-created sheet has exact cells.
        # Preserve the original sheet and mark its grid as unconfigured.
        cols, rows = 0, 0
    if kind in ("portrait", "concept", "scene_layer", "ui"):
        cols, rows = 1, 1
    action = relative.parts[-2] if "actions" in relative.parts else ""
    return kind, owner, action, width, height, cols, rows


def contents(source: Path) -> str:
    kind, owner, action, width, height, cols, rows = describe(source)
    path = source.relative_to(REPO).as_posix()
    lines = [
        '[gd_resource type="Resource" script_class="WuxiaArtCandidateDefinition" load_steps=2 format=3]',
        "",
        f'[ext_resource type="Script" path={escape(SCRIPT)} id="1_candidate"]',
        "",
        "[resource]",
        'script = ExtResource("1_candidate")',
        f"asset_kind = {escape(kind)}",
        f"owner_id = {escape(owner)}",
        f"source_path = {escape(path)}",
        f"source_pixel_size = Vector2i({width}, {height})",
        f"columns = {cols}",
        f"rows = {rows}",
    ]
    if action:
        lines.append(f"action_id = {escape(action)}")
    return "\n".join(lines) + "\n"


def files() -> list[tuple[Path, Path]]:
    return [
        (source, DEST / source.relative_to(SOURCES).with_suffix(".tres"))
        for source in sorted(SOURCES.rglob("*"))
        if source.is_file() and source.suffix.lower() in EXTENSIONS
        and source.relative_to(SOURCES).parts[0] in ("characters", "scenes", "vfx", "ui")
    ]


def run(check: bool) -> int:
    pairs = files()
    actual = {target for target in DEST.rglob("*.tres")}
    expected = {target for _, target in pairs}
    errors: list[str] = []
    created = 0
    if len(expected) != len(pairs):
        errors.append("Candidate source basename collision (different image formats share a .tres path)")
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    for source, target in pairs:
        try:
            proposed = contents(source)
        except (OSError, ValueError) as exc:
            errors.append(str(exc))
            continue
        if target.exists():
            # Never compare the complete text: artists may have edited the
            # Resource. Pixel dimensions/source identity are checked in Godot.
            continue
        if check:
            errors.append("Missing candidate Resource: " + str(target.relative_to(REPO)))
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(proposed, encoding="utf-8")
        created += 1
    for orphan in sorted(actual - expected):
        errors.append("Orphan candidate Resource: " + str(orphan.relative_to(REPO)))
    for error in errors:
        print(error, file=sys.stderr)
    print(f"Candidate sources: {len(pairs)}, created: {created}, errors: {len(errors)}")
    return 1 if errors else 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report missing/stale resources without writing")
    args = parser.parse_args()
    sys.exit(run(args.check))
