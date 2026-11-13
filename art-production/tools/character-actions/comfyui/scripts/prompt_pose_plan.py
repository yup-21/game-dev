"""Validate and draw an external AI-authored joint plan, without interpreting text.

The language model authors JSON separately. This compiler has no action lookup,
pose library, character-image input, image analysis, inference or remote calls.
All 18 joints are explicit [x,y] body-height units relative to O (+y down).
Feet describe intended heel/sole/toe geometry separately from COCO ankles.
"""
from __future__ import annotations

import copy
import hashlib
import io
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw
from video_pose_template import COLORS, LIMBS, NAMES

SCHEMA = 'prompt-pose-plan/v1'
BONES = [(NAMES[a], NAMES[b]) for a, b in LIMBS]


def _require(condition, message):
    if not condition:
        raise ValueError(message)


def _number(value):
    return type(value) in (int, float) and math.isfinite(value)


def _point(value, label):
    _require(isinstance(value, list) and len(value) == 2 and all(_number(x) for x in value), f'{label}: expected two finite numbers')
    return value


def _text(value, label):
    _require(isinstance(value, str) and bool(value.strip()), f'{label}: nonempty text required')


def validate_pose_plan(plan, prompt):
    """Reject malformed plans; return a detached validated copy, without files."""
    _require(isinstance(plan, dict) and plan.get('schema_version') == SCHEMA, 'Unsupported pose plan schema_version')
    _text(prompt, 'prompt')
    _require(plan.get('source_prompt') == prompt, 'Pose plan source_prompt does not match the exact requested prompt')
    _require(plan.get('source_prompt_sha256') == hashlib.sha256(prompt.encode('utf-8')).hexdigest(), 'Pose plan source_prompt_sha256 mismatch')
    _require(str(plan.get('prompt_planner', '')).startswith('AI authored'), 'prompt_planner must identify the AI-authored external plan')
    _require(plan.get('coordinate_system') == 'body_height_relative_to_origin', 'Unsupported coordinate_system')
    _require(plan.get('facing') in ('right', 'left'), 'facing must be right or left')
    _require(type(plan.get('loop')) is bool, 'loop must be a boolean')
    _require('no_flight' not in plan or type(plan['no_flight']) is bool, 'no_flight must be a boolean when supplied')
    _text(plan.get('frame_count_reason'), 'frame_count_reason')
    _text(plan.get('loop_policy'), 'loop_policy')
    _require(not any(k in plan for k in ('original_sha256', 'character_image', 'source_image', 'identity_reference')), 'Pose planning must be independent of character-image inputs')
    frames = plan.get('frames')
    _require(isinstance(frames, list) and 1 <= len(frames) <= 256, 'frames must contain 1..256 authored poses')
    end_contract = plan.get('end_contract')
    _require(end_contract is None or end_contract in ('loop', 'return_to_guard', 'hold_defeat', 'hold_pose'), 'Unknown end_contract')
    if end_contract == 'return_to_guard':
        _require(plan['loop'] is False and len(frames) >= 3, 'A genuine guard return needs a nonlooping action with intermediate poses')
        _require(all(frames[-1].get(key) == frames[0].get(key) for key in ('joints_coco18', 'feet', 'weapon')),
                 'return_to_guard must restore the initial authored guard geometry and equipment')
    declared = plan.get('bone_lengths')
    expected_bones = {a + ':' + b for a, b in BONES}
    _require(isinstance(declared, dict) and set(declared) == expected_bones, 'bone_lengths must declare every COCO18 bone and no unknown bone')
    _require(all(_number(x) and x > 0 for x in declared.values()), 'bone_lengths must be finite and positive')
    tolerance = plan.get('bone_length_tolerance', .002)
    _require(_number(tolerance) and 0 <= tolerance <= .005, 'bone_length_tolerance must be within 0..0.005 body heights')
    elapsed, ids, signatures = 0, set(), set()
    for index, frame in enumerate(frames):
        _require(isinstance(frame, dict), f'frame {index}: object required')
        fid = frame.get('id')
        _require(isinstance(fid, str) and fid and all(c.isascii() and (c.isalnum() or c in '_-') for c in fid) and fid not in ids, f'frame {index}: unique safe id required')
        ids.add(fid)
        _require(frame.get('frame_index') == index and type(frame.get('frame_index')) is int, f'{fid}: frame_index must be contiguous from zero')
        duration, start = frame.get('duration_ms'), frame.get('time_ms')
        _require(_number(duration) and duration > 0 and _number(start) and start == elapsed, f'{fid}: positive duration_ms and contiguous time_ms required')
        elapsed += duration
        _require(frame.get('role') in ('key', 'inbetween'), f'{fid}: role must be key or inbetween')
        for field in ('phase', 'pose_description', 'support_contact', 'center_of_mass', 'weapon_trajectory', 'transition'):
            _text(frame.get(field), f'{fid}.{field}')
        contract = frame.get('pose_contract')
        _require(isinstance(contract, dict), f'{fid}: pose_contract required')
        for part in ('head', 'torso', 'pelvis', 'limbs'):
            _text(contract.get(part), f'{fid}.pose_contract.{part}')
        _point(frame.get('root_offset'), f'{fid}.root_offset')
        _require(frame['root_offset'] == [0, 0], f'{fid}: local pose PNG must not bake world displacement')
        _require(not frame.get('source_image'), f'{fid}: source_image cannot replace an authored action pose')
        points = frame.get('joints_coco18')
        _require(isinstance(points, dict) and set(points) == set(NAMES), f'{fid}: exactly the 18 known COCO joints are required; unknown/missing joint')
        for name, value in points.items():
            _point(value, f'{fid}.{name}')
        for a, b in BONES:
            length = math.dist(points[a], points[b])
            _require(length > 0 and abs(length - declared[a + ':' + b]) <= tolerance, f'{fid}: bone length mismatch {a}:{b}')
        signature = json.dumps(points, sort_keys=True)
        boundary_return = (end_contract == 'return_to_guard' and index == len(frames)-1
                           and signature == json.dumps(frames[0]['joints_coco18'], sort_keys=True))
        _require(signature not in signatures or boundary_return, f'{fid}: duplicated pose; do not pad frames or repeat loop closure')
        signatures.add(signature)
        feet = frame.get('feet')
        _require(isinstance(feet, dict) and set(feet) == {'right', 'left'}, f'{fid}: right and left foot geometry required')
        for side, foot in feet.items():
            _require(isinstance(foot, dict) and foot.get('contact') in ('none', 'heel', 'sole', 'toe'), f'{fid}: invalid {side} foot contact')
            for part in ('heel', 'sole', 'toe'):
                _point(foot.get(part), f'{fid}.{side}.{part}')
                _require(foot[part][1] <= 1e-6, f'{fid}: planned {side} {part} penetrates the ground')
            _require(math.dist(points[side + '_ankle'], foot['sole']) >= .01, f'{fid}: ankle is not the intended shoe sole')
            if foot['contact'] != 'none':
                _require(abs(foot[foot['contact']][1]) <= 1e-6, f'{fid}: declared foot contact must lie on O ground baseline y=0')
        if plan.get('no_flight'):
            _require(any(f['contact'] != 'none' for f in feet.values()), f'{fid}: walking plan must retain intended ground contact')
        weapon = frame.get('weapon')
        if weapon is not None:
            _require(isinstance(weapon, dict) and weapon.get('grip_joint') in ('right_wrist', 'left_wrist'), f'{fid}: weapon grip must name a wrist; weapon is separate from body joints')
            _point(weapon.get('direction'), f'{fid}.weapon.direction')
            _require(math.hypot(*weapon['direction']) > 0, f'{fid}: weapon direction cannot be zero')
            if 'length_body_heights' in weapon:
                _require(_number(weapon['length_body_heights']) and weapon['length_body_heights'] > 0, f'{fid}: positive weapon length required')
            if 'projection_scale' in weapon:
                _require(_number(weapon['projection_scale']) and 0 <= weapon['projection_scale'] <= 1,
                         f'{fid}: weapon projection_scale must be within 0..1')
        for name, point in frame.get('body_contact_points', {}).items():
            _text(name, f'{fid}: body contact name')
            _point(point, f'{fid}: body contact {name}')
            _require(abs(point[1]) <= 1e-6, f'{fid}: planned body contact must lie on ground')
        if 'world_root_offset_m' in frame:
            _point(frame['world_root_offset_m'], f'{fid}: world_root_offset_m')
            _require(index != 0 or frame['world_root_offset_m'] == [0,0], 'World movement plan must start at zero')
    _require(_number(plan.get('duration_ms')) and plan['duration_ms'] == elapsed, 'duration_ms must equal the sum of frame durations')
    return copy.deepcopy(plan)


def load_pose_plan(plan_path, prompt):
    return validate_pose_plan(json.loads(Path(plan_path).read_text('utf-8-sig')), prompt)


def _immutable_png(image, path):
    stream = io.BytesIO()
    image.save(stream, format='PNG')
    payload = stream.getvalue()
    if path.exists():
        _require(path.read_bytes() == payload, f'Existing pose differs: {path}; use a new candidate directory')
    else:
        path.write_bytes(payload)


def prepare_pose_plan(plan_path, prompt, canvas, origin, target_height, poses_dir):
    """Compile an explicit external plan into Comfy-compatible motion + PNGs.

    target_height is the shared body height in pixels, never a per-frame fit.
    The returned pose paths are relative to poses_dir.parent (usually poses/).
    Validation and canvas checks finish before creating any output files.
    """
    plan = load_pose_plan(plan_path, prompt)
    _require(isinstance(canvas, (list, tuple)) and len(canvas) == 2 and all(type(x) is int and x > 16 for x in canvas), 'canvas needs two positive integer dimensions')
    _require(isinstance(origin, (list, tuple)) and len(origin) == 2 and all(type(x) is int and 0 <= x < bound for x, bound in zip(origin, canvas)), 'origin needs two integer pixel coordinates inside canvas')
    _require(_number(target_height) and target_height > 0, 'target_height must be finite positive pixels')
    target = Path(poses_dir)
    def pixel(point):
        return [round(origin[i] + target_height * point[i], 6) for i in (0, 1)]
    frames = []
    for source in plan['frames']:
        points = {name: pixel(source['joints_coco18'][name]) for name in NAMES}
        for name, point in points.items():
            _require(all(8 <= x <= bound - 9 for x, bound in zip(point, canvas)), f"{source['id']}: {name} exceeds pose-guide safe area")
        feet = {side: {**foot, **{part: pixel(foot[part]) for part in ('heel', 'sole', 'toe')}} for side, foot in source['feet'].items()}
        for side, foot in feet.items():
            for part in ('heel', 'sole', 'toe'):
                _require(all(8 <= x <= bound - 9 for x, bound in zip(foot[part], canvas)), f"{source['id']}: {side} {part} exceeds pose-guide safe area")
        frame = {k: copy.deepcopy(v) for k, v in source.items() if k not in ('joints_coco18', 'feet')}
        frame.update(pose=f'{target.name}/{source["id"]}.png', pose_control=True,
                     prompt=source['pose_description'], action_id=plan.get('action_id', 'prompt_action'),
                     authored_keypoints_coco18=points, pose_keypoints=[points[n] for n in NAMES],
                     pose_plan_joints_norm=source['joints_coco18'], pose_plan_feet_norm=source['feet'],
                     support_foot_geometry=feet,
                     support_sole_points={side: foot[foot['contact']] for side, foot in feet.items() if foot['contact'] != 'none'},
                     pose_method=plan['prompt_planner'], source_prompt=prompt,
                     logical_origin=list(origin), facing=plan.get('facing', 'right'),
                     actual_support_unverified=True, pose_template_status='authored_candidate',
                     root_offset_method='Local in-place pose; world locomotion is separate from sprite pixels.')
        frame['support_body_points'] = {name: pixel(point) for name, point in source.get('body_contact_points', {}).items()}
        for point in frame['support_body_points'].values():
            _require(all(8 <= x <= bound-9 for x, bound in zip(point, canvas)), f"{source['id']}: body contact exceeds safe area")
        weapon = source.get('weapon')
        if weapon and weapon.get('length_body_heights'):
            norm = math.hypot(*weapon['direction'])
            unit = [x/norm for x in weapon['direction']]
            grip = source['joints_coco18'][weapon['grip_joint']]
            projection = weapon.get('projection_scale', 1)
            tip = [grip[i]+unit[i]*weapon['length_body_heights']*projection for i in (0,1)]
            handle = [grip[i]-unit[i]*.06*projection for i in (0,1)]
            _require(tip[1] <= 1e-6 and handle[1] <= 1e-6, f"{source['id']}: weapon guide penetrates ground")
            geometry = {'grip': pixel(grip), 'tip': pixel(tip), 'handle': pixel(handle),
                        'physical_length_body_heights': weapon['length_body_heights'], 'projection_scale': projection,
                        'role': 'review guide only; not a body-pose model input'}
            for part in ('grip', 'tip', 'handle'):
                _require(all(8 <= x <= bound-9 for x, bound in zip(geometry[part], canvas)), f"{source['id']}: weapon {part} exceeds pose-guide safe area")
            frame['weapon_geometry'] = geometry
        frames.append(frame)
    target.mkdir(parents=True, exist_ok=True)
    # Match the existing 768px OpenPose renderer (4px joint radius / 8px
    # sticks) at the control-canvas scale. Body-height scaling made a native
    # 384px control only 2px wide, losing limb color detail in the VAE.
    radius = max(1, round(min(canvas) / 144))
    for frame in frames:
        image = Image.new('RGB', tuple(canvas), 'black')
        draw = ImageDraw.Draw(image)
        points = frame['pose_keypoints']
        for (a, b), color in zip(LIMBS, COLORS):
            draw.line((tuple(points[a]), tuple(points[b])), fill=tuple(round(c * .6) for c in color), width=radius * 2)
        for (x, y), color in zip(points, COLORS):
            draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=color)
        _immutable_png(image, target / (frame['id'] + '.png'))
    provenance = {'method': 'external_ai_authored_pose_plan', 'source_kind': 'text',
                  'control_render': {'joint_radius_px': radius, 'limb_width_px': radius * 2,
                                     'canvas_scale_basis_px': 576, 'native_canvas': list(canvas)},
                  'prompt_planner': plan['prompt_planner'], 'source_prompt': prompt,
                  'source_prompt_sha256': plan['source_prompt_sha256'],
                  'pose_plan_path': str(Path(plan_path).resolve()),
                  'pose_plan_sha256': hashlib.sha256(Path(plan_path).read_bytes()).hexdigest(),
                  'pose_generation_character_image_dependency': False,
                  'video_used': False, 'previous_generated_frames_used': False,
                  'original_as_first_frame': False, 'automatic_skeleton_extraction': False,
                  'compiler_role': 'Validate and render externally AI-authored coordinates; no prompt classification or pose-library selection.'}
    return {'schema_version': 1, 'name': plan.get('name', 'external_prompt_pose_plan'),
            **{key: copy.deepcopy(plan[key]) for key in ('end_contract', 'rig_id', 'weapon_contract', 'world_motion_units') if key in plan},
            'mode': 'external_ai_authored_pose_plan', 'source_kind': 'text', 'source_prompt': prompt,
            'status': 'candidate; authored intention, no generated-character acceptance',
            'canvas': list(canvas), 'logical_origin': list(origin), 'facing': plan.get('facing', 'right'),
            'duration_ms': plan['duration_ms'], 'pose_control': True, 'pose_templates_available': True,
            'pose_keypoint_names': list(NAMES), 'loop': plan['loop'], 'frames': frames,
            'intro_frame_ids': [], 'loop_frame_ids': [f['id'] for f in frames] if plan['loop'] else [],
            'loop_policy': plan['loop_policy'], 'frame_count_reason': plan['frame_count_reason'],
            'provenance': provenance, 'limitations': ['Planned heel/sole contact is not measured rendered-shoe contact.', 'Body-height coordinates and stable bone lengths do not verify final anatomy, clothing, equipment, Alpha or continuity.']}
