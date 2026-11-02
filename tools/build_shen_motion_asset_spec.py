#!/usr/bin/env python3
"""Freeze a paint-ready cutout contract *after* body motion authoring.

Body parts are never extracted by cropping a full posed character.
Every transparent layer is drawn against its own Bone2D canvas/pivot.
"""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/"demos/changfeng-battle/captures/shen-rig-first/art-templates"
RIG=ROOT/"demos/changfeng-battle/prototypes/shen_rig_first/rig_contract.json"
MANDATORY={
    "head","torso","pelvis",
    "upper_arm_front","forearm_front","hand_front",
    "upper_arm_back","forearm_back","hand_back",
    "thigh_front","shin_front","boot_front",
    "thigh_back","shin_back","boot_back","sword",
}
FRAMES={"idle":[1],"walk":[2,3,4,5],"attack_sword":[6,7,8]}

def main():
    spec=json.loads(RIG.read_text())
    frames=json.loads((BASE/"art_frames.json").read_text())
    source={part["name"]:part for part in spec["parts"]}
    prepared=[]
    seen=set()
    for item in frames["parts"]:
        name=item["name"]
        if name in seen:
            raise SystemExit("Duplicate part "+name)
        seen.add(name)
        original=source[name]
        px,py=item["pivot_in_source_canvas_px"]
        w,h=item["source_canvas_size_px"]
        # A pivot can be outside the image on deliberately extended accessory
        # strips, but it must remain in the shared source/art coordinate frame.
        if not (w>0 and h>0 and abs(px)<w*4 and abs(py)<h*4):
            raise SystemExit("Invalid art canvas/pivot for "+name)
        prepared.append({
            "part":name,
            "group":item.get("rig_group","body"),
            "bone":item["attach_to_bone"],
            "segment_from":original["segment_start"],
            "segment_to":original["segment_end"],
            "canvas_px":item["source_canvas_size_px"],
            "pivot_px":item["pivot_in_source_canvas_px"],
            "overlap_world_px":item["joint_overlap_world_px"],
            "transparent_padding_world_px":item["transparent_padding_world_px"],
            "z_index":item["z_index"],
            "template":item["template_svg"],
            "required":name in MANDATORY,
            "status":"candidate",
            "png_present":False,
        })
    missing=sorted(MANDATORY-seen)
    if missing:
        raise SystemExit("Missing joint-separated critical parts: "+str(missing))
    if "attack_swing" in seen or "guard_arms" in seen:
        raise SystemExit("Composite arm/weapon cutouts are not permitted")
    output={
        "version":1,
        "actor":"shen_changfeng",
        "coordinate_frame":"rig_rest_pose / right-facing / ground (0,0)",
        "source_scale":4,
        "reference_atlas":"art-production/candidates/2026-11-01/shen_changfeng/sprite_shen_changfeng_atlas_normalized_v02.png",
        "reference_frame_indices":FRAMES,
        "core_scene":"res://prototypes/humanoid_rig/humanoid_side_core.tscn",
        "standalone_decorations":frames["accessory_scenes"],
        "animation_stage":"motion-first candidate; no new painted cutouts approved",
        "requirements":{
            "one_transparent_rgba_png_per_bone_segment":True,
            "all_hidden_joint_regions_fully_painted":True,
            "shoulder_elbow_knee_ankle_overlap_required":True,
            "weapon_png_separate_from_hand_png":True,
            "same_source_scale_and_world_origin_for_every_part":True,
            "do_not_crop_out_pivot_padding":True,
            "all_actions_share_a_single_bind_pose":True,
            "accessory_skeletons_optional":True,
        },
        "parts":prepared,
    }
    BASE.joinpath("required-parts.json").write_text(json.dumps(output,ensure_ascii=False,indent=2)+"\n")
    print("SHEN_MOTION_ASSET_SPEC_OK parts=%d mandatory=%d" %(len(prepared),len(MANDATORY)))

if __name__=="__main__":
    main()
