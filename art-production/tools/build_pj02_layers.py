#!/usr/bin/env python3
"""Lossless, same-origin RGBA separation of the PJ-02 v02 painted master.

The masks are authored in 1600x1000 world pixels. Each original pixel belongs
to exactly one layer: this is an art split, never a collision rasterization.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art-production/candidates/scenes/pingjiang_crossroads/environment_pingjiang_crossroads_master_v02.webp"
DEST = ROOT / "demos/changfeng-battle/assets/imported/scenes/pingjiang_crossroads"
DESTINATIONS = (
    DEST,
    ROOT / "art-production/candidates/scenes/pingjiang_crossroads/layers-v02",
    ROOT / "art-production/in-use/scenes/pingjiang_crossroads",
)
SIZE = (1600, 1000)

# Authored against v02: paved north approach and continuous E/W street.
# These masks describe artwork only; collision is authored in the Map Resource.
GROUND_OUTLINE = [
    (672, 176), (878, 176), (936, 530), (1040, 548),
    (1599, 568), (1599, 999), (0, 999), (0, 565),
    (575, 546), (640, 520),
]
# Camera-near roof/foliage islands outside the four-way walking corridor.
FOREGROUND_OUTLINES = [
    [(0, 710), (85, 740), (140, 800), (280, 820), (464, 885),
     (490, 999), (0, 999)],
    [(1599, 690), (1510, 750), (1430, 800), (1260, 800),
     (1160, 852), (1100, 999), (1599, 999)],
]


def create_layers(source: Image.Image) -> dict[str, Image.Image]:
    if source.size != SIZE:
        raise ValueError(f"PJ-02 source must be {SIZE}, got {source.size}")
    rgb = source.convert("RGB")
    ground_mask = Image.new("L", SIZE, 0)
    foreground_mask = Image.new("L", SIZE, 0)
    ImageDraw.Draw(ground_mask).polygon(GROUND_OUTLINE, fill=255)
    painter = ImageDraw.Draw(foreground_mask)
    for polygon in FOREGROUND_OUTLINES:
        painter.polygon(polygon, fill=255)
    reverse_foreground = ImageChops.invert(foreground_mask)
    ground_mask = ImageChops.multiply(ground_mask, reverse_foreground)
    background_mask = ImageChops.invert(ImageChops.add(ground_mask, foreground_mask))
    solid = rgb.convert("RGBA")
    empty = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    return {
        name: Image.composite(solid, empty, mask)
        for name, mask in (
            ("background", background_mask),
            ("ground", ground_mask),
            ("foreground", foreground_mask),
        )
    }


def verify(layers: dict[str, Image.Image], source: Image.Image) -> None:
    composite = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    coverage = Image.new("L", SIZE, 0)
    for name, layer in layers.items():
        if layer.mode != "RGBA" or layer.size != SIZE:
            raise AssertionError(f"{name}: invalid mode or size")
        mask = layer.getchannel("A")
        if ImageChops.multiply(coverage, mask).getbbox() is not None:
            raise AssertionError(f"{name}: overlapping alpha")
        coverage = ImageChops.add(coverage, mask)
        composite = Image.alpha_composite(composite, layer)
    if coverage.getextrema() != (255, 255):
        raise AssertionError("layers leave transparent holes")
    if ImageChops.difference(composite.convert("RGB"), source.convert("RGB")).getbbox():
        raise AssertionError("layers do not losslessly reconstruct v02")
    for name in ("ground", "foreground"):
        if layers[name].getchannel("A").getextrema() != (0, 255):
            raise AssertionError(f"{name}: requires genuine transparent pixels")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify committed files without changing them")
    args = parser.parse_args()
    with Image.open(SOURCE) as source:
        expected = create_layers(source)
        verify(expected, source)
        for destination in DESTINATIONS:
            if args.check:
                for name, candidate in expected.items():
                    path = destination / f"{name}.png"
                    with Image.open(path) as actual:
                        if actual.mode != "RGBA" or actual.size != SIZE or any(
                            high != 0 for low, high in
                            ImageChops.difference(actual, candidate).getextrema()
                        ):
                            raise AssertionError(f"{path}: does not match authored mask")
            else:
                destination.mkdir(parents=True, exist_ok=True)
                for name, layer in expected.items():
                    layer.save(destination / f"{name}.png", optimize=True)
    print("PJ-02: three 1600x1000 RGBA layers, exact v02 reconstruction PASS")


if __name__ == "__main__":
    main()
