#!/usr/bin/env python3
"""Review evidence of actual per-bone PNG binding rendered in Godot."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/"demos/changfeng-battle/captures/shen-rig-first/candidate-bound"
ART=ROOT/"demos/changfeng-battle/prototypes/shen_rig_first/candidate_cutouts"
ACTIONS={"idle":160,"walk":110,"attack_sword":110}
def main():
    frames={}
    for name,duration in ACTIONS.items():
        paths=sorted((BASE/name).glob("frame-*.png"))
        if len(paths)!=8:raise SystemExit(f"{name}: expected 8 Godot screenshots, got {len(paths)}")
        images=[Image.open(p).convert("RGB") for p in paths]
        frames[name]=images
        images[0].save(BASE/(name+".gif"),save_all=True,
            append_images=images[1:],duration=duration,loop=0,optimize=True)
    w,h=340,350
    board=Image.new("RGB",(w*4,h*3),(26,31,39))
    d=ImageDraw.Draw(board)
    for row,(name,images) in enumerate(frames.items()):
        for col,index in enumerate((0,2,5,7)):
            img=images[index]
            img.thumbnail((w-15,h-38))
            x=col*w+(w-img.width)//2
            y=row*h+32
            board.paste(img,(x,y))
            d.text((col*w+9,row*h+9),f"{name} / frame {index}",fill="white")
    board.save(BASE/"keyframes.png")
    missing=[]
    manifest=json.loads((ART/"candidate-manifest.json").read_text())
    for p in manifest["parts"]:
        f=ART/(p["name"]+".png")
        if not f.exists() or Image.open(f).size!=tuple(p["canvas_px"]):
            missing.append(p["name"])
    if missing:raise SystemExit("Missing candidate RGBA layers: "+str(missing))
    (BASE/"candidate-visual-gate.json").write_text(json.dumps({
        "technical_binding":"pending human pixel visual approval",
        "art_status":"candidate_not_approved",
        "parts":len(manifest["parts"]),
        "reason":"Segmented and completed from original material, not finished hand-redrawn illustration. Inspect seam caps and sword grip in all clips.",
        "required_views":["bind-pose.png","bind-with-bones.png","keyframes.png"]},indent=2)+"\n")
    print("SHEN_CANDIDATE_BOUND_GIFS_OK action_count=3 parts="+str(len(manifest["parts"])))
if __name__=="__main__":main()
