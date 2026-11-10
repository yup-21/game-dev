"""CPU-only diagnostic: compare generated body landmarks to the planned pose.

No fitting, mirroring, translation, rescaling or changes to source images.
This checks pose-following evidence, not identity, true foot contact or approval.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib
import json
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from character_action_paths import POSE_MODEL, POSE_DEPS
from PIL import Image, ImageDraw


REGIONS = {
    'head': (('nose',), 1, ('nose',)),
    'torso': (('neck', 'right_shoulder', 'left_shoulder', 'right_hip', 'left_hip'), 3, ('neck',)),
    'right_arm': (('right_shoulder', 'right_elbow', 'right_wrist'), 2, ('right_wrist',)),
    'left_arm': (('left_shoulder', 'left_elbow', 'left_wrist'), 2, ('left_wrist',)),
    'right_leg': (('right_hip', 'right_knee', 'right_ankle'), 2, ('right_ankle',)),
    'left_leg': (('left_hip', 'left_knee', 'left_ankle'), 2, ('left_ankle',)),
}
MEAN_THRESHOLD = .10
MAX_JOINT_THRESHOLD = .15


def _finite_number(value, name, minimum=None, maximum=None):
    if (isinstance(value, bool) or not isinstance(value, (int, float))
            or not math.isfinite(value) or minimum is not None and value < minimum
            or maximum is not None and value > maximum):
        raise ValueError(f'{name} must be a finite number' +
                         (f' between {minimum} and {maximum}' if maximum is not None else ''))
    return float(value)


def _parameters(height, confidence):
    height = _finite_number(height, 'Planned body height')
    if height <= 0:
        raise ValueError('A positive planned body height is required')
    return height, _finite_number(confidence, 'Confidence threshold', 0, 1)


def _planned_points(planned):
    from video_pose_template import NAMES
    if not isinstance(planned, dict):
        raise ValueError('Planned COCO18 points must be a mapping')
    result = {}
    for name in NAMES:
        point = planned.get(name)
        if not isinstance(point, (list, tuple)) or len(point) != 2:
            raise ValueError(f'Planned {name} must contain two finite coordinates')
        result[name] = [_finite_number(v, f'Planned {name} coordinate') for v in point]
    return result


def _sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def _json_sha(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False,
                                    separators=(',', ':'), allow_nan=False).encode('utf-8')).hexdigest()


def diagnostic_recipe(context, confidence=.3):
    """Return the detector/threshold recipe that callers must bind to cached samples."""
    import video_pose_template as pose
    height, confidence = _parameters(
        context['job'].get('production_request', {}).get('target_standing_height_px'), confidence)
    if POSE_MODEL is None or not POSE_MODEL.is_file():
        raise ValueError('Existing CPU pose detector is missing; no downloads performed')
    return {'schema_version': 2, 'target_standing_height_px': height,
            'confidence_threshold': confidence, 'detector_model_sha256': _sha(POSE_MODEL),
            'diagnostic_source_sha256': _sha(Path(__file__)),
            'detector_source_sha256': _sha(Path(pose.__file__)),
            'minimum_joint_count': 10, 'mean_threshold_body_heights': MEAN_THRESHOLD,
            'max_joint_threshold_body_heights': MAX_JOINT_THRESHOLD,
            'regions': {name: {'joints': list(joints), 'minimum_joint_count': minimum,
                               'critical_joints': list(critical)}
                        for name, (joints, minimum, critical) in REGIONS.items()}}


def _existing_run(out, binding):
    """Reuse complete evidence without modifying it; incomplete/tampered runs stop."""
    try:
        manifest = json.loads((out / 'manifest.json').read_text('utf-8'))
        expected = {'report.json'} | {frame['id'] + '.png' for frame in binding['frames']}
        artifacts = manifest.get('artifacts', {})
        if (manifest.get('binding') != binding or set(artifacts) != expected
                or any(not (out / name).is_file() or _sha(out / name) != digest
                       for name, digest in artifacts.items())):
            raise ValueError('Run evidence differs from its immutable manifest')
        report = json.loads((out / 'report.json').read_text('utf-8'))
        if report.get('report_path') != str(out / 'report.json'):
            raise ValueError('Run report path differs from its immutable location')
        return report
    except (OSError, ValueError, TypeError, AttributeError) as exc:
        raise ValueError(f'Existing diagnostic run is incomplete or changed; preserved without overwrite: {out}') from exc


def compare_landmarks(planned, detected, height, confidence=.3):
    from video_pose_template import NAMES
    height, confidence = _parameters(height, confidence)
    planned = _planned_points(planned)
    records, unavailable, distances = [], {}, {}
    for index, name in enumerate(NAMES[:14]):
        try:
            x, y, score = [float(v) for v in detected[index]]
        except (IndexError, TypeError, ValueError):
            unavailable[name] = 'invalid_or_missing_detection'
            continue
        if not all(math.isfinite(v) for v in (x, y, score)) or not 0 <= score <= 1:
            unavailable[name] = 'invalid_detection'
            continue
        if score < confidence:
            unavailable[name] = 'low_confidence'
            continue
        target = planned[name]
        if target == [0, 0]:
            unavailable[name] = 'missing_planned_joint'
            continue
        distance = math.dist(target, [x, y])
        distances[name] = distance
        records.append({'joint': name, 'planned': target, 'detected': [round(x, 3), round(y, 3)],
                        'confidence': round(score, 4), 'distance_px': round(distance, 3)})
    mean = sum(distances.values()) / len(records) if records else None
    maximum = max(distances.values(), default=None)
    insufficient, deviations, regions = [], [], {}
    if len(records) < 10:
        insufficient.append('global: fewer than 10 reliable body joints')
    for region, (joints, minimum, critical) in REGIONS.items():
        present = [name for name in joints if name in distances]
        missing = [name for name in joints if name not in distances]
        missing_critical = [name for name in critical if name not in distances]
        region_mean = sum(distances[name] for name in present) / len(present) if present else None
        region_max = max((distances[name] for name in present), default=None)
        if len(present) < minimum:
            insufficient.append(f'{region}: reliable coverage {len(present)}/{len(joints)} is below {minimum}')
        if missing_critical:
            insufficient.append(f'{region}: missing critical endpoint/anchor: {", ".join(missing_critical)}')
        large = region_mean is not None and region_mean / height > MEAN_THRESHOLD
        large_max = region_max is not None and region_max / height > MAX_JOINT_THRESHOLD
        if large:
            deviations.append(f'{region}: mean deviation exceeds {MEAN_THRESHOLD:.0%} of planned height')
        if large_max:
            deviations.append(f'{region}: a joint deviation exceeds {MAX_JOINT_THRESHOLD:.0%} of planned height')
        regions[region] = {'joint_count': len(present), 'expected_joint_count': len(joints),
                           'coverage': round(len(present) / len(joints), 4),
                           'minimum_joint_count': minimum, 'missing_joints': missing,
                           'missing_critical_joints': missing_critical,
                           'mean_distance_px': round(region_mean, 3) if region_mean is not None else None,
                           'mean_distance_body_heights': round(region_mean / height, 4) if region_mean is not None else None,
                           'max_distance_px': round(region_max, 3) if region_max is not None else None,
                           'max_distance_body_heights': round(region_max / height, 4) if region_max is not None else None,
                           'status': 'insufficient_detection' if len(present) < minimum or missing_critical else
                                     'large_pose_deviation' if large or large_max else 'no_large_deviation_detected'}
    if mean is not None and mean / height > MEAN_THRESHOLD:
        deviations.append(f'global: mean deviation exceeds {MEAN_THRESHOLD:.0%} of planned height')
    return {'status': 'insufficient_detection' if insufficient else
                      'large_pose_deviation' if deviations else 'no_large_deviation_detected',
            'joint_count': len(records), 'mean_distance_px': round(mean, 3) if mean is not None else None,
            'mean_distance_body_heights': round(mean / height, 4) if mean is not None else None,
            'large_deviation_threshold_body_heights': MEAN_THRESHOLD, 'joints': records,
            'max_distance_px': round(maximum, 3) if maximum is not None else None,
            'max_distance_body_heights': round(maximum / height, 4) if maximum is not None else None,
            'max_joint_threshold_body_heights': MAX_JOINT_THRESHOLD,
            'regions': regions, 'unavailable_joints': unavailable,
            'reasons': insufficient + deviations,
            'interpretation': 'Heuristic CPU screening only; side-view occlusion and left/right ambiguity can affect detection. No semantic approval.'}


def check_job(job_path, frame_ids=None):
    from comfy_character_actions import load_job
    import video_pose_template as pose
    context = load_job(job_path)
    available = [f['id'] for f in context['frames']]
    selected = available if frame_ids is None else list(frame_ids)
    if not selected or any(not isinstance(fid, str) or not fid for fid in selected):
        raise ValueError('Selected frame IDs must be nonempty')
    if len(selected) != len(set(selected)):
        raise ValueError('Duplicate selected frame ID')
    if not set(selected) <= set(available):
        raise ValueError('Unknown selected frame ID')
    target_height, confidence = _parameters(
        context['job'].get('production_request', {}).get('target_standing_height_px'), .3)
    canvas = tuple(context['job']['camera']['canvas'])
    # Validate all requested inputs before detector startup or output writes.
    inputs = []
    for frame in context['frames']:
        if frame['id'] not in selected:
            continue
        planned = _planned_points(frame['authored_keypoints_coco18'])
        path = context['out'] / 'frames_raw' / (frame['id'] + '.png')
        if not path.is_file():
            raise ValueError(f'No generated raw frame for {frame["id"]}; this diagnostic never generates images')
        with Image.open(path) as source:
            if source.size != canvas:
                raise ValueError(f'{frame["id"]}: raw frame canvas {source.size} must equal job canvas {canvas}; no resizing allowed')
            image = source.convert('RGB')
        pose_path = context['files'][f'pose_{frame["id"]}']
        inputs.append((frame, path, image, {'raw_frame_sha256': _sha(path),
                       'pose_image_sha256': _sha(pose_path),
                       'planned_coordinates_sha256': _json_sha(planned)}))
    if POSE_MODEL is None or not POSE_MODEL.is_file() or (POSE_DEPS is not None and not POSE_DEPS.is_dir()):
        raise ValueError('Existing CPU pose detector is missing; no downloads performed')
    recipe = diagnostic_recipe(context, confidence)
    binding = {'diagnostic_recipe': recipe, 'canvas': list(canvas),
               'frames': [{'id': frame['id'], 'planned_pose': frame['pose'],
                           'raw_frame': str(path), 'provenance': provenance}
                          for frame, path, image, provenance in inputs]}
    out = context['out'] / 'pose-review' / 'pose-following' / 'runs' / _json_sha(binding)
    if out.exists():
        return _existing_run(out, binding)
    if POSE_DEPS is not None:
        sys.path.insert(0, str(POSE_DEPS))
    pose.np = importlib.import_module('numpy')
    pose.cv2 = importlib.import_module('cv2')
    ort = importlib.import_module('onnxruntime')
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    options.inter_op_num_threads = 1
    session = ort.InferenceSession(str(POSE_MODEL), sess_options=options, providers=['CPUExecutionProvider'])
    records = []
    out.mkdir(parents=True, exist_ok=False)
    for frame, path, image, provenance in inputs:
        points, bbox, method = pose.infer(session, pose.np.asarray(image), None)
        report = compare_landmarks(frame['authored_keypoints_coco18'], points, target_height, confidence)
        report.update(id=frame['id'], detector_roi=bbox, detector_roi_method=method,
                      planned_pose=frame['pose'], raw_frame=str(path), provenance=provenance,
                      diagnostic_recipe_sha256=_json_sha(recipe))
        overlay = image.copy()
        draw = ImageDraw.Draw(overlay)
        for item in report['joints']:
            x, y = item['planned']
            a, b = item['detected']
            draw.line((x, y, a, b), fill='#ffce00', width=1)
            draw.ellipse((x-2, y-2, x+2, y+2), outline='#ff5030')
            draw.ellipse((a-2, b-2, a+2, b+2), outline='#30efff')
        overlay.save(out / (frame['id'] + '.png'))
        records.append(report)
    report = {'schema_version': 2, 'status': 'diagnostic_only', 'model': str(POSE_MODEL),
              'report_path': str(out / 'report.json'), 'run_id': out.name,
              'diagnostic_recipe': recipe, 'diagnostic_recipe_sha256': _json_sha(recipe),
              'original_artwork_used_in_detection': False, 'per_frame_fitting': False,
              'red': 'planned joint', 'cyan': 'detected joint', 'yellow': 'deviation line',
              'identity_verified': False, 'support_verified': False, 'frames': records}
    (out / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', 'utf-8')
    artifacts = {name: _sha(out / name) for name in
                 ['report.json'] + [frame['id'] + '.png' for frame, _, _, _ in inputs]}
    (out / 'manifest.json').write_text(json.dumps({'binding': binding, 'artifacts': artifacts},
                                                ensure_ascii=False, indent=2) + '\n', 'utf-8')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--job', type=Path, required=True)
    parser.add_argument('--frames', help='Comma-separated existing frame IDs')
    args = parser.parse_args()
    try:
        result = check_job(args.job, args.frames.split(',') if args.frames is not None else None)
        print(json.dumps([{k: f[k] for k in ('id', 'status', 'joint_count', 'mean_distance_px')} for f in result['frames']], ensure_ascii=False))
        print(f"REPORT_PATH={result['report_path']}")
    except (ValueError, OSError) as exc:
        parser.exit(1, str(exc) + '\n')
