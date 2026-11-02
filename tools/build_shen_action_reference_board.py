#!/usr/bin/env python3
"""Extract actual Shen animation reference frames from the normalized 6x4 atlas.
This is an action storyboard, not artwork for bone binding.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
ATLAS=ROOT/"demos/changfeng-battle/assets/imported/candidates/2026-11-01/shen_changfeng/sprite_shen_changfeng_atlas_normalized_v02.png"
OUT=ROOT/"demos/changfeng-battle/captures/shen-rig-first"
COLS, ROWS = 6, 4
REF={"idle":[1],"walk":[2,3,4,5],"attack_sword":[6,7,8]}
CELL=256
def main():
    atlas=Image.open(ATLAS).convert("RGBA")
    expected=(COLS*CELL,ROWS*CELL)
    if atlas.size!=expected:
        raise SystemExit(f"Unexpected atlas dimensions {atlas.size} expected {expected}")
    OUT.mkdir(parents=True,exist_ok=True)
    width, height=235,280
    margin=12
    page=Image.new("RGB",(margin*2+4*width, margin*2+3*(height+30)),(26,32,38))
    draw=ImageDraw.Draw(page)
    font=ImageFont.load_default()
    for row,(action,frames) in enumerate(REF.items()):
        for col, index in enumerate(frames):
            x=(index%COLS)*CELL
            y=(index//COLS)*CELL
            frame=atlas.crop((x,y,x+CELL,y+CELL))
            # Keep exact original source-foot registration (at y=228).
            display=frame.resize((width,width),Image.Resampling.LANCZOS)
            left=margin+col*width
            top=margin+row*(height+30)
            draw.rectangle((left,top,left+width-1,top+height+28),fill=(36,43,49))
            page.paste(display,(left,top+26),display)
            baseline=top+26+int(round(228*width/CELL))
            draw.line((left,baseline,left+width,baseline),fill=(111,195,146),width=1)
            draw.text((left+7,top+7),f"{action} / source frame {index}",fill=(237,239,238),font=font)
    page.save(OUT/"original-sprite-motion-reference.png")
    print("SHEN_SOURCE_SPRITE_FRAMES_OK",ATLAS)

if __name__=="__main__":
    main()
