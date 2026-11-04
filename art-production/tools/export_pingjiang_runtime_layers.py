#!/usr/bin/env python3
"""Export pixel-exact, aligned Pingjiang native scene layers from approved masters.

This offline authoring step uses *only* original master pixels. A pixel belongs
to exactly one layer; background/ground/foreground alpha-composite to the source
without a single changed RGB pixel. The game never reads these mask presets.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


SCENES = {
    "pingjiang_south_gate": {
        "size": (1600, 2000),
        "source": "art-production/candidates/scenes/pingjiang_south_gate/environment_pingjiang_south_gate_master_v03.webp",
        "ground": [[(625, 0), (975, 0), (975, 2000), (625, 2000)]],
        "foreground": [
            # Overhead gate lintel and hanging teeth, with the open arch void
            # excluded; this is an overhang, not an opaque box over the road.
            [(585, 617), (1015, 617), (1015, 814), (948, 814),
             (916, 740), (684, 740), (652, 814), (585, 814)],
            [(585, 814), (675, 814), (675, 1055), (585, 1055)],
            [(925, 814), (1015, 814), (1015, 1055), (925, 1055)],
            # The parapet is in front of the hero on the bridge. The painted
            # roadway between these occluders remains on the ground layer.
            [(442, 1040), (630, 1040), (630, 1598), (442, 1598)],
            [(970, 1040), (1158, 1040), (1158, 1598), (970, 1598)],
        ],
    },
    "pingjiang_crossroads": {
        "size": (1600, 1000),
        "source": "art-production/candidates/scenes/pingjiang_crossroads/environment_pingjiang_crossroads_master_v02.webp",
        "ground": [
            [(630, 0), (970, 0), (970, 1000), (630, 1000)],
            [(0, 545), (1600, 545), (1600, 836), (0, 836)],
        ],
        "foreground": [
            # Ornamental arch, projected in front of the upper vertical lane.
            [(573, 87), (1027, 87), (1027, 221), (950, 221),
             (912, 173), (681, 173), (650, 221), (573, 221)],
        ],
    },
    "pingjiang_outer_road": {
        "size": (1600, 1000),
        "source": "art-production/candidates/scenes/pingjiang_outer_road/environment_pingjiang_outer_road_master_v01.png",
        "ground": [[(640, 0), (960, 0), (960, 1000), (640, 1000)]],
        "foreground": [],
    },
}


def export(root: Path, scene_id: str) -> None:
    definition = SCENES[scene_id]
    source_path = root / definition["source"]
    original = Image.open(source_path).convert("RGBA")
    expected = definition["size"]
    # The generated outer-road seed is 1586x992, and its 1% calibration to
    # 1600x1000 happens HERE, once. All runtime layers share that output grid.
    if original.size != expected:
        if scene_id != "pingjiang_outer_road":
            raise ValueError(f"{scene_id}: source {original.size}, expected {expected}")
        original = original.resize(expected, Image.Resampling.LANCZOS)

    def mask_for(polygons: list[list[tuple[int, int]]]) -> Image.Image:
        mask = Image.new("L", expected, 0)
        brush = ImageDraw.Draw(mask)
        for polygon in polygons:
            brush.polygon(polygon, fill=255)
        return mask

    foreground_mask = mask_for(definition["foreground"])
    ground_mask = mask_for(definition["ground"])
    # Ground is never painted under a foreground occluder. Pixel ownership is
    # exclusive, so the reconstruction test also detects double-painted art.
    ground_mask = ImageChops.subtract(ground_mask, foreground_mask)
    background_mask = ImageChops.subtract(
        ImageChops.subtract(Image.new("L", expected, 255), ground_mask), foreground_mask
    )
    masks = {"background": background_mask, "ground": ground_mask,
             "foreground": foreground_mask}
    destination = root / "demos/changfeng-battle/assets/imported/scenes" / scene_id
    destination.mkdir(parents=True, exist_ok=True)
    composed = Image.new("RGBA", expected)
    layers = ("background", "ground", "foreground") if foreground_mask.getbbox() else ("background", "ground")
    for layer in layers:
        target = original.copy()
        target.putalpha(masks[layer])
        composed = Image.alpha_composite(composed, target)
        target.save(destination / f"{layer}.webp", format="WEBP", lossless=True, method=6)
    if ImageChops.difference(composed, original).getbbox() is not None:
        raise AssertionError(f"{scene_id}: reconstructed pixels differ from the master")
    # Test the actual encoded assets Godot will import, not just the in-memory
    # masks. Lossy WebP accidentally enabled here would fail this assertion.
    decoded = Image.new("RGBA", expected)
    for layer in layers:
        with Image.open(destination / f"{layer}.webp") as saved:
            decoded = Image.alpha_composite(decoded, saved.convert("RGBA"))
    if ImageChops.difference(decoded, original).getbbox() is not None:
        raise AssertionError(f"{scene_id}: WebP encoding changed visible pixels")
    if not foreground_mask.getbbox() and scene_id != "pingjiang_outer_road":
        raise AssertionError(f"{scene_id}: missing occlusion geometry")
    print(f"{scene_id}: {expected}, {len(layers)} lossless aligned layers, pixel-identical composite")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("scenes", nargs="*", choices=tuple(SCENES.keys()))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    for scene in args.scenes or SCENES:
        export(root, scene)


if __name__ == "__main__":
    main()
