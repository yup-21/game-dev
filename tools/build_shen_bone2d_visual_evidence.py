#!/usr/bin/env python3
"""Build reviewable GIFs and a key-frame contact sheet for PR visual evidence."""

from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CAPTURE_ROOT = ROOT / "demos" / "changfeng-battle" / "captures" / "shen-bone2d"
ACTIONS = {
    "idle": 150,
    "walk": 100,
    "attack_sword": 75,
    "guard": 125,
}
KEY_INDICES = (0, 2, 5, 7)
GIF_WIDTH = 760
THUMB_WIDTH = 300


def resized(image: Image.Image, width: int) -> Image.Image:
    if image.width <= width:
        return image.copy()
    height = round(image.height * width / image.width)
    return image.resize((width, height), Image.Resampling.LANCZOS)


def load_frames(action: str) -> list[Image.Image]:
    paths = sorted((CAPTURE_ROOT / action).glob("frame-*.png"))
    if len(paths) != 8:
        raise SystemExit(f"{action}: expected 8 PNG frames, found {len(paths)}")
    return [Image.open(path).convert("RGBA") for path in paths]


def build_gif(action: str, duration_ms: int, frames: list[Image.Image]) -> Path:
    rendered = [resized(frame, GIF_WIDTH).convert("RGB") for frame in frames]
    target = CAPTURE_ROOT / f"{action}.gif"
    rendered[0].save(
        target,
        save_all=True,
        append_images=rendered[1:],
        duration=duration_ms,
        loop=0,
        optimize=True,
        disposal=2,
    )
    return target


def build_contact_sheet(all_frames: dict[str, list[Image.Image]]) -> Path:
    font = ImageFont.load_default()
    thumbs: dict[tuple[str, int], Image.Image] = {}
    max_h = 0
    for action, frames in all_frames.items():
        for index in KEY_INDICES:
            thumb = resized(frames[index], THUMB_WIDTH).convert("RGB")
            thumbs[(action, index)] = thumb
            max_h = max(max_h, thumb.height)

    label_h = 24
    gap = 10
    margin = 16
    cell_w = THUMB_WIDTH + gap
    cell_h = max_h + label_h + gap
    sheet = Image.new(
        "RGB",
        (
            margin * 2 + cell_w * len(KEY_INDICES),
            margin * 2 + cell_h * len(ACTIONS),
        ),
        (28, 31, 34),
    )
    draw = ImageDraw.Draw(sheet)

    for row, action in enumerate(ACTIONS):
        for col, index in enumerate(KEY_INDICES):
            thumb = thumbs[(action, index)]
            x = margin + col * cell_w
            y = margin + row * cell_h
            sheet.paste(thumb, (x, y + label_h))
            draw.text((x + 4, y + 4), f"{action}  frame {index}", font=font, fill=(235, 235, 235))

    target = CAPTURE_ROOT / "keyframes-contact-sheet.png"
    sheet.save(target)
    return target


def main() -> None:
    CAPTURE_ROOT.mkdir(parents=True, exist_ok=True)
    all_frames: dict[str, list[Image.Image]] = {}
    for action, duration in ACTIONS.items():
        frames = load_frames(action)
        all_frames[action] = frames
        target = build_gif(action, duration, frames)
        print(f"GIF {target}")
    contact = build_contact_sheet(all_frames)
    print(f"CONTACT_SHEET {contact}")

    required = [
        CAPTURE_ROOT / "overview.png",
        CAPTURE_ROOT / "keyframes-contact-sheet.png",
        *(CAPTURE_ROOT / f"{action}.gif" for action in ACTIONS),
    ]
    missing = [path for path in required if not path.exists() or path.stat().st_size == 0]
    if missing:
        raise SystemExit("missing visual evidence: " + ", ".join(map(str, missing)))


if __name__ == "__main__":
    main()
