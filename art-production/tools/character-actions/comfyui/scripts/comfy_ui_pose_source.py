"""CPU-only source preparation for the native ComfyUI action-source node.

No service, diffusion, character-image pose extraction or generated-frame feedback.
Successful batches are immutable and all prepared bytes are checked on reuse.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from datetime import date
from pathlib import Path
import re
import shutil
import uuid

from PIL import Image, ImageDraw

from character_action_paths import AI_POSE_PLANS, BUNDLE
import generate_prompt_pose_plan as planner
import prompt_pose_plan as plans
import video_pose_template as video_poses

SCHEMA = 'comfy-ui-pose-source/v1'
MAX_SOURCE_FRAMES = 256
FEEDBACK_KEYS = {'init_image', 'source_image', 'source_frames', 'feedback', 'previous_frame', 'previous_frame_image'}


def _require(ok, message):
    if not ok:
        raise ValueError(message)


def _sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def _json(path):
    return json.loads(Path(path).read_text('utf-8-sig'))


def _dump(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', 'utf-8')


def _reject_feedback(value, label='input motion'):
    if isinstance(value, dict):
        for key, child in value.items():
            _require(key not in FEEDBACK_KEYS or child in (None, False, '', [], {}),
                     f'{label}.{key}: image initialization/source-frame feedback is forbidden')
            _reject_feedback(child, f'{label}.{key}')
    elif isinstance(value, list):
        for index, child in enumerate(value):
            _reject_feedback(child, f'{label}[{index}]')


def _child(base, value):
    """A manifest only grants access to regular descendants, never links."""
    _require(isinstance(value, str) and value, 'manifest pose path is required')
    relative = Path(value)
    _require(not relative.is_absolute() and '..' not in relative.parts,
             'manifest pose path must remain inside its parent directory')
    base = Path(base).resolve()
    child = base / relative
    for parent in [child, *child.parents]:
        if parent == base:
            break
        _require(not parent.is_symlink() and not parent.is_junction(), 'manifest symlink/junction is forbidden')
    _require(child.resolve().is_relative_to(base), 'manifest pose escaped parent directory')
    _require(child.is_file(), f'missing manifest pose: {child}')
    return child.resolve()


def _input_files(path):
    path = Path(path).absolute()
    _require(path.exists(), f'missing input: {path}')
    if path.is_dir():
        files = sorted(path.rglob('*'))
        _require(all(not p.is_symlink() and not p.is_junction() for p in [path, *files]),
                 'input directory symlinks/junctions are forbidden')
        return {str(p.resolve()): _sha(p) for p in files if p.is_file()}
    result = {str(path.resolve()): _sha(path)}
    if path.suffix.lower() == '.json':
        doc = _json(path)
        if doc.get('schema_version') != plans.SCHEMA:
            for frame in doc.get('frames', []):
                pose = _child(path.parent, frame.get('pose'))
                result[str(pose)] = _sha(pose)
    return result


def _rgb_pose(path, size):
    with Image.open(path) as image:
        _require(image.format == 'PNG' and image.mode == 'RGB', f'pose must be an RGB PNG: {path}')
        _require(image.size == size, f'native pose canvas mismatch: {image.size}, expected {size}; resizing is forbidden')
        _require(all(image.getpixel(p) == (0, 0, 0) for p in
                     ((0, 0), (size[0]-1, 0), (0, size[1]-1), (size[0]-1, size[1]-1))),
                 'pose PNG requires a black background')


def _reference(character, target):
    with Image.open(character) as image:
        image = image.convert('RGBA')
        scale = min(768 / image.width, 768 / image.height)
        image = image.resize((max(1, round(image.width*scale)), max(1, round(image.height*scale))), Image.Resampling.LANCZOS)
        canvas = Image.new('RGB', (768, 768), (24, 26, 26))
        canvas.paste(image, ((768-image.width)//2, (768-image.height)//2), image)
        canvas.save(target)
    return 'original_once_isotropic_fit_and_darkcharcoal_padding'


def _prompt(identity, equipment, local):
    return ('refcontrol, apply the body pose from image 1. '
            'Repose the character from image 2 in strict right-facing side view. '
            f'{identity} Equipment: {equipment}. Current pose: {local} '
            'Keep the original face, costume, materials and lighting. Fixed camera, scale and ground baseline; '
            'body pose moves around the same ground root. Complete character and equipment, plain background.')


def _draw_points(points, target, size):
    radius = max(1, round(min(size) / 144))
    image = Image.new('RGB', size, 'black')
    draw = ImageDraw.Draw(image)
    for (a, b), color in zip(video_poses.LIMBS, video_poses.COLORS):
        if min(points[a][2], points[b][2]) >= .2:
            draw.line((tuple(points[a][:2]), tuple(points[b][:2])), fill=tuple(round(c*.6) for c in color), width=2*radius)
    for point, color in zip(points, video_poses.COLORS):
        x, y, confidence = point
        if confidence >= .2:
            _require(8+radius <= x <= size[0]-9-radius and 8+radius <= y <= size[1]-9-radius,
                     'video pose has insufficient canvas margins under the shared transform')
            draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=color)
    image.save(target)


def _text_frames(root, action_text, duration_ms, pose_path, size, origin, height_m):
    if pose_path:
        source = Path(pose_path).resolve()
    else:
        audit = []
        global_plans = AI_POSE_PLANS
        record = {'global_cache': str(global_plans), 'checks': audit}
        try:
            source = planner.find_cached_plan(action_text, global_plans, duration_ms, audit=audit)
            if source is None:
                global_plans.mkdir(parents=True, exist_ok=True)
                target = global_plans / f'ui_{uuid.uuid4().hex}.json'
                record['requested_plan'] = str(target)
                source = planner.generate_plan(action_text, target, duration_ms=duration_ms)
            record['selected_plan'] = str(Path(source).resolve())
        finally:
            _dump(root / 'planner-cache-check.json', record)
    plan = plans.load_pose_plan(source, action_text)
    _require(plan['duration_ms'] == duration_ms, 'pose plan duration does not match request')
    if Path(source).resolve() != (root / 'source-plan.json').resolve():
        shutil.copyfile(source, root / 'source-plan.json')
    motion = plans.prepare_pose_plan(root / 'source-plan.json', action_text, size, origin,
                                     round(height_m*100), root / 'poses')
    _dump(root / 'motion.json', motion)
    return [{**frame, 'pose': str(root / frame['pose']),
             'planned_points': frame['authored_keypoints_coco18']} for frame in motion['frames']]


def _pose_frames(root, source, action_text, duration_ms, size, origin, height_m):
    source = Path(source).resolve()
    if source.suffix.lower() == '.json' and source.is_file():
        doc = _json(source)
        _reject_feedback(doc)
        if doc.get('schema_version') == plans.SCHEMA:
            return _text_frames(root, action_text or doc.get('source_prompt'), duration_ms, source, size, origin, height_m)
        records = doc.get('frames')
        _require(isinstance(records, list) and records, 'motion.json must contain ordered frames')
        frames = [{**f, 'input_pose': _child(source.parent, f.get('pose'))} for f in records]
    else:
        paths = ([source] if source.is_file() else sorted(p for p in source.iterdir()
                 if p.is_file() and p.suffix.lower() == '.png' and 'neutral' not in p.stem.lower()))
        _require(paths, 'pose source contains no action RGB PNGs')
        if source.is_dir():
            _require(all(p.suffix.lower() == '.png' for p in source.iterdir() if p.is_file()),
                     'pose directory must contain only RGB skeleton PNGs')
        frames = [{'input_pose': p} for p in paths]
    (root / 'poses').mkdir(exist_ok=True)
    output = []
    count = len(frames)
    _require(count <= MAX_SOURCE_FRAMES,
             f'pose source contains {count} frames, exceeding safety limit={MAX_SOURCE_FRAMES}; '
             'authored poses cannot be silently truncated')
    _require(duration_ms >= count, 'duration_ms must allow at least one millisecond per pose')
    for i, frame in enumerate(frames):
        source_pose = frame.pop('input_pose')
        _rgb_pose(source_pose, size)
        target = root / 'poses' / f'frame_{i:04d}.png'
        shutil.copyfile(source_pose, target)
        duration = frame.get('duration_ms', round((i+1)*duration_ms/count)-round(i*duration_ms/count))
        _require(type(duration) in (int, float) and math.isfinite(duration) and duration >= 1,
                 'frame duration_ms must be positive')
        points = frame.get('planned_points') or frame.get('authored_keypoints_coco18')
        if points is None and frame.get('keypoints'):
            points = {n: p[:2] for n, p in zip(video_poses.NAMES, frame['keypoints'])}
        if points is None and frame.get('pose_keypoints'):
            points = {n: p[:2] for n, p in zip(video_poses.NAMES, frame['pose_keypoints'])}
        if points is not None:
            _require(isinstance(points, dict) and set(points) == set(video_poses.NAMES),
                     'motion planned points must contain exactly 18 COCO joints')
            _require(all(isinstance(p, (list,tuple)) and len(p) == 2
                         and all(type(v) in (int,float) and math.isfinite(v) for v in p)
                         and all(0 <= v < bound for v,bound in zip(p,size)) for p in points.values()),
                     'motion planned points must be finite coordinates inside the native canvas')
        output.append({**frame, 'id': f'frame_{i:04d}', 'frame_index': i, 'pose': str(target),
                       'duration_ms': round(duration), 'planned_points': points,
                       'original_pose': str(source_pose), 'original_pose_sha256': _sha(source_pose)})
    return output


def _video_frames(root, video_path, duration_ms, max_frames, start, end, size, origin):
    directory = root / 'video-extraction'
    args = argparse.Namespace(video=Path(video_path), output=directory, duration=duration_ms/1000,
                              start=start, end=end or None, max_keyframes=max_frames, analysis_fps=12.,
                              max_analysis_frames=1500, change_threshold=.09, max_gap=.9,
                              confidence=.2, threads=4, roi=None, model=None, deps_dir=None, neutral_pose=None)
    video_poses.run(args)
    motion = _json(directory / 'motion.json')
    _require(motion.get('canvas') == [768, 768], 'video extraction must provide a 768 canvas')
    scale = min(size[0]/768, size[1]/768)
    (root / 'poses').mkdir(exist_ok=True)
    output = []
    for index, frame in enumerate(motion['frames']):
        raw = frame['keypoints']
        _require(len(raw) == 18 and all(len(p) == 3 and all(math.isfinite(v) for v in p) for p in raw),
                 'video inference must provide 18 finite COCO points')
        # A missing observation is not an observed pixel at (0, 0). Preserve
        # the detector's missing-point semantics across the affine mapping.
        points = [[round(origin[0]+(x-342)*scale, 6), round(origin[1]+(y-700)*scale, 6), c]
                  if c >= .2 else [0, 0, c] for x, y, c in raw]
        target = root / 'poses' / f'frame_{index:04d}.png'
        _draw_points(points, target, size)
        output.append({**frame, 'pose': str(target), 'planned_points': {n: p[:2] for n, p in zip(video_poses.NAMES, points)},
                       'keypoints': points, 'shared_transform': {'scale': scale, 'old_origin': [342,700], 'origin': list(origin)}})
    return output


def _cached(root, source_key):
    manifest = root / 'manifest.json'
    _require(not (root / 'failed.json').exists() and manifest.is_file(),
             'frozen cache has a failed marker or incomplete manifest; refusing reuse or retry')
    receipt = root / 'manifest.sha256'
    _require(receipt.is_file() and receipt.read_text('ascii').strip() == _sha(manifest), 'cache manifest SHA mismatch')
    doc = _json(manifest)
    _require(doc.get('source_key') == source_key and doc.get('schema') == SCHEMA, 'cache source key mismatch')
    for relative, expected in doc['files'].items():
        path = _child(root, relative)
        _require(_sha(path) == expected, f'cache file SHA mismatch: {relative}')
    result = doc['result']
    _require(Path(result['root']).resolve() == root.resolve(), 'cache root mismatch')
    return result


def _cache_attempts(source_key):
    """Preserve failed/interrupted attempts; validate every frozen cache before reuse."""
    name = f'comfy_ui_{source_key}'
    pattern = re.compile(re.escape(name) + r'(?:__attempt_([0-9]{4,}))?')
    attempts = []
    successful = []
    for root in sorted((BUNDLE / 'outputs').glob(f'*/{name}*')):
        match = pattern.fullmatch(root.name)
        if not match:
            continue
        _require(root.is_dir() and not root.is_symlink() and not root.is_junction(),
                 'source cache must be a regular directory')
        attempts.append(int(match.group(1) or 1))
        if (root / 'manifest.json').exists() or (root / 'manifest.sha256').exists():
            # A damaged successful cache must never be downgraded to a failed
            # attempt, even if someone adds a failed marker afterwards.
            successful.append(_cached(root, source_key))
        elif (root / 'failed.json').exists():
            failed = _json(root / 'failed.json')
            _require(failed.get('status') == 'failed' and failed.get('source_key') == source_key,
                     'failed cache marker does not match source request')
        # No manifest, receipt or failed marker means preparation was interrupted.
        # Keep the entire directory and prepare a new attempt rather than resume it.
    _require(len(successful) <= 1, 'multiple source caches exist; refusing ambiguous reuse')
    if successful:
        return successful[0], None
    suffix = f'__attempt_{max(attempts) + 1:04d}' if attempts else ''
    return None, name + suffix


def prepare_source(*, mode, character_path, action_text='', video_path=None, pose_path=None,
                   height_m=1.8, width=384, height=288, origin=(171, 256), duration_ms=2000,
                   max_frames=16, video_start=0, video_end=0, identity_description='', weapon_description=''):
    """Freeze/reuse a source; max_frames bounds text/video, pose imports all <=256 frames."""
    _require(mode in ('text', 'video', 'pose'), 'mode must be text, video or pose')
    _require(type(width) is int and type(height) is int and width >= 32 and height >= 32
             and width % 16 == 0 and height % 16 == 0, 'native canvas must use positive multiples of 16; 328 is unsupported')
    _require(isinstance(origin, (tuple,list)) and len(origin) == 2
             and all(type(x) is int and 0 <= x < bound for x,bound in zip(origin,(width,height))), 'origin must be inside canvas')
    _require(type(height_m) in (int,float) and math.isfinite(height_m) and 1 <= height_m <= 2.2, 'height_m must be within 1..2.2')
    _require(type(duration_ms) in (int,float) and math.isfinite(duration_ms) and duration_ms >= 1 and duration_ms == round(duration_ms),
             'duration_ms must be a positive whole millisecond count')
    _require(type(max_frames) is int and 1 <= max_frames <= 256, 'max_frames must be within 1..256')
    _require(all(type(v) in (int,float) and math.isfinite(v) and v >= 0 for v in (video_start, video_end))
             and (not video_end or video_end > video_start), 'invalid video window')
    _require(mode != 'text' or isinstance(action_text,str) and bool(action_text.strip()), 'text mode needs the complete action text')
    _require(mode != 'video' or video_path, 'video mode needs video_path')
    _require(mode != 'pose' or pose_path, 'pose mode needs pose_path')
    character = Path(character_path).resolve()
    _require(character.is_file(), 'character_path must be an original image file')
    inputs = _input_files(character)
    for path in (video_path, pose_path):
        if path:
            inputs.update(_input_files(path))
    code = {p.name: _sha(p) for p in (Path(__file__).resolve(), Path(planner.__file__), Path(plans.__file__),
                                    Path(video_poses.__file__))}
    request = dict(mode=mode, action_text=action_text, height_m=height_m, width=width, height=height,
                   origin=list(origin), duration_ms=duration_ms, max_frames=max_frames, video_start=video_start,
                   video_end=video_end, identity_description=identity_description, weapon_description=weapon_description,
                   inputs=inputs, code=code)
    source_key = hashlib.sha256(json.dumps(request, ensure_ascii=False, sort_keys=True).encode()).hexdigest()
    # Search previous dates as well: an unchanged request reuses the frozen batch.
    cached, attempt_name = _cache_attempts(source_key)
    if cached is not None:
        return cached
    root = BUNDLE / 'outputs' / date.today().isoformat() / attempt_name
    root.mkdir(parents=True, exist_ok=False)
    _dump(root / 'request.json', request)
    try:
        if mode == 'text':
            frames = _text_frames(root, action_text, duration_ms, pose_path, (width,height), origin, height_m)
        elif mode == 'pose':
            frames = _pose_frames(root, pose_path, action_text, duration_ms, (width,height), origin, height_m)
        else:
            frames = _video_frames(root, video_path, duration_ms, max_frames, video_start, video_end, (width,height), origin)
        _require(frames, 'source contains no frames')
        _require(len(frames) <= MAX_SOURCE_FRAMES,
                 f'{mode} source contains {len(frames)} frames, exceeding safety limit={MAX_SOURCE_FRAMES}; '
                 'authored poses cannot be silently truncated')
        _require(mode == 'pose' or len(frames) <= max_frames,
                 f'{mode} source contains {len(frames)} frames, exceeding max_frames={max_frames}; '
                 'raise the explicit limit; authored poses cannot be silently truncated')
        identity = identity_description.strip() or 'Preserve the character identity exactly as reference.'
        equipment = weapon_description.strip() or 'as reference; preserve the original equipment and count'
        for index, frame in enumerate(frames):
            _rgb_pose(frame['pose'], (width,height))
            frame.update(frame_index=index, duration_ms=round(frame['duration_ms']),
                         prompt=_prompt(identity, equipment, frame.get('pose_description') or frame.get('prompt') or 'Match the supplied body-pose control.'))
        reference = root / 'identity_reference.png'
        reference_policy = _reference(character, reference)
        _dump(root / 'audit.json', {'status': 'candidate', 'original_as_first_frame': False,
              'original_used_to_infer_text_pose': False, 'previous_generated_frames_used': False,
              'identity_and_real_support_accepted': False, 'original': str(character), 'original_sha256': _sha(character),
              'reference_policy': reference_policy, 'reference_sha256': _sha(reference), 'mode': mode})
        # Detect source changes during inference/preparation before freezing.
        _require(all(Path(p).is_file() and _sha(p) == h for p,h in inputs.items()), 'source input changed during preparation')
        result = {'root': str(root), 'source_key': source_key, 'reference': str(reference), 'width': width, 'height': height,
                  'frames': frames, 'height_m': height_m, 'origin': list(origin), 'manifest': str(root / 'manifest.json')}
        files = {str(p.relative_to(root)): _sha(p) for p in sorted(root.rglob('*')) if p.is_file()}
        _dump(root / 'manifest.json', {'schema': SCHEMA, 'source_key': source_key, 'result': result, 'files': files})
        (root / 'manifest.sha256').write_text(_sha(root / 'manifest.json') + '\n', 'ascii')
        return result
    except Exception as exc:
        _dump(root / 'failed.json', {'status': 'failed', 'source_key': source_key, 'error': str(exc)})
        raise
