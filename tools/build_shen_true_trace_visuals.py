#!/usr/bin/env python3
"""Visual acceptance: original sprite | actual Bone2D fitted overlay | bare bones.
Never call a frame 'passed' merely because Godot produced screenshots.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "demos/changfeng-battle/captures/shen-rig-first/true-source-trace"
POSES = {"idle":["idle_1"], "walk":["walk_2","walk_3","walk_4","walk_5"],
         "attack":["attack_6","attack_7","attack_8"]}
IMAGE_SIZE=(420,332)

def tile(img_path, title, error=None):
    image=Image.open(img_path).convert("RGB")
    image.thumbnail(IMAGE_SIZE,Image.Resampling.LANCZOS)
    dest=Image.new("RGB",(IMAGE_SIZE[0],IMAGE_SIZE[1]+35),(30,34,39))
    x=(dest.width-image.width)//2
    dest.paste(image,(x,35))
    draw=ImageDraw.Draw(dest)
    draw.text((8,8),title,fill="#eff1f2")
    if error is not None:
        draw.text((8,22),f"Mean {error:.1f}px",fill="#f2c36e")
    return dest

def main():
    review=json.loads((OUT/"joint-errors.json").read_text())
    results={f["frame"]:f for f in review["frames"]}
    report=[]
    all_frames=[]
    for kind,frames in POSES.items():
        page=Image.new("RGB",(IMAGE_SIZE[0]*3,(IMAGE_SIZE[1]+35)*len(frames)),(27,31,36))
        for i,name in enumerate(frames):
            record=results[name]
            report.append({"frame":name,"mean":record["mean_error_px"],
                "max":record["max_error_px"],"source_quality":record["source_quality"],
                "low_confidence":record["low_confidence"]})
            sections=[
                tile(OUT/(name+"-original.png"),name+" | 1. source sprite"),
                tile(OUT/(name+"-overlay.png"),"2. native Skeleton2D overlay",
                     record["mean_error_px"]),
                tile(OUT/(name+"-bones.png"),"3. native bones + target landmarks"),
            ]
            for j,section in enumerate(sections):
                page.paste(section,(j*IMAGE_SIZE[0],i*(IMAGE_SIZE[1]+35)))
            # Sequential source-frame flipbook; not interpolated Godot gameplay.
            all_frames.append(sections[1])
        page.save(OUT/(kind+"-pose-comparison.png"))
    all_frames[0].save(OUT/"source-poses-flipbook.gif",save_all=True,
        append_images=all_frames[1:],duration=420,loop=0,optimize=True)
    (OUT/"visual-review-summary.json").write_text(json.dumps({
        "status":"human_review_required",
        "interpretation":"Errors measured against hand-labelled visible source landmarks. "
            "Occluded limbs / severed attack boots are EXCLUDED from scored error.",
        "poses":report,
    },ensure_ascii=False,indent=2)+"\n")
    required=[*(OUT/(kind+"-pose-comparison.png") for kind in POSES),
        OUT/"source-poses-flipbook.gif", OUT/"joint-errors.json"]
    if any(not f.is_file() or f.stat().st_size==0 for f in required):
        raise SystemExit("Visual evidence is incomplete")
    print("SHEN_TRUE_SOURCE_TRACE_VISUAL_OK frames="+str(len(report)))

if __name__=="__main__":
    main()
