#!/usr/bin/env python3
"""Build 20 *independent* RGBA Bone2D candidate layers from source material.

This is a retargeting pilot: reuse original garment texture but reconstruct
occluded joint overlap, never reuse the old sword+arms attack composite. These
are candidate paint layers, NOT approved production illustration.
Run after build_shen_rig_art_templates.py. No second runtime data format.
"""
import base64, io, json, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops, ImageFont

ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT/"demos/changfeng-battle"
BASE=GAME/"prototypes/shen_rig_first"
INPUT=BASE/"rig_contract.json"
FRAMES=GAME/"captures/shen-rig-first/art-templates/art_frames.json"
OUTPUT=BASE/"candidate_cutouts"
PREVIEW=GAME/"captures/shen-rig-first/candidate-cutout-sheet.png"
ATLAS=GAME/"prototypes/shen_bone2d_v2"
SRC={
 "head":(451,116,29,36),"hair_back":(160,4,49,98),
 "torso":(67,116,40,57),"pelvis":(4,182,38,35),
 "arm_front":(279,4,27,75),"arm_back":(310,4,38,74),
 "thigh_front":(46,182,17,34),"thigh_back":(67,182,16,34),
 "shin_front":(87,182,13,32),"shin_back":(104,182,13,32),
 "boot_front":(163,182,15,19),"boot_back":(182,182,10,18),
 "coat_front":(4,4,43,108),"coat_back":(51,4,44,108),
 "coat_inner":(99,4,57,99)
}
FILL={
 "head":(194,163,139,240),"hair_back":(43,39,47,245),
 "torso":(65,77,90,245),"pelvis":(55,63,74,245),
 "upper_arm_front":(88,103,118,245),"forearm_front":(214,215,208,245),
 "hand_front":(190,151,122,245),"upper_arm_back":(83,93,106,245),
 "forearm_back":(184,191,189,245),"hand_back":(175,139,112,245),
 "thigh_front":(43,47,59,245),"thigh_back":(42,44,56,245),
 "shin_front":(39,42,54,245),"shin_back":(38,40,52,245),
 "boot_front":(39,36,41,245),"boot_back":(42,38,42,245),
 "coat_front":(69,83,101,220),"coat_back":(61,70,85,225),
 "coat_inner":(197,195,184,215),
}
SCALE=4

def atlas():
    chunks="".join((ATLAS/f"atlas.b64.{i:02d}").read_text().strip() for i in range(4))
    img=Image.open(io.BytesIO(base64.b64decode(chunks))).convert("RGBA")
    if img.size!=(512,221):
        raise ValueError(f"Unexpected original candidate atlas dimensions: {img.size}")
    return img

def source_piece(img,name):
    if name in ("sword",): return None
    if name in SRC:
        x,y,w,h=SRC[name]
        return img.crop((x,y,x+w,y+h))
    side="front" if name.endswith("_front") else "back"
    x,y,w,h=SRC["arm_"+side]
    # Real forearm/upper-arm/hand texture regions are derived from the old
    # full sleeve only as a candidate. Repaint seams before final acceptance.
    if name.startswith("upper_arm"):
        a,b=0,43
    elif name.startswith("forearm"):
        a,b=30,66
    else:
        a,b=59,75 if side=="front" else 74
    a=max(0,min(a,h-1));b=min(h,max(a+1,b))
    return img.crop((x,y+a,x+w,y+b))

def rect_from_guides(info, entry, anchors):
    topx,topy=info["canvas_top_left_in_world_px"]
    def xy(pt):
        return ((pt[0]-topx)*SCALE,(pt[1]-topy)*SCALE)
    return xy(anchors[entry["segment_start"]]),xy(anchors[entry["segment_end"]])

def capsule(size,start,end,radius):
    layer=Image.new("L",size,0)
    d=ImageDraw.Draw(layer)
    a=tuple(round(z) for z in start);b=tuple(round(z) for z in end)
    r=max(2,round(radius))
    d.line([a,b],fill=255,width=r*2,joint="curve")
    for x,y in (a,b):
        d.ellipse((x-r,y-r,x+r,y+r),fill=255)
    return layer

def draw_sword(size,start,end):
    canvas=Image.new("RGBA",size)
    d=ImageDraw.Draw(canvas)
    dx,dy=end[0]-start[0],end[1]-start[1]
    length=math.hypot(dx,dy)
    ux,uy=dx/length,dy/length
    nx,ny=-uy,ux
    def pt(t,side=0):
        return tuple(round(v) for v in (start[0]+ux*t+nx*side,start[1]+uy*t+ny*side))
    d.line([pt(-5),pt(length*0.18)],fill=(69,51,42,255),width=13)
    d.line([pt(0),pt(length*0.17)],fill=(169,120,64,255),width=5)
    guard=length*0.2
    d.line([pt(guard,-13),pt(guard,13)],fill=(207,157,83,255),width=7)
    blade=[pt(guard+2,-7),pt(length-13,-4),pt(length,0),pt(length-13,4),pt(guard+2,7)]
    d.polygon(blade,fill=(185,199,204,255))
    d.line([pt(guard+8,0),pt(length-15,0)],fill=(237,239,235,255),width=2)
    return canvas

def build():
    spec=json.loads(INPUT.read_text())
    frame_data=json.loads(FRAMES.read_text())
    if len(frame_data["parts"])!=20:
        raise SystemExit("Need exactly 20 separate cutout contracts")
    anchors={b["name"]:b["anchor"] for b in spec["bones"]}
    for group in spec["accessories"]:
        anchors.update({b["name"]:b["anchor"] for b in group["bones"]})
    anchors.update({name:b["anchor"] for name,b in spec["sockets"].items()})
    entries={p["name"]:p for p in spec["parts"]}
    atlas_img=atlas()
    OUTPUT.mkdir(parents=True,exist_ok=True)
    manifest=[]
    for info in frame_data["parts"]:
        name=info["name"]
        entry=entries[name]
        size=tuple(int(v) for v in info["source_canvas_size_px"])
        a,b=rect_from_guides(info,entry,anchors)
        width=float(info["guide_width_world_px"])*SCALE
        overlap=float(info["joint_overlap_world_px"])*SCALE
        dx,dy=b[0]-a[0],b[1]-a[1]
        length=max(1.0,math.hypot(dx,dy))
        ux,uy=dx/length,dy/length
        st=(a[0]-ux*overlap,a[1]-uy*overlap)
        en=(b[0]+ux*overlap,b[1]+uy*overlap)
        if name=="sword":
            piece=draw_sword(size,a,b)
        else:
            mask=capsule(size,st,en,width/2)
            piece=Image.new("RGBA",size,FILL[name])
            piece.putalpha(mask.point(lambda v:int(v*.95)))
            paint=source_piece(atlas_img,name)
            bbox=mask.getbbox()
            if paint is not None and bbox:
                bw,bh=bbox[2]-bbox[0],bbox[3]-bbox[1]
                if bw>2 and bh>2:
                    paint=paint.resize((bw,bh),Image.Resampling.LANCZOS)
                    alpha=Image.new("L",size,0)
                    alpha.paste(paint.getchannel("A"),bbox[:2])
                    alpha=ImageChops.multiply(alpha,mask)
                    material=Image.new("RGBA",size)
                    material.paste(paint,bbox[:2])
                    piece.alpha_composite(Image.composite(material,Image.new("RGBA",size),alpha))
        # Each layer retains the ENTIRE canonical canvas, including empty
        # padding around the named bone pivot.
        name_path=OUTPUT/f"{name}.png"
        piece.save(name_path,optimize=True)
        alpha=piece.getchannel("A")
        if not alpha.getbbox():
            raise SystemExit("Empty source layer "+name)
        manifest.append({"name":name,"rig_group":info["rig_group"],
            "attach_to_bone":info["attach_to_bone"],
            "canvas_px":list(size),
            "pivot_px":info["pivot_in_source_canvas_px"],
            "z_index":info["z_index"],
            "sha_source":"shen_bone2d_v2_original_atlas + reconstructed overlap",
            "role":"candidate_not_final_art",
            "status":"candidate",
            "file":str(name_path.relative_to(GAME))})
    (OUTPUT/"candidate-manifest.json").write_text(json.dumps({
        "status":"candidate","warning":"Texture reused and repainted/segmented algorithmically. Needs full manual art validation, especially hand joints and robe.",
        "parts":manifest},ensure_ascii=False,indent=2)+"\n")
    # Transparent candidate layout. This visual MUST NOT be called approved.
    cellw,cellh=235,285
    board=Image.new("RGBA",(cellw*5,cellh*4),(32,38,47,255))
    d=ImageDraw.Draw(board)
    for i,item in enumerate(manifest):
        original=Image.open(OUTPUT/f"{item['name']}.png").convert("RGBA")
        original.thumbnail((cellw-25,cellh-50),Image.Resampling.LANCZOS)
        x=(i%5)*cellw+(cellw-original.width)//2
        y=(i//5)*cellh+20
        board.alpha_composite(original,(x,y))
        d.text(((i%5)*cellw+8,(i//5)*cellh+cellh-26),
            item["name"],fill=(240,241,238,255))
    PREVIEW.parent.mkdir(parents=True,exist_ok=True)
    board.convert("RGB").save(PREVIEW)
    print(f"SHEN_20_INDEPENDENT_RGBA_CANDIDATES_OK parts={len(manifest)}")

if __name__=="__main__":
    build()
