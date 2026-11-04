#!/usr/bin/env python3
"""Conservative repair for existing 6x4 RGBA sprite sheets.

Removes detached fragments that entered a cell, keeps the dominant action
silhouette, and repacks frames with a shared bottom presentation anchor.
Original source and normalized atlases remain unchanged for rollback.
Requires Pillow. Run with --write to update native resource bindings.
"""
from __future__ import annotations
import argparse
from collections import deque
from pathlib import Path
from PIL import Image, ImageChops, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "demos/changfeng-battle"
BATCH = Path("candidates/characters")
ACTORS = ("shen_changfeng", "pursuer_captain", "gu_qingshuang",
          "green_wanderer", "black_blade", "night_assassin")
V2 = {"shen_changfeng", "pursuer_captain"}
FRAME = 256
COLS, ROWS = 6, 4
MARGIN = 8
TARGET_BOTTOM = 226
ALPHA = 24


def dominant_mask(frame: Image.Image) -> tuple[Image.Image, int, float]:
    alpha = frame.getchannel("A")
    signal = alpha.point(lambda p: 255 if p >= ALPHA else 0)
    # Dilation reconnects the sleeves, blades and robes of one silhouette,
    # without grouping small fragments across a long transparent gap.
    expanded = signal.filter(ImageFilter.MaxFilter(13))
    data = expanded.tobytes()
    visited = bytearray(FRAME * FRAME)
    components = []
    for idx, value in enumerate(data):
        if value == 0 or visited[idx]:
            continue
        visited[idx] = 1
        queue = deque([idx])
        members = []
        while queue:
            k = queue.popleft()
            members.append(k)
            x, y = k % FRAME, k // FRAME
            for neighbor in ((k-1 if x else -1),
                             (k+1 if x < FRAME-1 else -1),
                             (k-FRAME if y else -1),
                             (k+FRAME if y < FRAME-1 else -1)):
                if neighbor >= 0 and not visited[neighbor] and data[neighbor]:
                    visited[neighbor] = 1
                    queue.append(neighbor)
        components.append(members)
    if not components:
        return frame.copy(), 0, 0.0
    # The largest connected expanded silhouette is normally the actor.
    # Tiny detached flickers at neighboring frame borders are discarded.
    main = max(components, key=len)
    keep = bytearray(FRAME * FRAME)
    for k in main:
        keep[k] = 255
    mask = Image.frombytes("L", (FRAME, FRAME), bytes(keep))
    original_sum = sum(alpha.getdata())
    kept_alpha = ImageChops.multiply(alpha, mask)
    retained = sum(kept_alpha.getdata()) / max(1, original_sum)
    result = frame.copy()
    result.putalpha(kept_alpha)
    removed = sum(1 for a, b in zip(alpha.getdata(), kept_alpha.getdata()) if a > 0 and b == 0)
    return result, removed, retained


def repair_cell(frame: Image.Image, index: int) -> tuple[Image.Image, str]:
    cleaned, removed, retained = dominant_mask(frame)
    # When segmentation looks ambiguous, do not silently delete major artwork.
    if retained < 0.78:
        cleaned = frame.copy()
        warning = "AMBIGUOUS_CONNECTED_ART"
    else:
        warning = ""
    bbox = cleaned.getchannel("A").point(lambda a: 255 if a >= ALPHA else 0).getbbox()
    if bbox is None:
        return Image.new("RGBA", (FRAME, FRAME)), f"{index}: EMPTY"
    # Isolate frame pixels before all transforms. Never composite into
    # adjacent atlas cells. Rescale only when an edge needs a safe margin.
    source = cleaned.crop(bbox)
    max_dimension = FRAME - 2*MARGIN
    factor = min(1.0, max_dimension/source.width, max_dimension/source.height)
    if factor < 1.0:
        source = source.resize((max(1, round(source.width*factor)),
                                max(1, round(source.height*factor))), Image.Resampling.LANCZOS)
    # Keep the original horizontal action motion, but ensure the frame
    # remains entirely inside its own cell.
    x = max(MARGIN, min(FRAME-MARGIN-source.width, bbox[0]))
    y = max(MARGIN, min(FRAME-MARGIN-source.height, TARGET_BOTTOM-source.height))
    output = Image.new("RGBA", (FRAME, FRAME))
    output.alpha_composite(source, (x,y))
    margin_bbox = output.getchannel("A").point(lambda a: 255 if a >= ALPHA else 0).getbbox()
    assert margin_bbox and margin_bbox[0]>=MARGIN and margin_bbox[1]>=MARGIN
    assert margin_bbox[2]<=FRAME-MARGIN and margin_bbox[3]<=FRAME-MARGIN
    return output, f"{index}: removed={removed}, retained={retained:.3f}, bottom={margin_bbox[3]} {warning}".strip()


def run(write: bool) -> None:
    for actor in ACTORS:
        version = "v02" if actor in V2 else "v01"
        original = (ROOT / "art-production" / BATCH / actor / "baseline" /
                    f"sprite_{actor}_atlas_normalized_{version}.png")
        if not original.is_file():
            raise FileNotFoundError(original)
        with Image.open(original) as image:
            source = image.convert("RGBA")
        if source.size != (1536,1024):
            raise ValueError(f"{original}: expected 1536x1024")
        atlas = Image.new("RGBA", source.size)
        for i in range(24):
            x, y = (i%COLS)*FRAME, (i//COLS)*FRAME
            cell, report = repair_cell(source.crop((x,y,x+FRAME,y+FRAME)),i)
            print(f"{actor}: {report}")
            atlas.paste(cell, (x,y))
        filename = f"sprite_{actor}_atlas_aligned_v03.png"
        relative = BATCH / actor / "baseline" / filename
        destinations = (ROOT / "art-production" / relative,
                        ROOT / "art-production/in-use/characters" / actor / "sprites" / filename,
                        GAME / "assets/imported/characters" / actor / "sprites" / filename)
        if write:
            for dest in destinations:
                dest.parent.mkdir(parents=True, exist_ok=True)
                atlas.save(dest, "PNG", optimize=True)
        for kind in ("animations", "characters"):
            resource = GAME / "data/native" / kind / f"{actor}.tres"
            current = resource.read_text(encoding="utf-8")
            old = f"sprite_{actor}_atlas_normalized_{version}.png"
            if old not in current and filename not in current:
                raise ValueError(f"{resource}: neither old nor current sheet is bound")
            if write and old in current:
                resource.write_text(current.replace(old, filename), encoding="utf-8")
        print(f"{actor}: {'WROTE' if write else 'PREVIEW'} 24 isolated frames, native profile + card")
    if write:
        print("SPRITE_REPAIR_OK")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()
    run(args.write)
