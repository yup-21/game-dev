#!/usr/bin/env python3
"""Audit chapter-one generated concept sources and prepare the ruined-temple
scene's aligned layers. Offline authoring utility; never loaded at runtime.
"""
from __future__ import annotations

import argparse
import hashlib
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / "art-production/candidates/2026-11-01"
CHARACTERS = ("gu_qingshuang", "green_wanderer", "black_blade",
              "night_assassin")
STORY_NPC = "escort_elder"
CANVAS = (1600, 1000)


def file_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def alpha_observations(path: Path, size: tuple[int, int],
                       atlas: bool = False) -> list[str]:
    problems = []
    with Image.open(path) as img:
        if img.size != size:
            problems.append(f"expected {size}, got {img.size}")
        if img.mode != "RGBA":
            problems.append(f"RGBA required, got {img.mode}")
        if "A" not in img.getbands():
            return problems
        alpha = img.getchannel("A")
        if alpha.getextrema()[0] == 255:
            problems.append("alpha fully opaque: painted backdrop is not transparent")
        if atlas and img.size == (1536, 1024):
            for i in range(24):
                x, y = (i % 6) * 256, (i // 6) * 256
                tile = alpha.crop((x, y, x + 256, y + 256))
                corners = (tile.getpixel((0, 0)), tile.getpixel((255, 0)),
                           tile.getpixel((0, 255)), tile.getpixel((255, 255)))
                if min(corners) > 24:
                    problems.append(f"frame {i}: corners not transparent")
                if tile.getbbox() is None:
                    problems.append(f"frame {i}: blank")
    return problems



def source_cell_edge_risks(path: Path) -> list[str]:
    """Flag likely clipped poses before normalization hides source-cell edges.

    This is a conservative triage signal, not proof that every other frame is
    artistically complete. Strict mode treats flagged source atlases as blockers.
    """
    risks: list[str] = []
    with Image.open(path) as image:
        if image.size != (1536, 1024) or "A" not in image.getbands():
            return risks
        alpha = image.getchannel("A")
        for frame_index in range(24):
            x, y = frame_index % 6 * 256, frame_index // 6 * 256
            tile = alpha.crop((x, y, x + 256, y + 256))
            edge_bands = {
                "top": (16, 0, 240, 2),
                "bottom": (16, 254, 240, 256),
                "left": (0, 16, 2, 240),
                "right": (254, 16, 256, 240),
            }
            touching = []
            for edge, bounds in edge_bands.items():
                band = tile.crop(bounds)
                # Ignore antialiasing noise and isolated flecks.
                opaque = band.point(lambda a: 255 if a >= 24 else 0)
                if opaque.histogram()[255] >= 8:
                    touching.append(edge)
            if touching:
                risks.append(f"frame {frame_index} touches {','.join(touching)}")
    return risks


def audit_sources() -> int:
    problems = []
    for identity in CHARACTERS:
        base = BATCH / identity
        problems.extend(f"{identity} portrait: {x}" for x in alpha_observations(
            base / f"portrait_{identity}_fullbody_v01.png", (1024, 1536)))
        source_atlas = base / f"sprite_{identity}_atlas_source_v01.png"
        problems.extend(f"{identity} atlas: {x}" for x in alpha_observations(
            source_atlas, (1536, 1024), atlas=True))
        edge_risks = source_cell_edge_risks(source_atlas)
        if edge_risks:
            examples = "; ".join(edge_risks[:8])
            problems.append(
                f"{identity} source-cell clipping risk in "
                f"{len(edge_risks)}/24 frames ({examples}); "
                "repaint complete isolated frames before re-atlasing")
    base = BATCH / STORY_NPC
    problems.extend(f"{STORY_NPC} portrait: {x}" for x in alpha_observations(
        base / "portrait_escort_elder_fullbody_v01.png", (1024, 1536)))
    problems.extend(f"{STORY_NPC} pose: {x}" for x in alpha_observations(
        base / "pose_escort_elder_injured_v01.png", (1536, 1024)))
    master = BATCH / "ruined_temple/environment_ruined_temple_master_v01.png"
    with Image.open(master) as image:
        if image.size != (1586, 992):
            problems.append(f"ruined_temple master: unexpected dimensions {image.size}")
    for identity in (*CHARACTERS, STORY_NPC):
        base = BATCH / identity
        for p in base.glob("*.png"):
            print(f"SOURCE {p.relative_to(ROOT)} SHA256 {file_digest(p)}")
    print(f"SOURCE {master.relative_to(ROOT)} SHA256 {file_digest(master)}")
    for issue in problems:
        print(f"NEEDS_REVIEW {issue}")
    print(f"ART_SOURCE_AUDIT: {len(problems)} unresolved alpha/atlas/source-boundary issues")
    return len(problems)


def prepare_temple(master_path: Path) -> dict[str, Image.Image]:
    with Image.open(master_path) as raw:
        image = raw.convert("RGBA").resize(CANVAS, Image.Resampling.LANCZOS)
    foreground = Image.new("L", CANVAS, 0)
    mask_draw = ImageDraw.Draw(foreground)
    # Screen-space masks, not collision. Preserve same source coordinates.
    for poly in (
        [(0, 0), (520, 0), (430, 80), (230, 140), (0, 240)],
        [(0, 700), (75, 740), (170, 810), (550, 865), (900, 1000), (0, 1000)],
        [(1600, 690), (1475, 760), (1240, 860), (1030, 1000),
         (1600, 1000)],
    ):
        mask_draw.polygon(poly, fill=255)
    ground = Image.new("L", CANVAS, 0)
    ImageDraw.Draw(ground).polygon(
        [(0, 450), (1600, 410), (1600, 860), (0, 865)], fill=255)
    ground = ImageChops.subtract(ground, foreground)
    background = ImageChops.subtract(
        Image.new("L", CANVAS, 255), ImageChops.lighter(ground, foreground))

    def masked(mask: Image.Image) -> Image.Image:
        result = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        result.paste(image, (0, 0), mask)
        return result

    layers = {"background": masked(background), "ground": masked(ground),
              "foreground": masked(foreground)}
    dry = Image.alpha_composite(
        Image.alpha_composite(layers["background"], layers["ground"]),
        layers["foreground"])
    if ImageChops.difference(dry.convert("RGB"),
                             image.convert("RGB")).getbbox():
        raise ValueError("composite differs from the resized scene master")
    weather = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    draw = ImageDraw.Draw(weather)
    rng = random.Random(20261101)
    for _ in range(480):
        x, y = rng.randrange(CANVAS[0]), rng.randrange(CANVAS[1])
        draw.line((x, y, x-2, y+rng.randrange(9, 24)),
                  fill=(172, 200, 214, rng.randrange(15, 43)), width=1)
    layers["weather"] = weather
    layers["preview"] = Image.alpha_composite(dry, weather)
    return layers



def normalized_atlas(path: Path) -> Image.Image:
    with Image.open(path) as source:
        atlas = source.convert("RGBA")
    if atlas.size != (1536, 1024):
        raise ValueError(f"{path}: source must be 6x4 256x256 cells")
    output = Image.new("RGBA", atlas.size, (0, 0, 0, 0))
    for frame_index in range(24):
        x, y = frame_index % 6 * 256, frame_index // 6 * 256
        frame = atlas.crop((x, y, x+256, y+256))
        opaque = frame.getchannel("A").point(lambda a: 255 if a >= 24 else 0)
        bounds = opaque.getbbox()
        if bounds is None:
            raise ValueError(f"{path}: frame {frame_index} has no subject")
        small = frame.resize((166, 166), Image.Resampling.LANCZOS)
        foot = round(bounds[3] * 166 / 256)
        output.alpha_composite(small, (x+45, y+227-foot))
    return output


def audit_normalized_atlas(atlas: Image.Image, label: str) -> None:
    feet = []
    for frame_index in range(24):
        x, y = frame_index % 6 * 256, frame_index // 6 * 256
        frame = atlas.crop((x, y, x+256, y+256))
        bounds = frame.getchannel("A").point(
            lambda a: 255 if a >= 24 else 0).getbbox()
        if bounds is None:
            raise ValueError(f"{label}: missing frame {frame_index}")
        if min(bounds[0], bounds[1]) < 8 or max(bounds[2], bounds[3]) > 248:
            raise ValueError(f"{label}: frame {frame_index} touches tile margin")
        feet.append(bounds[3])
    if max(feet) - min(feet) > 3:
        raise ValueError(f"{label}: inconsistent bottom anchor {min(feet)}-{max(feet)}")
    print(f"NORMALIZED_ATLAS_OK {label}: 24 cells, bounds-safe, foot range {min(feet)}-{max(feet)}")

def verify_or_write(layers: dict[str, Image.Image], output: Path,
                    write: bool, replace: bool) -> None:
    for name, expected in layers.items():
        filename = (f"scene_ruined_temple_{name}_v01.png" if name != "preview"
                    else "scene_ruined_temple_composite_preview_v01.png")
        target = output / filename
        if target.exists():
            with Image.open(target) as present:
                same = (present.size == CANVAS and present.mode == "RGBA"
                        and present.tobytes() == expected.tobytes())
            if same:
                print(f"OK {target.relative_to(ROOT)}")
                continue
            if not write or not replace:
                raise ValueError(f"{target} differs; explicit --write --replace required")
        elif not write:
            print(f"PENDING_LAYER {target.relative_to(ROOT)}")
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        expected.save(target, format="PNG", optimize=True)
        print(f"WROTE {target.relative_to(ROOT)}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="write missing layered scene outputs")
    parser.add_argument("--replace", action="store_true", help="with --write, allow replacing changed candidates")
    parser.add_argument("--strict", action="store_true", help="fail on source alpha, frame and boundary-clipping risks")
    args = parser.parse_args()
    if args.replace and not args.write:
        parser.error("--replace requires --write")
    issues = audit_sources()
    scene_dir = BATCH / "ruined_temple"
    layers = prepare_temple(scene_dir / "environment_ruined_temple_master_v01.png")
    verify_or_write(layers, scene_dir, args.write, args.replace)
    for identity in CHARACTERS:
        actor_dir = BATCH / identity
        target = actor_dir / f"sprite_{identity}_atlas_normalized_v01.png"
        expected = normalized_atlas(
            actor_dir / f"sprite_{identity}_atlas_source_v01.png")
        audit_normalized_atlas(expected, identity)
        if target.exists():
            with Image.open(target) as current:
                same = (current.mode == "RGBA" and current.size == expected.size
                        and current.tobytes() == expected.tobytes())
            if same:
                print(f"OK {target.relative_to(ROOT)}")
                continue
            if not args.write or not args.replace:
                raise ValueError(f"{target}: differs; --write --replace required")
        elif not args.write:
            print(f"PENDING_ATLAS {target.relative_to(ROOT)}")
            continue
        expected.save(target, "PNG", optimize=True)
        print(f"WROTE {target.relative_to(ROOT)}")
    if issues and args.strict:
        raise SystemExit("STRICT_ART_SOURCE_AUDIT_FAILED")
    print("CHAPTER_ONE_CANDIDATE_AUDIT_OK (not art approval)")


if __name__ == "__main__":
    main()
