#!/usr/bin/env python3
"""Rebuild Shen Changfeng's 12 *candidate* GIFs from three AI 5x5 source sheets.

This only performs one shared geometric transformation and deterministic cutting.
It never attempts to fix source-frame clipping, red spill, weapon continuity, or
foot contact; those remain review failures recorded in quality_report.json.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image
from sync_candidate_resources import contents as candidate_resource_contents


ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "art-production/candidates/characters/shen_changfeng/gif-v01"
CANVAS = (328, 256)
SCALE = 0.90  # Identical uniform scale, never resized to a frame's alpha bounds.
# AI source canvases vary slightly in height. Offset each whole *batch* once to
# share the same intended ground line; never auto-center individual frames.
BATCH_OFFSETS = ((48, 23), (48, 20), (48, 23))

# The storyboard determines frame counts, never the dimensions of a sheet.
ACTIONS = {
    "idle": [150, 150, 150, 150],
    "walk": [105] * 8,
    "run": [78] * 8,
    "attack1": [120, 100, 80, 70, 90, 110, 150],
    "attack2": [100, 130, 130, 70, 70, 120, 130],
    "attack3": [110, 100, 95, 80, 80, 100, 145],
    "attack4": [120, 120, 130, 150, 65, 70, 105, 140],
    "skill": [140, 130, 120, 100, 70, 100, 160],
    "evade": [90, 80, 90, 100, 140],
    "guard": [120, 120, 100, 120, 140],
    "hit": [90, 85, 110, 150],
    "defeat": [100, 100, 125, 150, 450],
}
LOOPING = {"idle", "walk", "run"}


def palette_gif_frame(frame: Image.Image) -> Image.Image:
    """Reserve palette index 0 for transparency, keeping 254 opaque colors."""
    alpha = frame.getchannel("A")
    flattened = Image.new("RGB", frame.size, (0, 0, 0))
    flattened.paste(frame, mask=alpha)
    quantized = flattened.quantize(colors=254, method=Image.Quantize.MEDIANCUT)
    original_palette = quantized.getpalette()[: 254 * 3]
    palette = [0, 0, 0] + original_palette
    palette += [0] * (768 - len(palette))
    result = Image.new("P", frame.size)
    result.putpalette(palette)
    indices = quantized.tobytes()
    masks = alpha.tobytes()
    result.frombytes(bytes(min(i + 1, 255) if a >= 128 else 0 for i, a in zip(indices, masks)))
    result.info["transparency"] = 0
    return result


def source_cell(source: Image.Image, index: int) -> Image.Image:
    width, height = source.size
    col, row = index % 5, index // 5
    # AI source canvases need not be divisible by five; this is an explicit
    # equal-fraction layout, not a pixel dimension invented in the .tres.
    box = (
        round(col * width / 5), round(row * height / 5),
        round((col + 1) * width / 5), round((row + 1) * height / 5),
    )
    return source.crop(box)


def inspect_cell(cell: Image.Image) -> dict:
    alpha = cell.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value >= 20 else 0).getbbox()
    if bbox is None:
        return {"empty": True, "raw_margins_px": None, "raw_edge_warning": True, "red_spill_pixels": 0}
    left, top, right, bottom = bbox
    margins = [left, top, cell.width - right, cell.height - bottom]
    # Bright red/orange effects are visually inconsistent with this sword set.
    red_count = sum(
        1 for r, g, b, a in cell.get_flattened_data()
        if a >= 5 and r >= 180 and g <= 95 and b <= 95
    )
    return {
        "empty": False,
        "raw_margins_px": margins,
        "raw_edge_warning": min(margins) < 8,
        "red_spill_pixels": red_count,
    }


def normalize(cell: Image.Image, batch: int) -> Image.Image:
    width = round(cell.width * SCALE)
    height = round(cell.height * SCALE)
    scaled = cell.resize((width, height), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    result.alpha_composite(scaled, BATCH_OFFSETS[batch])
    return result


def main() -> None:
    sources = [
        PACKAGE / "source" / f"sprite_shen_changfeng_batch{i}_5x5_source_v01.png"
        for i in range(1, 4)
    ]
    if any(not path.exists() for path in sources):
        raise SystemExit("Missing one or more original AI source sheets")
    images = [Image.open(path).convert("RGBA") for path in sources]
    mapping = []
    preview_frames = {}
    checks = []
    position = 0
    for action, durations in ACTIONS.items():
        preview_frames[action] = []
        for frame_index, duration in enumerate(durations):
            batch, cell_index = divmod(position, 25)
            cell = source_cell(images[batch], cell_index)
            check = inspect_cell(cell)
            normalized = normalize(cell, batch)
            normalized_bbox = normalized.getchannel("A").point(
                lambda value: 255 if value >= 20 else 0
            ).getbbox()
            if normalized_bbox is None:
                raise ValueError(f"Empty normalized frame: {action}/{frame_index}")
            l, t, r, b = normalized_bbox
            normalized_margins = [l, t, CANVAS[0] - r, CANVAS[1] - b]
            if min(normalized_margins) < 8:
                raise ValueError(f"Normalized frame has less than 8px safety margin: {action}/{frame_index}")
            checks.append({"action_id": action, "frame_index": frame_index, "batch": batch + 1,
                           "cell_index": cell_index,
                           "normalized_margins_px": normalized_margins, **check})
            mapping.append({"batch": batch + 1, "cell_index": cell_index,
                            "action_id": action, "action_frame_index": frame_index,
                            "duration_ms": duration})
            preview_frames[action].append(normalized)
            position += 1
    assert position == 75, position

    outputs = []
    created_gifs = []
    for action, frames in preview_frames.items():
        destination = PACKAGE / "actions" / action / f"sprite_shen_changfeng_{action}_v01.gif"
        destination.parent.mkdir(parents=True, exist_ok=True)
        prepared = [palette_gif_frame(frame) for frame in frames]
        kwargs = {"save_all": True, "append_images": prepared[1:],
                  "duration": ACTIONS[action], "disposal": 2, "transparency": 0,
                  "optimize": False}
        if action in LOOPING:
            kwargs["loop"] = 0
        prepared[0].save(destination, **kwargs)
        with Image.open(destination) as check:
            assert check.size == CANVAS
            assert check.n_frames == len(frames), (action, check.n_frames)
            assert check.info.get("transparency") is not None
        outputs.append({"action_id": action, "frames": len(frames), "loop": action in LOOPING,
                        "gif": destination.relative_to(ROOT).as_posix(),
                        "durations_ms": ACTIONS[action]})
        created_gifs.append(destination)

    # Candidate .tres descriptors are intentionally separate from the existing
    # runtime CharacterDefinition / AnimationProfile / SpriteFrames resources.
    for source in [*sources, *created_gifs]:
        candidate_relative = source.relative_to(ROOT / "art-production/candidates")
        descriptor = (ROOT / "demos/changfeng-battle/data/art_candidates" / candidate_relative).with_suffix(".tres")
        if not descriptor.exists():
            descriptor.parent.mkdir(parents=True, exist_ok=True)
            descriptor.write_text(candidate_resource_contents(source), encoding="utf-8")
        else:
            # An edited descriptor is left intact, but must not lie about size.
            expected = next(line for line in candidate_resource_contents(source).splitlines()
                            if line.startswith("source_pixel_size = "))
            if expected not in descriptor.read_text(encoding="utf-8").splitlines():
                raise ValueError(f"Stale candidate Resource pixel size: {descriptor}")

    manifest = {
        "version": 1, "status": "candidate", "character_id": "shen_changfeng",
        "canvas_px": list(CANVAS), "source_grid": [5, 5],
        "source_sheets": [str(path.relative_to(ROOT)) for path in sources],
        "common_scale": SCALE, "per_batch_offsets_px": [list(offset) for offset in BATCH_OFFSETS],
        "batch_cell_action_map": mapping, "actions": outputs,
        "native_binding_changed": False,
    }
    (PACKAGE / "MANIFEST.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    warning_count = sum(bool(entry["raw_edge_warning"]) for entry in checks)
    red_count = sum(entry["red_spill_pixels"] for entry in checks)
    report = {
        "status": "requires_source_rework_and_visual_review",
        "source_alpha_edge_warnings": warning_count,
        "normalized_margin_failures": 0,
        "source_red_spill_pixels": red_count,
        "frame_checks": checks,
        "notes": [
            "AI source sheets have edge-contact cells; uniform normalization does not restore clipped anatomy or sword tips.",
            "Saturated red/orange color fringes need inspection in the skill/guard/defeat batch; low-alpha pixels are dropped in GIF palette conversion.",
            "Actual support foot, identity, weapon continuity, dynamic loop seams and Godot playback remain unapproved.",
        ],
    }
    (PACKAGE / "quality_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Created {len(outputs)} GIFs / {position} frames; raw edge warnings={warning_count}, red pixels={red_count}")


if __name__ == "__main__":
    main()
