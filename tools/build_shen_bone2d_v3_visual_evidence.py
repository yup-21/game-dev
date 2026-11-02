#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CAP = ROOT / "demos" / "changfeng-battle" / "captures" / "shen-bone2d-v3"
ACTIONS = {"idle": 150, "walk": 100, "attack_sword": 88}
KEYS = (0, 2, 5, 7)

def resize(im, width):
    if im.width <= width:
        return im.copy()
    return im.resize((width, round(im.height * width / im.width)), Image.Resampling.LANCZOS)

def main():
    all_frames = {}
    for action, duration in ACTIONS.items():
        paths = sorted((CAP / action).glob("frame-*.png"))
        if len(paths) != 8:
            raise SystemExit(f"{action}: expected 8 frames, got {len(paths)}")
        frames = [Image.open(p).convert("RGBA") for p in paths]
        all_frames[action] = frames
        rgb = [resize(x, 520).convert("RGB") for x in frames]
        rgb[0].save(CAP / f"{action}.gif", save_all=True, append_images=rgb[1:],
                    duration=duration, loop=0, optimize=True, disposal=2)

    thumbs = {}
    max_h = 0
    for action, frames in all_frames.items():
        for i in KEYS:
            t = resize(frames[i], 250).convert("RGB")
            thumbs[(action, i)] = t
            max_h = max(max_h, t.height)
    font = ImageFont.load_default()
    margin, gap, label_h = 14, 8, 22
    cell_w, cell_h = 250 + gap, max_h + label_h + gap
    sheet = Image.new("RGB", (margin * 2 + cell_w * 4, margin * 2 + cell_h * len(ACTIONS)), (25, 28, 31))
    draw = ImageDraw.Draw(sheet)
    for row, action in enumerate(ACTIONS):
        for col, i in enumerate(KEYS):
            x, y = margin + col * cell_w, margin + row * cell_h
            sheet.paste(thumbs[(action, i)], (x, y + label_h))
            draw.text((x + 4, y + 4), f"{action} frame {i}", fill=(235,235,235), font=font)
    sheet.save(CAP / "keyframes-contact-sheet.png")

    required = [CAP / "overview.png", CAP / "bind-pose-overlay.png", CAP / "keyframes-contact-sheet.png",
                *(CAP / f"{a}.gif" for a in ACTIONS)]
    missing = [p for p in required if not p.exists() or p.stat().st_size == 0]
    if missing:
        raise SystemExit("missing: " + ", ".join(map(str, missing)))
    print("SHEN_BONE2D_V3_GIFS_OK")

if __name__ == "__main__":
    main()
