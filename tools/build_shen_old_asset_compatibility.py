#!/usr/bin/env python3
"""Visual retargeting evidence: existing V3 cutouts vs universal human bones."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "demos/changfeng-battle/captures/shen-rig-first/old-asset-compatibility"
DURATIONS = {"idle": 150, "walk": 100, "attack_sword": 88}

def main() -> None:
    frames = {}
    for action, duration in DURATIONS.items():
        paths = sorted((BASE / action).glob("frame-*.png"))
        if len(paths) != 8:
            raise SystemExit(f"Expected 8 overlay frames for {action}; found {len(paths)}")
        sequence = [Image.open(path).convert("RGB") for path in paths]
        frames[action] = sequence
        sequence[0].save(BASE / (action + "-retarget.gif"), save_all=True,
            append_images=sequence[1:], duration=duration, loop=0,
            optimize=True)
    box_w, box_h = 290, 230
    report = Image.new("RGB", (box_w * 4, box_h * 3), "#1a222b")
    draw = ImageDraw.Draw(report)
    for row,(action, sequence) in enumerate(frames.items()):
        for col, frame_index in enumerate((0,2,5,7)):
            tile = sequence[frame_index].copy()
            tile.thumbnail((box_w - 6, box_h - 30))
            x,y=col*box_w,row*box_h
            report.paste(tile,(x+(box_w-tile.width)//2, y+25))
            draw.text((x+9,y+7),f"{action} / frame {frame_index}",
                fill="white", font=ImageFont.load_default())
    report.save(BASE / "new-core-over-old-sprites.png")
    required = [BASE / "new-core-over-old-sprites.png", BASE / "bind-with-new-core.png",
        *(BASE / f"{a}-retarget.gif" for a in DURATIONS)]
    for path in required:
        if not path.exists() or path.stat().st_size == 0:
            raise SystemExit("Missing retarget evidence " + str(path))
    print("SHEN_OLD_ASSET_COMPATIBILITY_EVIDENCE_OK")

if __name__=="__main__":
    main()
