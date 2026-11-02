#!/usr/bin/env python3
"""Assemble three small rig-only playback GIFs and their keyframes."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "demos/changfeng-battle/captures/shen-rig-first"
SPECS = {"idle": 150, "walk": 100, "attack_sword": 88}
KEYS = (0, 2, 5, 7)

def main():
    frames = {}
    for name, duration in SPECS.items():
        paths = sorted((BASE / name).glob("frame-*.png"))
        if len(paths) != 8:
            raise SystemExit(f"{name}: found {len(paths)} frames, expected 8")
        source = [Image.open(p).convert("RGB") for p in paths]
        frames[name] = source
        source[0].save(BASE / (name + ".gif"), append_images=source[1:],
            save_all=True, loop=0, duration=duration, optimize=True)
    width, height = 300, 205
    out = Image.new("RGB", (width * 4, (height + 25) * 3), (24, 29, 35))
    draw = ImageDraw.Draw(out)
    for row, (name, sequence) in enumerate(frames.items()):
        for col, index in enumerate(KEYS):
            img = sequence[index]
            img.thumbnail((width-6, height-6))
            x = width * col
            y = row * (height+25)
            out.paste(img, (x, y+25))
            draw.text((x+8,y+5), f"{name} / frame {index}", fill="#ffffff", font=ImageFont.load_default())
    out.save(BASE / "keyframes.png")
    for name in SPECS:
        if not (BASE / (name + ".gif")).stat().st_size:
            raise SystemExit("Missing " + name + " GIF")
    print("SHEN_RIG_FIRST_GIFS_OK")

if __name__ == "__main__":
    main()
