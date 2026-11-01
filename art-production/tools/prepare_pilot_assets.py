#!/usr/bin/env python3
"""Rebuild the first visual-art pilot offline. Never loaded by Godot at runtime."""
from __future__ import annotations

import argparse
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / "art-production" / "candidates" / "2026-11-01"
FRAME_ORDER = {
    "idle": (0, 1), "move": (2, 3, 4, 5),
    "attack": (6, 7, 8), "guard": (9, 10), "hit": (11, 12),
    "evade": (13, 14, 15), "skill": (16, 17, 18),
    "combo": (19, 20, 21), "defeat": (22, 23),
}


def normalized_atlas(path: Path) -> Image.Image:
    src = Image.open(path).convert("RGBA")
    if src.size != (1536, 1024):
        raise ValueError(f"{path}: expected 1536x1024, got {src.size}")
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    for i in range(24):
        x, y = (i % 6) * 256, (i // 6) * 256
        frame = src.crop((x, y, x + 256, y + 256))
        opaque = frame.getchannel("A").point(lambda a: 255 if a >= 24 else 0)
        bbox = opaque.getbbox()
        if bbox is None:
            raise ValueError(f"{path}: blank frame {i}")
        small = frame.resize((166, 166), Image.Resampling.LANCZOS)
        foot = int(bbox[3] * 166 / 256)
        out.alpha_composite(small, (x + 45, y + 227 - foot))
    return out


def separated_layers(path: Path) -> dict[str, Image.Image]:
    original = Image.open(path).convert("RGBA")
    original = original.resize((1600, 1000), Image.Resampling.LANCZOS)
    fore_mask = Image.new("L", original.size, 0)
    brush = ImageDraw.Draw(fore_mask)
    polygons = [
        [(0, 497), (1600, 489), (1600, 610), (1435, 625),
         (1260, 590), (920, 585), (610, 580), (280, 605), (0, 620)],
        [(0, 610), (280, 650), (450, 850), (600, 1000), (0, 1000)],
        [(1600, 580), (1325, 700), (1310, 855), (1375, 1000), (1600, 1000)],
        [(0, 0), (80, 0), (90, 270), (0, 475)],
        [(1560, 125), (1600, 115), (1600, 470), (1530, 435)],
    ]
    for shape in polygons:
        brush.polygon(shape, fill=255)
    ground_mask = Image.new("L", original.size, 0)
    ImageDraw.Draw(ground_mask).polygon(
        [(0, 338), (1600, 348), (1600, 555), (0, 548)], fill=255
    )
    ground_mask = ImageChops.subtract(ground_mask, fore_mask)
    background_mask = ImageChops.subtract(
        Image.new("L", original.size, 255),
        ImageChops.lighter(ground_mask, fore_mask),
    )

    def masked(mask: Image.Image) -> Image.Image:
        image = Image.new("RGBA", original.size, (0, 0, 0, 0))
        image.paste(original, (0, 0), mask)
        return image

    background = masked(background_mask)
    ground = masked(ground_mask)
    foreground = masked(fore_mask)
    dry_composite = Image.alpha_composite(
        Image.alpha_composite(background, ground), foreground
    )
    if ImageChops.difference(dry_composite, original).getbbox() is not None:
        raise ValueError("Layer reconstruction differs from source master")
    weather = Image.new("RGBA", original.size, (0, 0, 0, 0))
    rain = ImageDraw.Draw(weather)
    rng = random.Random(20261101)
    for _ in range(540):
        x, y = rng.randrange(1600), rng.randrange(1000)
        length = rng.randrange(10, 29)
        rain.line([(x, y), (x - 2, y + length)],
                  fill=(165, 194, 203, rng.randrange(12, 50)), width=1)
    preview = Image.alpha_composite(dry_composite, weather)
    return {
        "background": background, "ground": ground,
        "foreground": foreground, "weather": weather, "preview": preview,
    }


def check_atlas(image: Image.Image, label: str) -> None:
    if image.size != (1536, 1024) or image.mode != "RGBA":
        raise ValueError(f"{label}: invalid atlas dimensions/mode")
    for action, frames in FRAME_ORDER.items():
        if len(frames) < 2 or any(not 0 <= i < 24 for i in frames):
            raise ValueError(f"{label}: action {action} has invalid frame indices")
    feet = []
    for i in range(24):
        x, y = (i % 6) * 256, (i // 6) * 256
        frame = image.crop((x, y, x + 256, y + 256))
        opaque = frame.getchannel("A").point(lambda a: 255 if a >= 32 else 0)
        bbox = opaque.getbbox()
        if bbox is None or min(bbox[0], bbox[1]) < 8 or max(bbox[2], bbox[3]) > 248:
            raise ValueError(f"{label}: frame {i} blank or touches tile boundary")
        feet.append(bbox[3])
    if max(feet) - min(feet) > 2:
        raise ValueError(f"{label}: feet drift {min(feet)}..{max(feet)}")
    print(f"{label}: 24 frames, 9 actions, safe margins, feet {min(feet)}..{max(feet)}")


def build() -> list[tuple[Path, Image.Image]]:
    result = []
    for identity, source in [
        ("shen_changfeng", "sprite_shen_changfeng_atlas_source_v02.png"),
        ("pursuer_captain", "sprite_pursuer_captain_atlas_source_v02.png"),
    ]:
        result.append((
            BATCH / identity / f"sprite_{identity}_atlas_normalized_v02.png",
            normalized_atlas(BATCH / identity / source),
        ))
    scene_dir = BATCH / "rainy_bridge"
    layers = separated_layers(scene_dir / "environment_rainy_bridge_master_v01.png")
    for name, image in layers.items():
        filename = (f"scene_rainy_bridge_{name}_v01.png"
                    if name != "preview" else "scene_rainy_bridge_composite_preview_v01.png")
        result.append((scene_dir / filename, image))
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="create missing outputs")
    parser.add_argument("--replace", action="store_true",
                        help="with --write, explicitly allow changing a candidate")
    args = parser.parse_args()
    if args.replace and not args.write:
        parser.error("--replace requires --write")
    for path, expected in build():
        if "atlas_normalized" in path.name:
            check_atlas(expected, path.name)
        if expected.mode != "RGBA":
            raise ValueError(f"{path}: missing alpha channel")
        if path.exists():
            with Image.open(path) as present:
                same = present.size == expected.size and present.mode == expected.mode
                if same:
                    same = ImageChops.difference(present, expected).getbbox() is None
            if same:
                print(f"OK {path.relative_to(ROOT)}")
                continue
            if not args.write or not args.replace:
                raise ValueError(f"{path}: differs; --write --replace required")
        elif not args.write:
            raise FileNotFoundError(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        expected.save(path, format="PNG", optimize=True, compress_level=9)
        print(f"WROTE {path.relative_to(ROOT)}")
    print("PILOT_ASSETS_OK")


if __name__ == "__main__":
    main()
