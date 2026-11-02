#!/usr/bin/env python3
"""Turn the authoritative Godot rig contract into measurable art templates.

The generated outlines are *guides*, not approved character art. A painted
transparent RGBA layer must match each guide's canvas and pivot before binding.
"""

from __future__ import annotations
import json
from math import hypot
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
PROTOTYPE = ROOT / "demos/changfeng-battle/prototypes/shen_rig_first"
OUTPUT = ROOT / "demos/changfeng-battle/captures/shen-rig-first/art-templates"
CONTRACT = PROTOTYPE / "rig_contract.json"


def fmt(v: float) -> str:
    return f"{v:.3f}".rstrip("0").rstrip(".") or "0"


def make_polygon(a, b, width, overlap):
    dx, dy = b[0] - a[0], b[1] - a[1]
    distance = hypot(dx, dy)
    if distance < 0.0001:
        # Head and other point-anchored silhouettes use a square guide.
        radius = width / 2
        return [
            (a[0] - radius, a[1] - radius),
            (a[0] + radius, a[1] - radius),
            (a[0] + radius, a[1] + radius),
            (a[0] - radius, a[1] + radius),
        ]
    ux, uy = dx / distance, dy / distance
    nx, ny = -uy, ux
    begin = (a[0] - ux * overlap, a[1] - uy * overlap)
    end = (b[0] + ux * overlap, b[1] + uy * overlap)
    h = width / 2
    return [
        (begin[0] + nx * h, begin[1] + ny * h),
        (end[0] + nx * h, end[1] + ny * h),
        (end[0] - nx * h, end[1] - ny * h),
        (begin[0] - nx * h, begin[1] - ny * h),
    ]


def svg_start(width, height):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {fmt(width)} {fmt(height)}" width="{fmt(width)}" height="{fmt(height)}">\n'


def main() -> None:
    contract = json.loads(CONTRACT.read_text())
    anchors = {item["name"]: item["anchor"] for item in contract["bones"]}
    for group in contract.get("accessories", []):
        anchors.update({bone["name"]: bone["anchor"] for bone in group["bones"]})
    anchors.update({name: marker["anchor"] for name, marker in contract.get("sockets", {}).items()})
    scale = contract["art_source_scale"]
    OUTPUT.mkdir(parents=True, exist_ok=True)
    part_dir = OUTPUT / "per-part-svg"
    part_dir.mkdir(parents=True, exist_ok=True)
    layers = []
    manifest = {
        "actor": contract["actor"],
        "profile": contract["profile"],
        "scale_source_px_per_world_px": scale,
        "foot_anchor_world_px": [0, 0],
        "source": str(CONTRACT.relative_to(ROOT)),
        "core_scene": contract["core_scene"],
        "accessory_scenes": {g["name"]: g["scene"] for g in contract.get("accessories", [])},
        "parts": [],
    }

    for part in contract["parts"]:
        name = part["name"]
        start = anchors[part["segment_start"]]
        end = anchors[part["segment_end"]]
        pivot = anchors[part["attach_to_bone"]]
        polygon = make_polygon(start, end, part["guide_width_px"], part["joint_overlap_px"])
        padding = part["transparent_padding_px"]
        minx = min(p[0] for p in polygon) - padding
        miny = min(p[1] for p in polygon) - padding
        maxx = max(p[0] for p in polygon) + padding
        maxy = max(p[1] for p in polygon) + padding
        # Source RGBA canvas and pivot are exact shared-scale integers.
        left = int(minx // 1)
        top = int(miny // 1)
        right = int(-(-maxx // 1))
        bottom = int(-(-maxy // 1))
        w, h = right - left, bottom - top
        transform = lambda xy: (fmt((xy[0] - left) * scale), fmt((xy[1] - top) * scale))
        points = " ".join(",".join(transform(point)) for point in polygon)
        px, py = transform(pivot)
        svg = svg_start(w * scale, h * scale)
        svg += f'  <polygon points="{points}" fill="#79c8dc" fill-opacity=".14" stroke="#157eab" stroke-width="{scale}"/>\n'
        svg += f'  <circle cx="{px}" cy="{py}" r="{3*scale}" fill="#df9d37"/>\n'
        svg += f'  <circle cx="{px}" cy="{py}" r="{1*scale}" fill="#ffffff"/>\n</svg>\n'
        (part_dir / (name + ".svg")).write_text(svg)
        manifest["parts"].append({
            "name": name,
            "attach_to_bone": part["attach_to_bone"],
            "rig_group": part.get("rig_group", "body"),
            "z_index": part["z_index"],
            "source_canvas_size_px": [w * scale, h * scale],
            "pivot_in_source_canvas_px": [float(px), float(py)],
            "canvas_top_left_in_world_px": [left, top],
            "guide_width_world_px": part["guide_width_px"],
            "joint_overlap_world_px": part["joint_overlap_px"],
            "transparent_padding_world_px": padding,
            "production_state": "candidate",
            "template_svg": "per-part-svg/" + name + ".svg",
        })
        shifted = " ".join(f"{fmt(x+130)},{fmt(y+228)}" for x,y in polygon)
        layers.append(f'  <g id="{escape(name)}"><polygon points="{shifted}" fill="#4fa2bf" fill-opacity=".09" stroke="#2784a8" stroke-opacity=".55" stroke-width=".65"/></g>')

    # Shared full-body transparent vector template in rig/world coordinates.
    full = svg_start(335, 275)
    full += '  <g id="art-attachment-guides">\n' + "\n".join(layers) + '\n  </g>\n'
    full += '  <g id="authoritative-bones" fill="none" stroke="#2a82b5" stroke-width="1.5">\n'
    for bone in contract["bones"]:
        if bone["parent"] is not None:
            x, y = anchors[bone["name"]]
            a, b = anchors[bone["parent"]]
            full += f'    <path d="M {fmt(a+130)} {fmt(b+228)} L {fmt(x+130)} {fmt(y+228)}"/>\n'
    full += '  </g>\n  <g id="decoration-skeletons" fill="none" stroke="#d59632" stroke-width="1.25">\n'
    for group in contract.get("accessories", []):
        for bone in group["bones"]:
            x, y = bone["anchor"]
            parent = bone["parent"] or group["parent_bone"]
            a, b = anchors[parent]
            full += f'    <path d="M {fmt(a+130)} {fmt(b+228)} L {fmt(x+130)} {fmt(y+228)}"/>\n'
    full += '  </g>\n  <g id="weapon-markers" stroke="#adb4c0" stroke-width="1.4">\n'
    for name, marker in contract.get("sockets", {}).items():
        x, y = marker["anchor"]
        a, b = anchors[marker["parent"]]
        full += f'    <path d="M {fmt(a+130)} {fmt(b+228)} L {fmt(x+130)} {fmt(y+228)}"/>\n'
    full += '  </g>\n  <g fill="#e8a53f">\n'
    for bone in contract["bones"]:
        x, y = bone["anchor"]
        full += f'    <circle cx="{fmt(x+130)}" cy="{fmt(y+228)}" r="2.3"/>\n'
    full += '  </g>\n  <path d="M 20 228 H 320" stroke="#42a46f" stroke-width="1.5"/>\n</svg>\n'
    (OUTPUT / "master-rig-template.svg").write_text(full)
    (OUTPUT / "art_frames.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    assert len(manifest["parts"]) == 20
    print(f"SHEN_RIG_ART_TEMPLATE_OK parts={len(manifest['parts'])} root={OUTPUT}")


if __name__ == "__main__":
    main()
