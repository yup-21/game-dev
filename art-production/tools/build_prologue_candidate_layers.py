#!/usr/bin/env python3
"""Build two 1600x1000 aligned prologue scene candidates from approved masters.

Requires Pillow. Input files are deliberately supplied separately as candidate
art; this script does not download images or promote assets to live scenes.
Usage:
python art-production/tools/build_prologue_candidate_layers.py \
  --source-root /path/to/generated/masters \
  --out demos/changfeng-battle/assets/candidates/prologue
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageOps

SIZE = (1600, 1000)
SOURCES = {
    "temple_hall": "雨夜残寺篝火.png",
    "mountain_road": "雨中竹山古道与破车.png",
}


def polygon(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]]) -> None:
    draw.polygon(points, fill=255)


def partition_masks(scene: str) -> tuple[Image.Image, Image.Image, Image.Image]:
    floor = Image.new("L", SIZE)
    front = Image.new("L", SIZE)
    ground_draw = ImageDraw.Draw(floor)
    front_draw = ImageDraw.Draw(front)

    if scene == "temple_hall":
        polygon(ground_draw, [
            (0,418), (200,420), (290,435), (565,420),
            (1005,418), (1340,429), (1600,413), (1600,1000), (0,1000)])
        polygon(front_draw, [
            (0,568), (80,616), (280,670), (498,747),
            (521,806), (295,805), (0,750)])
        polygon(front_draw, [
            (0,862), (340,898), (660,982), (653,1000), (0,1000)])
        polygon(front_draw, [
            (991,985), (1050,920), (1600,867), (1600,1000)])
    elif scene == "mountain_road":
        polygon(ground_draw, [
            (594,0), (1019,0), (974,340), (1037,600),
            (1084,1000), (533,1000), (551,718), (584,400)])
        polygon(front_draw, [
            (978,311), (1155,256), (1370,333), (1461,469),
            (1353,650), (1099,664), (944,552)])
        polygon(front_draw, [
            (0,0), (448,0), (340,117), (160,231), (0,326)])
        polygon(front_draw, [
            (0,768), (202,830), (445,906), (495,1000), (0,1000)])
        polygon(front_draw, [
            (1460,712), (1600,655), (1600,1000),
            (1232,1000), (1350,868)])
    else:
        raise ValueError("unknown scene: " + scene)

    # Partition pixels, never paste independently redrawn image elements.
    floor.paste(0, (0, 0, SIZE[0], SIZE[1]), front)
    rear = ImageOps.invert(ImageChops.lighter(floor, front))
    return rear, floor, front


def export_layers(source_root: Path, out_root: Path) -> list[dict]:
    audit = []
    for scene, filename in SOURCES.items():
        source = source_root / filename
        if not source.is_file():
            raise FileNotFoundError(source)
        master = ImageOps.fit(Image.open(source).convert("RGB"), SIZE,
                              method=Image.Resampling.LANCZOS).convert("RGBA")
        target = out_root / scene
        target.mkdir(parents=True, exist_ok=True)
        master.save(target / "master.png", optimize=True)
        layers = []
        for role, mask in zip(("background", "ground", "foreground"),
                              partition_masks(scene)):
            layer = master.copy()
            layer.putalpha(mask)
            layer.save(target / (role + ".png"), optimize=True)
            layers.append(layer)
        composite = Image.new("RGBA", SIZE, (0, 0, 0, 0))
        for layer in layers:
            composite = Image.alpha_composite(composite, layer)
        composite.save(target / "preview.png", optimize=True)
        # Reject independently hallucinated geometry / holey layer exports.
        if ImageChops.difference(composite, master).getbbox() is not None:
            raise ValueError("Pixel alignment failed: " + scene)
        audit.append({
            "scene": scene, "source": filename, "size": [1600, 1000],
            "pixel_equal_master": True,
            "layer_order": ["background", "ground", "foreground"],
            "status": "candidate_unapproved",
        })
    (out_root / "manifest.json").write_text(
        json.dumps({"scenes": audit}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8")
    return audit


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=Path(
        "demos/changfeng-battle/assets/candidates/prologue"))
    args = parser.parse_args()
    print(json.dumps(export_layers(args.source_root, args.out),
                     ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
