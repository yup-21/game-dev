#!/usr/bin/env python3
"""Reusable, alpha-transparent world-scale calibration overlay for authored scenes.

Only produces a DESIGN REFERENCE overlay. Never import it into live scenery.
Numbers are read from Godot's combat_scale.gd to avoid a second scale authority.

Usage:
  python art-production/tools/scene_scale_guide.py --output /tmp/town_scale.png
  python art-production/tools/scene_scale_guide.py --orientation vertical --output /tmp/vertical_street.png
  python art-production/tools/scene_scale_guide.py --orientation mixed --output /tmp/crossroads.png
  python art-production/tools/scene_scale_guide.py --check
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCALE_SCRIPT = ROOT / "demos/changfeng-battle/scripts/combat_scale.gd"


def read_scale() -> tuple[float, float, float]:
    script = SCALE_SCRIPT.read_text(encoding="utf-8")
    def number(const: str) -> float:
        match = re.search(r"^\s*const\s+" + re.escape(const)
                          + r"\s*:=\s*(\d+(?:\.\d+)?)\s*$",
                          script, flags=re.MULTILINE)
        if match is None:
            raise ValueError(f"Godot scale constant missing: {const}")
        return float(match.group(1))
    return (number("PIXELS_PER_UNIT"), number("ACTOR_HEIGHT_UNITS"),
            number("FOOTPRINT_RADIUS_UNITS"))


def plan(width: int, height: int, foot_x: int, foot_y: int,
         ground_top: int, ground_bottom: int, door_x: int,
         orientation: str = "horizontal", lane_left: int = 650,
         lane_right: int = 950, lane_top: int = 120,
         lane_bottom: int = 920) -> dict:
    ppu, actor_units, radius_units = read_scale()
    if not 480 <= width <= 8192 or not 400 <= height <= 8192:
        raise ValueError("invalid guide dimensions (480..8192 x 400..8192)")
    if orientation not in ("horizontal", "vertical", "mixed"):
        raise ValueError("orientation must be horizontal, vertical or mixed")
    if orientation in ("horizontal", "mixed") and not (0 < ground_top < foot_y < ground_bottom < height):
        raise ValueError("ground_top < actor foot_y < ground_bottom < height required")
    if orientation in ("vertical", "mixed") and not (
            0 < lane_top < foot_y < lane_bottom < height and
            0 < lane_left < foot_x < lane_right < width and
            lane_right - lane_left >= 2 * round(radius_units * ppu) + 80):
        raise ValueError("vertical corridor must contain the actor, its footprint, and both exits")
    actor_px = round(actor_units * ppu)
    radius_px = round(radius_units * ppu)
    door_h = round(3.5 * ppu)  # visual planning suggestion, NOT gameplay collision
    door_w = round(2.0 * ppu)
    if foot_y - actor_px < 0 or foot_x-radius_px*2 < 0 or foot_x+radius_px*2 > width:
        raise ValueError("actor calibration silhouette does not fit within canvas")
    if door_x-door_w//2 < 0 or door_x+door_w//2 > width or foot_y-door_h < 0:
        raise ValueError("door calibration silhouette does not fit within canvas")
    return dict(width=width, height=height, pixels_per_unit=ppu,
                actor_height_units=actor_units, actor_height_px=actor_px,
                radius_px=radius_px, door_height_px=door_h, door_width_px=door_w,
                foot_x=foot_x, foot_y=foot_y, door_x=door_x,
                ground_top=ground_top, ground_bottom=ground_bottom,
                orientation=orientation, lane_left=lane_left,
                lane_right=lane_right, lane_top=lane_top,
                lane_bottom=lane_bottom)


def render(spec: dict, output: Path) -> None:
    try:
        from PIL import Image, ImageDraw
    except ImportError as exc:
        raise SystemExit("PNG generation requires Pillow (pip install Pillow)") from exc
    w, h = spec["width"], spec["height"]
    ppu = int(spec["pixels_per_unit"])
    actor = spec["actor_height_px"]
    radius = spec["radius_px"]
    fx, fy, dx = spec["foot_x"], spec["foot_y"], spec["door_x"]
    canvas = Image.new("RGBA", (w,h), (0,0,0,0))
    draw = ImageDraw.Draw(canvas, "RGBA")
    # Grid is a measuring overlay for production; DO NOT ship this as scenery.
    for x in range(0,w,ppu):
        draw.line((x,0,x,h),fill=(34,166,216,70),width=1)
    for y in range(0,h,ppu):
        draw.line((0,y,w,y),fill=(34,166,216,70),width=1)
    orientation = spec["orientation"]
    if orientation in ("horizontal", "mixed"):
        draw.rectangle((0,spec["ground_top"],w-1,spec["ground_bottom"]),
                       fill=(77,192,132,36),outline=(64,192,126,220),width=2)
        draw.text((15,max(0,spec["ground_top"]-25)),
                  "horizontal street band (planning only)",fill=(23,132,81,255))
    if orientation in ("vertical", "mixed"):
        ll, rr = spec["lane_left"], spec["lane_right"]
        top, bottom = spec["lane_top"], spec["lane_bottom"]
        draw.rectangle((ll,top,rr,bottom),
                       fill=(77,192,132,36),outline=(64,192,126,220),width=3)
        draw.polygon([(fx,top+15),(fx-25,top+52),(fx+25,top+52)],
                     fill=(64,192,126,230))
        draw.polygon([(fx,bottom-15),(fx-25,bottom-52),(fx+25,bottom-52)],
                     fill=(64,192,126,230))
        draw.text((rr+14,top+16),"NORTH / SOUTH exits",fill=(23,132,81,255))
        draw.text((rr+14,top+36),"full-scale world Y travel",fill=(23,132,81,255))
    # Ground contact + visual (not physical) human reference.
    draw.ellipse((fx-radius,fy-radius//3,fx+radius,fy+radius//3),
                 outline=(251,177,65,255),width=3)
    draw.line((fx-48,fy,fx+48,fy),fill=(255,105,52,255),width=3)
    head_r=round(actor*0.095)
    head_y=fy-round(actor*0.89)
    draw.ellipse((fx-head_r,head_y-head_r,fx+head_r,head_y+head_r),
                 fill=(254,175,75,125),outline=(226,112,32,255),width=3)
    draw.polygon([(fx-22,fy-actor+42),(fx+22,fy-actor+42),
                  (fx+35,fy-round(actor*0.37)),(fx-35,fy-round(actor*0.37))],
                 fill=(254,175,75,110))
    draw.line((fx-13,fy-round(actor*0.37),fx-16,fy),fill=(226,112,32,255),width=5)
    draw.line((fx+13,fy-round(actor*0.37),fx+16,fy),fill=(226,112,32,255),width=5)
    draw.line((fx-23,fy-round(actor*0.73),fx-46,fy-round(actor*0.48)),
              fill=(226,112,32,255),width=5)
    draw.line((fx+23,fy-round(actor*0.73),fx+47,fy-round(actor*0.48)),
              fill=(226,112,32,255),width=5)
    if orientation in ("vertical", "mixed"):
        # Second same-sized actor makes accidental distance-dependent scaling
        # conspicuous: neither approaching nor leaving changes body height.
        other_y: int = max(actor+30, spec["lane_top"]+actor+10)
        if other_y < fy-actor//2 and other_y < spec["lane_bottom"]-30:
            draw.ellipse((fx-radius,other_y-radius//3,fx+radius,other_y+radius//3),
                         outline=(251,177,65,255),width=3)
            draw.rectangle((fx-18,other_y-actor+35,fx+18,other_y-44),
                           fill=(254,175,75,90),outline=(226,112,32,255),width=2)
            draw.ellipse((fx-17,other_y-actor,fx+17,other_y-actor+34),
                         outline=(226,112,32,255),width=2)
            draw.line((fx-12,other_y-44,fx-12,other_y),
                      fill=(226,112,32,255),width=4)
            draw.line((fx+12,other_y-44,fx+12,other_y),
                      fill=(226,112,32,255),width=4)
    # Suggested door is 3.5 units high and 2 units wide for character comfort.
    door_height=spec["door_height_px"]
    door_width=spec["door_width_px"]
    draw.rectangle((dx-door_width//2,fy-door_height,
                    dx+door_width//2,fy),
                   outline=(172,88,220,255),fill=(172,88,220,26),width=5)
    draw.line((dx-door_width//2,fy,dx+door_width//2,fy),
              fill=(172,88,220,255),width=3)
    draw.line((fx+72,fy-actor,fx+72,fy),fill=(228,111,25,255),width=3)
    draw.text((fx+82,fy-actor//2),f"actor {spec['actor_height_units']:g}u / {actor}px",
              fill=(162,84,12,255))
    draw.text((dx-door_width//2,fy-door_height-24),
              f"door reference 3.5u = {door_height}px",fill=(151,59,202,255))
    draw.rectangle((12,12,min(w-12,550),95),fill=(255,255,255,205))
    draw.text((24,24),f"WORLD SCALE  |  1u = {ppu} world px",fill=(28,57,68,255))
    draw.text((24,45),f"Actor height: {actor}px   footprint radius: {radius}px",fill=(28,57,68,255))
    draw.text((24,66),f"{orientation.upper()}  {w}x{h}   DO NOT BAKE INTO GAME ART",fill=(28,57,68,255))
    output.parent.mkdir(parents=True,exist_ok=True)
    canvas.save(output,format="PNG")
    print(f"CALIBRATION_OVERLAY_WRITTEN {output}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="write transparent reference PNG")
    parser.add_argument("--check", action="store_true", help="validate world-scale math without Pillow")
    parser.add_argument("--width", type=int, default=1600)
    parser.add_argument("--height", type=int, default=1000)
    parser.add_argument("--orientation", choices=("horizontal", "vertical", "mixed"),
                        default="horizontal")
    parser.add_argument("--foot-x", type=int, default=None)
    parser.add_argument("--foot-y", type=int, default=780)
    parser.add_argument("--door-x", type=int, default=1070)
    parser.add_argument("--ground-top", type=int, default=600)
    parser.add_argument("--ground-bottom", type=int, default=920)
    parser.add_argument("--lane-left", type=int, default=650)
    parser.add_argument("--lane-right", type=int, default=950)
    parser.add_argument("--lane-top", type=int, default=120)
    parser.add_argument("--lane-bottom", type=int, default=920)
    args=parser.parse_args()
    if args.check:
        unit, human, radius = read_scale()
        assert unit == 80.0 and human == 2.5 and radius == 0.30
        example = plan(1600,1000,540,780,600,920,1070)
        vertical = plan(1600,1000,800,780,600,920,1070, "vertical")
        mixed = plan(1600,1000,800,780,600,920,1070, "mixed")
        assert vertical["orientation"] == "vertical"
        assert mixed["orientation"] == "mixed"
        assert vertical["actor_height_px"] == example["actor_height_px"]
        assert vertical["radius_px"] == example["radius_px"]
        assert example["actor_height_px"] == 200
        assert example["radius_px"] == 24
        assert example["door_height_px"] == 280
        try:
            plan(1600,1000,540,780,810,920,1070)
        except ValueError:
            pass
        else:
            raise AssertionError("invalid walkable band was accepted")
        try:
            plan(1600, 1000, 540, 780, 600, 920, 1070, "vertical")
        except ValueError:
            pass
        else:
            raise AssertionError("vertical guide accepted feet outside the walkable corridor")
        print("WORLD_MAP_SCALE_GUIDE_PASS: all orientations, 1u=80px, actor=200px, radius=24px")
        return 0
    foot_x = args.foot_x if args.foot_x is not None else (
        (args.lane_left + args.lane_right)//2
        if args.orientation != "horizontal" else 540)
    spec=plan(args.width,args.height,foot_x,args.foot_y,
              args.ground_top,args.ground_bottom,args.door_x,
              args.orientation,args.lane_left,args.lane_right,
              args.lane_top,args.lane_bottom)
    print(f"Reference 1u={spec['pixels_per_unit']:g}px, actor={spec['actor_height_px']}px, "
          f"ground depth={(args.ground_bottom-args.ground_top)/spec['pixels_per_unit']:.2f}u")
    if args.width != 1600 or args.height != 1000:
        print("WARNING: current story and layer pipeline requires 1600x1000 per zone; "
              "nonstandard canvas is guide-only until camera/streaming support ships.")
    if args.output:
        render(spec,args.output)
    else:
        parser.error("use --output to write a reference or --check to run assertions")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
