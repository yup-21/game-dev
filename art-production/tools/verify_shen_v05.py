#!/usr/bin/env python3
"""Candidate Atlas geometry check; does not grant visual approval."""
import json,sys
from pathlib import Path
from PIL import Image
import numpy as np
p=Path(sys.argv[1] if len(sys.argv)>1 else ".")
r=json.loads((p/"frame_contract.json").read_text(encoding="utf8"))
im=Image.open(p/"shen_changfeng_v05_atlas.webp").convert("RGBA")
cw,ch=r["cell_size"];cols=r["atlas_columns"];rows=r["atlas_rows"]
assert im.size==(cols*cw,rows*ch)
indices=[i for a in r["actions"].values() for i in a["frames"]]
assert len(indices)==78 and len(set(indices))==78
assert all(0<=i<cols*rows for i in indices)
assert len(r["frames"])==78
assert all(a["min_margin"]>=24 for a in r["frames"])
assert all(a["contact_xy"]==[302,274] for a in r["frames"])
for i in (78,79):
    tile=im.crop((i%cols*cw,i//cols*ch,(i%cols+1)*cw,(i//cols+1)*ch))
    assert np.asarray(tile.getchannel("A")).max()==0
print("Geometry PASS: 78 frames, 2 empty, min gap 24, numerical anchor 0")
print("Source edge warnings:",sum(a["source_touches_cell_edge"] for a in r["frames"]))
print("Human contact review pending:",sum(not a["contact_reviewed"] for a in r["frames"]))
