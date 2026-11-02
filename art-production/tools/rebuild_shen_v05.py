#!/usr/bin/env python3
"""Reproducible 10-action RGBA sprite candidate packer (never changes in-use .tres).

pip install pillow numpy opencv-python
python art-production/tools/rebuild_shen_v05.py --inputs path/to/source_pngs --output candidate_output
Optionally edit candidate_output/foot_annotations.csv, set reviewed=1, rerun with
--annotations candidate_output/foot_annotations.csv. Auto foot picks are estimates.
"""
from pathlib import Path
import argparse
import csv
import json
import math
import numpy as np
import cv2
from PIL import Image, ImageDraw

CELL_W, CELL_H, COLS = 768, 320, 8
PADDING = 24
TARGET_X, TARGET_Y = 302, 274
A_THRESHOLD = 96
SOURCES = [
    ("idle", "单剑侠客待机循环.png", 2, 4, None, 12),
    ("move", "沈长风武侠动作精灵表.png", 8, 4, 1, 14),
    ("attack", "沈长风八帧剑招精灵图.png", 2, 4, None, 14),
    ("guard", "沈长风单剑守势八帧动画.png", 2, 4, None, 12),
    ("hit", "水墨武侠剑客受击四帧动作图.png", 2, 2, None, 12),
    ("evade", "沈长风六式闪避动作分镜.png", 3, 2, None, 16),
    ("skill", "沈长风八式剑技连招精灵图.png", 4, 2, None, 15),
    ("combo", "十帧水墨武侠连击剑招_sprite图集.png", 5, 2, None, 16),
    ("ultimate", "沈长风十二式剑技连招图集.png", 4, 3, None, 16),
    ("defeat", "六帧武侠剑客倒下动画.png", 3, 2, None, 10),
]

def crop_source(im, cols, rows, only_row, index):
    row = only_row if only_row is not None else index // cols
    col = index if only_row is not None else index % cols
    return im.crop((round(col*im.width/cols), round(row*im.height/rows),
                    round((col+1)*im.width/cols), round((row+1)*im.height/rows)))

def clean(im):
    rgba = np.asarray(im.convert("RGBA")).copy()
    r,g,b = [rgba[:,:,i].astype("int16") for i in range(3)]
    bad = ((r>155)&(r>g*1.55)&(r>b*1.5)) | ((r>185)&(g>105)&(b<110)&(r>b*1.7))
    rgba[:,:,3][bad]=0
    rgba[:,:,3][rgba[:,:,3]<16]=0
    return Image.fromarray(rgba,"RGBA")

def bounds(im):
    alpha=np.asarray(im.getchannel("A"))
    y,x=np.where(alpha>=A_THRESHOLD)
    if len(x)==0: raise ValueError("empty cell")
    return (int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1))

def estimated_contact(im,action,i):
    a=np.asarray(im)
    x0,y0,x1,y1=bounds(im)
    if action=="defeat" and i>=3:
        return int(x0+(x1-x0)*0.45),y1-2
    yy,xx=np.indices(a.shape[:2])
    mask=(a[:,:,3]>=A_THRESHOLD)&(a[:,:,:3].mean(axis=2)<167)&(yy>=y0+(y1-y0)*.69)
    ys,xs=np.where(mask)
    if len(xs)<10:
        ys,xs=np.where((a[:,:,3]>=A_THRESHOLD)&(yy>=y0+(y1-y0)*.69))
    if len(xs)<1: return (x0+x1)//2,y1-1
    sole=np.percentile(ys,96)
    indices=ys>=sole-7
    fx=xs[indices]
    side=("front" if action in ("move","evade","combo","ultimate") and (i//2)%2 else "rear")
    return int(np.percentile(fx,75 if side=="front" else 25)),int(np.percentile(ys[indices],98))

def pack(raw,action,index,confirmed):
    im=clean(raw)
    box=bounds(im)
    x0,y0,x1,y1=box
    ax,ay=confirmed.get((action,index), estimated_contact(im,action,index))
    full=im.crop(box);ax-=x0;ay-=y0
    h,w=full.height,full.width
    scale=min(218/max(1,h),
              (TARGET_X-PADDING)/max(1,ax),
              (CELL_W-PADDING-TARGET_X)/max(1,w-ax),
              (TARGET_Y-PADDING)/max(1,ay),
              (CELL_H-PADDING-TARGET_Y)/max(1,h-ay))
    new_w,new_h=max(1,round(w*scale)),max(1,round(h*scale))
    new=full.resize((new_w,new_h),Image.Resampling.LANCZOS)
    left=TARGET_X-round(ax*scale)
    top=TARGET_Y-round(ay*scale)
    assert left>=PADDING and top>=PADDING
    assert left+new_w<=CELL_W-PADDING and top+new_h<=CELL_H-PADDING
    cell=Image.new("RGBA",(CELL_W,CELL_H))
    cell.alpha_composite(new,(left,top))
    bx0,by0,bx1,by1=bounds(cell)
    margin=min(bx0,by0,CELL_W-bx1,CELL_H-by1)
    contact=(left+round(ax*scale),top+round(ay*scale))
    assert contact==(TARGET_X,TARGET_Y),contact
    assert margin>=PADDING,(action,index,margin)
    return cell,{
       "action":action,"frame":index,"contact_xy":list(contact),
       "contact_reviewed":(action,index) in confirmed,
       "source_touches_cell_edge":x0<=3 or y0<=3 or x1>=raw.width-3 or y1>=raw.height-3,
       "min_margin":margin}

def run(inputs,output,annotation_path):
    output.mkdir(parents=True,exist_ok=True)
    confirmed={}
    if annotation_path and annotation_path.exists():
        with annotation_path.open(encoding="utf8",newline="") as f:
            for row in csv.DictReader(f):
                if row.get("reviewed")=="1":
                    confirmed[(row["action"],int(row["frame"]))]=(int(row["x"]),int(row["y"]))
    cells=[];report=[];action_ids={};annotations=[]
    for action,name,cols,rows,only_row,fps in SOURCES:
        im=Image.open(inputs/name).convert("RGBA")
        total=cols if only_row is not None else cols*rows
        ids=[]
        for i in range(total):
            source=crop_source(im,cols,rows,only_row,i)
            clean_source=clean(source)
            bx,by=confirmed.get((action,i),estimated_contact(clean_source,action,i))
            cell,item=pack(source,action,i,confirmed)
            ids.append(len(cells));cells.append(cell);report.append(item)
            annotations.append((action,i,bx,by,1 if (action,i) in confirmed else 0,
                                int(item["source_touches_cell_edge"])))
        action_ids[action]={"frames":ids,"fps_target":fps,
                            "loop":action in ("idle","move"),"runtime_clip":action!="ultimate"}
    with (output/"foot_annotations.csv").open("w",encoding="utf8",newline="") as f:
        wr=csv.writer(f);wr.writerow(["action","frame","x","y","reviewed","source_edge_flag"])
        wr.writerows(annotations)
    while len(cells)%COLS: cells.append(Image.new("RGBA",(CELL_W,CELL_H)))
    atlas=Image.new("RGBA",(COLS*CELL_W,len(cells)//COLS*CELL_H))
    for i,cell in enumerate(cells):
        atlas.alpha_composite(cell,((i%COLS)*CELL_W,(i//COLS)*CELL_H))
    atlas.save(output/"shen_changfeng_v05_atlas.webp",lossless=True,method=5)
    for action,meta in action_ids.items():
        ids=meta["frames"]
        sheet=Image.new("RGBA",(COLS*CELL_W,math.ceil(len(ids)/COLS)*CELL_H))
        for j,i in enumerate(ids):
            sheet.alpha_composite(cells[i],((j%COLS)*CELL_W,(j//COLS)*CELL_H))
        sheet.save(output/("shen_changfeng_v05_"+action+".webp"),lossless=True,method=5)
    result={"status":"candidate","size":list(atlas.size),"cell_size":[CELL_W,CELL_H],
            "atlas_columns":COLS,"atlas_rows":len(cells)//COLS,
            "contact_target":[TARGET_X,TARGET_Y],"actions":action_ids,"frames":report,
            "edge_warning_count":sum(r["source_touches_cell_edge"] for r in report)}
    (output/"frame_contract.json").write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf8")
    print("CANDIDATE_BUILD_OK",len(report),"frames",
          result["edge_warning_count"],"source-edge warnings; NOT approved")

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--inputs",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True)
    p.add_argument("--annotations",type=Path)
    args=p.parse_args()
    run(args.inputs,args.output,args.annotations)
