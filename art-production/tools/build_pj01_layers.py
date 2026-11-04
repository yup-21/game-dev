#!/usr/bin/env python3
"""Deterministically split the PJ-01 v03 candidate for an isolated Godot QA map.

This is a *technical* pixel-preserving layer extraction, not a replacement for
artist-authored foreground edges or approval of the v03 perspective. Every
source pixel belongs to exactly one layer, so the stacked image is lossless
relative to the candidate source. Geometry is authored separately in Godot.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art-production/candidates/scenes/pingjiang_south_gate/environment_pingjiang_south_gate_master_v03.webp"
OUTPUT = ROOT / "demos/changfeng-battle/assets/imported/scenes/pingjiang_south_gate_qa"
SIZE = (1600, 2000)


def masks() -> dict[str, Image.Image]:
    ground = Image.new("L", SIZE, 0)
    g = ImageDraw.Draw(ground)
    # The top/bottom approach, gate threshold and stone bridge share one fixed
    # world-space corridor. The art bleeds beyond the conservative 360px
    # collision outline; that fringe stays with the static background.
    g.polygon([(620, 0), (980, 0), (980, 1999), (620, 1999)], fill=255)

    foreground = Image.new("L", SIZE, 0)
    f = ImageDraw.Draw(foreground)
    # Stone gateway/crown, with the actual central opening left clear. The
    # lintel and lifted iron teeth can pass in front of the player's upper body.
    f.polygon([(582, 625), (1018, 625), (1018, 705), (956, 701),
               (929, 674), (882, 646), (800, 636), (716, 646),
               (667, 674), (644, 701), (582, 705)], fill=255)
    f.polygon([(582, 705), (660, 705), (660, 1000), (582, 1000)], fill=255)
    f.polygon([(940, 705), (1018, 705), (1018, 1000), (940, 1000)], fill=255)
    f.polygon([(656, 711), (944, 711), (934, 764), (666, 764)], fill=255)
    # Stone bridge parapets and lantern bases run outside the central feet
    # corridor; keep them separately occluding the character at the edges.
    f.polygon([(524, 1050), (622, 1048), (623, 1555), (465, 1587),
               (465, 1492), (524, 1360)], fill=255)
    f.polygon([(978, 1048), (1076, 1050), (1135, 1360),
               (1135, 1587), (977, 1555)], fill=255)
    # Fabric banners hang in front of the gate walls but not across the road.
    f.polygon([(553, 416), (612, 416), (612, 556), (553, 556)], fill=255)
    f.polygon([(988, 416), (1047, 416), (1047, 556), (988, 556)], fill=255)

    ground = ImageChops.subtract(ground, foreground)
    background = ImageChops.invert(ImageChops.lighter(ground, foreground))
    return {"background": background, "ground": ground, "foreground": foreground}


def render() -> dict[str, Image.Image]:
    with Image.open(SOURCE) as im:
        source = im.convert("RGBA")
    if source.size != SIZE:
        raise ValueError(f"Unexpected source size: {source.size}")
    transparent = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    result = {
        name: Image.composite(source, transparent, mask)
        for name, mask in masks().items()
    }
    reconstructed = transparent
    for name in ("background", "ground", "foreground"):
        reconstructed = Image.alpha_composite(reconstructed, result[name])
    if ImageChops.difference(reconstructed, source).getbbox():
        raise AssertionError("Layer stack changed at least one source pixel")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify committed layers")
    args = parser.parse_args()
    result = render()
    for name, layer in result.items():
        destination = OUTPUT / f"{name}.png"
        if args.check:
            if not destination.is_file():
                raise FileNotFoundError(destination)
            with Image.open(destination) as stored:
                if ImageChops.difference(stored.convert("RGBA"), layer).getbbox():
                    raise AssertionError(f"Stale extracted layer: {destination}")
        else:
            OUTPUT.mkdir(parents=True, exist_ok=True)
            layer.save(destination, optimize=True)
        alpha_count = layer.getchannel("A").histogram()[255]
        print(f"PJ01_LAYER_OK {name} 1600x2000 opaque_pixels={alpha_count}")
    print("PJ01_COMPOSITE_EXACT source=v03")


if __name__ == "__main__":
    main()
