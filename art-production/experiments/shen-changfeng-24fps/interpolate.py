#!/usr/bin/env python3
"""Candidate-only 8x4 RGBA atlas -> 24fps previews and transparent 8x3 atlases.
Requires Pillow, numpy and opencv-python.
Usage: python interpolate.py path/to/user_source.png output_dir
"""
import sys
from pathlib import Path
import cv2
import numpy as np
from PIL import Image

source = Image.open(sys.argv[1]).convert("RGBA")
output = Path(sys.argv[2])
output.mkdir(parents=True, exist_ok=True)
w, h = source.size
for row, name in enumerate(("idle", "walk", "attack", "guard")):
    originals = []
    for col in range(8):
        frame = source.crop((round(col*w/8), round(row*h/4),
                             round((col+1)*w/8), round((row+1)*h/4)))
        if frame.width > 224 or frame.height > 224:
            raise ValueError("Input cells exceed 224x224; choose a larger canvas")
        canvas = Image.new("RGBA", (224, 224))
        canvas.alpha_composite(frame, ((224-frame.width)//2, 224-frame.height))
        originals.append(np.array(canvas))
    interpolated = []
    for index, a in enumerate(originals):
        b = originals[(index+1) % len(originals)]
        a_gray = cv2.cvtColor(a[:,:,:3], cv2.COLOR_RGB2GRAY)
        b_gray = cv2.cvtColor(b[:,:,:3], cv2.COLOR_RGB2GRAY)
        flow = cv2.calcOpticalFlowFarneback(a_gray, b_gray, None,
                                            .5, 3, 17, 3, 5, 1.1, 0)
        yy, xx = np.mgrid[:224, :224].astype(np.float32)
        for step in range(3):
            t = step / 3
            if step == 0:
                interpolated.append(Image.fromarray(a))
                continue
            a_warp = cv2.remap(a, xx-flow[:,:,0]*t, yy-flow[:,:,1]*t,
                               cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
            b_warp = cv2.remap(b, xx+flow[:,:,0]*(1-t),
                               yy+flow[:,:,1]*(1-t), cv2.INTER_LINEAR,
                               borderMode=cv2.BORDER_CONSTANT)
            mixed = np.uint8(np.clip(a_warp*(1-t)+b_warp*t, 0, 255))
            interpolated.append(Image.fromarray(mixed))
    atlas = Image.new("RGBA", (8*224, 3*224))
    for i, frame in enumerate(interpolated):
        atlas.alpha_composite(frame, ((i%8)*224, (i//8)*224))
    atlas.save(output / f"{name}_24fps_atlas.png")
    preview = []
    for frame in interpolated:
        background = Image.new("RGBA", (224,224), (31,36,43,255))
        background.alpha_composite(frame)
        preview.append(background.convert("RGB").quantize(colors=128))
    preview[0].save(output / f"{name}_24fps.gif", save_all=True,
                    append_images=preview[1:], duration=[42,42,41]*8,
                    loop=0, optimize=False, disposal=2)
