"""Extract an editable motion template from a new single-subject video or GIF.

Example (portable Python, existing local dependencies and model; CPU only)::
    python video_pose_template.py --video action.gif --output motion-template
    python video_pose_template.py --video action.mp4 --output motion-template \
        --start 3.92 --end 8.56 --duration 2.5 --max-keyframes 16

--duration is the suggested OUTPUT playback duration, never an input crop.
The input is decoded and inferred again; previous corrected templates are not
used as network results. No downloads, package installation, or GPU use occur.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib
import json
import math
import os
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from character_action_paths import POSE_MODEL, POSE_DEPS

NAMES = ["nose", "neck", "right_shoulder", "right_elbow", "right_wrist",
         "left_shoulder", "left_elbow", "left_wrist", "right_hip",
         "right_knee", "right_ankle", "left_hip", "left_knee", "left_ankle",
         "right_eye", "left_eye", "right_ear", "left_ear"]
COCO17_TO_18 = [0, None, 6, 8, 10, 5, 7, 9, 12, 14, 16, 11, 13, 15, 2, 1, 4, 3]
LIMBS = [(1, 2), (1, 5), (2, 3), (3, 4), (5, 6), (6, 7), (1, 8),
         (8, 9), (9, 10), (1, 11), (11, 12), (12, 13), (1, 0),
         (0, 14), (14, 16), (0, 15), (15, 17)]
COLORS = [(255, 0, 0), (255, 85, 0), (255, 170, 0), (255, 255, 0),
          (170, 255, 0), (85, 255, 0), (0, 255, 0), (0, 255, 85),
          (0, 255, 170), (0, 255, 255), (0, 170, 255), (0, 85, 255),
          (0, 0, 255), (85, 0, 255), (170, 0, 255), (255, 0, 255),
          (255, 0, 170), (255, 0, 85)]
MODEL_NAME = "dw-ll_ucoco_384.onnx"
MODEL_SOURCE = "https://huggingface.co/yzd-v/DWPose/blob/main/dw-ll_ucoco_384.onnx"
INFERENCE_SOURCE = "https://github.com/IDEA-Research/DWPose/blob/onnx/ControlNet-v1-1-nightly/annotator/dwpose/onnxpose.py"
RENDER_SOURCE = "https://github.com/Fannovel16/comfyui_controlnet_aux/blob/main/src/custom_controlnet_aux/open_pose/util.py"


def dump(path, value):
    Path(path).write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8")


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def locations(args):
    """Known local locations, with explicit flags/environment taking priority."""
    deps = [args.deps_dir, os.environ.get("MOTION_POSE_DEPS"), POSE_DEPS]
    deps_path = next((Path(p).resolve() for p in deps if p and Path(p).is_dir()), None)
    if args.deps_dir and deps_path != Path(args.deps_dir).resolve():
        raise FileNotFoundError(f"Dependency directory does not exist: {args.deps_dir}")
    if deps_path:
        sys.path.insert(0, str(deps_path))
    models = [args.model, os.environ.get("MOTION_POSE_MODEL"),
              POSE_MODEL,
              Path(__file__).resolve().parent / "models" / MODEL_NAME]
    model = next((Path(p).resolve() for p in models if p and Path(p).is_file()), None)
    if args.model and model != Path(args.model).resolve():
        raise FileNotFoundError(f"Model does not exist: {args.model}")
    if not model:
        raise FileNotFoundError("Existing DWPose model not found; pass --model PATH. No automatic download is performed.")
    return model, deps_path


def decode(path, info):
    """Yield source frame index, relative timestamp, duration, and RGB pixels."""
    from PIL import Image
    if path.suffix.lower() == ".gif":
        info["decoder"] = "Pillow GIF"
        with Image.open(path) as image:
            info["source_size"] = list(image.size)
            info["source_frame_count"] = image.n_frames
            timing = []
            elapsed = 0.0
            for index in range(image.n_frames):
                image.seek(index)
                duration = float(image.info.get("duration", 80) or 80)
                timing.append((elapsed, duration))
                elapsed += duration
            info["source_duration_ms"] = elapsed
            for index, (timestamp, duration) in enumerate(timing):
                image.seek(index)
                yield index, timestamp, duration, np.asarray(image.convert("RGB"))
    else:
        av = importlib.import_module("av")
        info["decoder"] = f"PyAV {av.__version__}"
        with av.open(str(path)) as container:
            if not container.streams.video:
                raise ValueError("Input has no video stream")
            stream = container.streams.video[0]
            rate = float(stream.average_rate or 25)
            fallback_duration = 1000.0 / rate
            info["source_size"] = [stream.width, stream.height]
            info["source_frame_count"] = stream.frames or None
            info["source_duration_ms"] = (float(stream.duration * stream.time_base) * 1000
                                          if stream.duration is not None else None)
            origin = None
            last_end = 0.0
            for index, frame in enumerate(container.decode(stream)):
                timestamp = float(frame.pts * frame.time_base) * 1000 if frame.pts is not None else index * fallback_duration
                if origin is None:
                    origin = timestamp
                timestamp -= origin
                duration = float(frame.duration * frame.time_base) * 1000 if frame.duration else fallback_duration
                last_end = timestamp + duration
                yield index, timestamp, duration, frame.to_ndarray(format="rgb24")
            if info["source_duration_ms"] is None:
                info["source_duration_ms"] = last_end


def subject_bbox(rgb, roi=None):
    """A generic solid-background crop, otherwise a full-frame top-down fallback.

    This is not a general multi-person detector. Source coordinates are always
    recovered through the inverse affine, so crop changes do not erase motion.
    """
    height, width = rgb.shape[:2]
    if roi:
        x, y, w, h = roi
        if x < 0 or y < 0 or w <= 0 or h <= 0 or x + w > width or y + h > height:
            raise ValueError("--roi X Y WIDTH HEIGHT must be inside the input canvas")
        return [float(x), float(y), float(x + w), float(y + h)], "explicit_source_roi"
    border = np.concatenate([rgb[0, :, :], rgb[-1, :, :], rgb[:, 0, :], rgb[:, -1, :]])
    background = np.median(border.astype(np.float32), axis=0)
    distance = np.linalg.norm(border.astype(np.float32) - background, axis=1)
    if float(np.percentile(distance, 90)) < 35:
        difference = np.linalg.norm(rgb.astype(np.float32) - background, axis=2)
        mask = (difference > 38).astype(np.uint8)
        kernel = np.ones((5, 5), np.uint8)
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
        count, labels, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
        if count > 1:
            areas = stats[1:, cv2.CC_STAT_AREA]
            largest = float(areas.max())
            keep = np.flatnonzero(areas >= max(35, largest * 0.035)) + 1
            if len(keep) and largest >= width * height * 0.002:
                yy, xx = np.where(np.isin(labels, keep))
                left, right, top, bottom = xx.min(), xx.max() + 1, yy.min(), yy.max() + 1
                pad = max(8, int((bottom - top) * 0.04))
                return [float(max(0, left - pad)), float(max(0, top - pad)),
                        float(min(width, right + pad)), float(min(height, bottom + pad))], "solid_background_foreground_bbox"
    return [0.0, 0.0, float(width), float(height)], "full_frame_top_down_no_person_detector"


def infer_crop(session, rgb, bbox):
    left, top, right, bottom = bbox
    center = np.array([(left + right) / 2, (top + bottom) / 2], dtype=np.float32)
    scale = np.array([right - left, bottom - top], dtype=np.float32) * 1.25
    _, _, height, width = session.get_inputs()[0].shape
    if not isinstance(height, int) or not isinstance(width, int):
        raise ValueError("Expected a fixed-size DWPose SimCC ONNX input")
    if scale[0] > scale[1] * width / height:
        scale[1] = scale[0] * height / width
    else:
        scale[0] = scale[1] * width / height
    affine = np.array([[width / scale[0], 0, width * (0.5 - center[0] / scale[0])],
                       [0, height / scale[1], height * (0.5 - center[1] / scale[1])]], dtype=np.float32)
    crop = cv2.warpAffine(rgb, affine, (width, height), flags=cv2.INTER_LINEAR)
    crop = (crop.astype(np.float32) - [123.675, 116.28, 103.53]) / [58.395, 57.12, 57.375]
    tensor = crop.transpose(2, 0, 1)[None].astype(np.float32)
    outputs = session.run(None, {session.get_inputs()[0].name: tensor})
    if len(outputs) != 2:
        raise ValueError("Expected DWPose SimCC x/y outputs")
    sx, sy = outputs
    xy = np.stack([sx.argmax(axis=-1), sy.argmax(axis=-1)], axis=-1)[0].astype(np.float32) / 2
    scores = np.minimum(sx.max(axis=-1), sy.max(axis=-1))[0]
    xy = xy / [width, height] * scale + center - scale / 2
    return np.c_[xy, np.clip(scores, 0, 1)].astype(np.float32)


def infer(session, rgb, roi):
    bbox, strategy = subject_bbox(rgb, roi)
    wholebody = infer_crop(session, rgb, bbox)
    # Improve a small subject in a complex scene without adding a detector model.
    if strategy.startswith("full_frame"):
        body = wholebody[:17]
        good = body[:, 2] >= 0.3
        if int(good.sum()) >= 8:
            lo, hi = body[good, :2].min(axis=0), body[good, :2].max(axis=0)
            pad = max(18.0, float(hi[1] - lo[1]) * 0.15)
            candidate = [max(0.0, float(lo[0] - pad)), max(0.0, float(lo[1] - pad)),
                         min(float(rgb.shape[1]), float(hi[0] + pad)),
                         min(float(rgb.shape[0]), float(hi[1] + pad))]
            if candidate[2] - candidate[0] > 20 and candidate[3] - candidate[1] > 40:
                refined = infer_crop(session, rgb, candidate)
                if np.median(refined[:17, 2]) >= np.median(body[:, 2]):
                    wholebody, bbox = refined, candidate
                    strategy = "full_frame_then_confident_joint_bbox_refinement"
    points = []
    for index in COCO17_TO_18:
        if index is None:
            neck = (wholebody[5] + wholebody[6]) / 2
            neck[2] = min(wholebody[5, 2], wholebody[6, 2])
            points.append(neck)
        else:
            points.append(wholebody[index].copy())
    return np.asarray(points), bbox, strategy


def rounded(points):
    return [[round(float(p[0]), 3), round(float(p[1]), 3), round(float(p[2]), 5)] for p in points]


def motion_features(records, threshold):
    """Interpolate/median-filter features only; raw inference remains untouched."""
    points = np.asarray([r["points"] for r in records], dtype=np.float64)
    times = np.asarray([r["time_ms"] for r in records], dtype=np.float64)
    roots = (points[:, 8, :2] + points[:, 11, :2]) / 2
    heights = []
    for p in points:
        valid = p[:, 2] >= threshold
        if valid.any():
            heights.append(float(np.ptp(p[valid, 1])))
    unit = max(30.0, float(np.median(heights)))
    positions = points[:, :, :2].copy()
    for joint in range(18):
        valid = points[:, joint, 2] >= threshold
        for axis in range(2):
            if valid.any():
                positions[:, joint, axis] = np.interp(times, times[valid], positions[valid, joint, axis])
            else:
                positions[:, joint, axis] = roots[:, axis]
    features = np.concatenate([(positions - roots[:, None, :]).reshape(len(points), -1), roots - roots[0]], axis=1) / unit
    smooth = features.copy()
    for i in range(1, len(features) - 1):
        smooth[i] = np.median(features[i - 1:i + 2], axis=0)
    return smooth, times, unit


def choose_keyframes(records, args):
    features, times, unit = motion_features(records, args.confidence)
    if len(records) <= 2:
        return list(range(len(records))), {"cap_reached": False, "body_height_unit_source_px": unit}
    selected = {0, len(records) - 1}
    final_score = 0.0
    while True:
        best = None
        final_score = 0.0
        ordered = sorted(selected)
        for left, right in zip(ordered, ordered[1:]):
            if right - left <= 1:
                continue
            candidates = np.arange(left + 1, right)
            gap = times[right] - times[left]
            alpha = (times[candidates] - times[left]) / max(1.0, gap)
            predicted = features[left] + alpha[:, None] * (features[right] - features[left])
            difference = (features[candidates] - predicted).reshape(len(candidates), 19, 2)
            distance = np.linalg.norm(difference, axis=2)
            error = 0.55 * np.sqrt(np.mean(distance ** 2, axis=1)) + 0.45 * distance.max(axis=1)
            index = int(error.argmax())
            score = float(error[index] / args.change_threshold)
            candidate = int(candidates[index])
            if gap > args.max_gap * 1000 and score < gap / (args.max_gap * 1000):
                score = gap / (args.max_gap * 1000)
                candidate = int(candidates[np.abs(times[candidates] - (times[left] + times[right]) / 2).argmin()])
            if score > final_score:
                final_score, best = score, candidate
        if final_score <= 1 or best is None or len(selected) >= args.max_keyframes:
            break
        selected.add(best)
    return sorted(selected), {
        "method": "time-aware recursive pose-trajectory simplification plus maximum source-time gap",
        "change_threshold_body_heights": args.change_threshold, "maximum_source_gap_ms": args.max_gap * 1000,
        "max_keyframes_safety_cap": args.max_keyframes, "selected_count": len(selected),
        "cap_reached": len(selected) >= args.max_keyframes and final_score > 1,
        "remaining_normalized_selection_score": round(final_score, 4),
        "body_height_unit_source_px": round(unit, 3),
        "smoothing": "3-sample median and missing-joint interpolation for selection features only; rendered/model coordinates are unchanged",
        "semantics": "No automatic action, phase, support-contact or weight-bearing recognition is claimed.",
    }


def common_transform(records, threshold):
    all_points = np.concatenate([r["points"] for r in records])
    valid = all_points[:, 2] >= threshold
    lo, hi = all_points[valid, :2].min(axis=0), all_points[valid, :2].max(axis=0)
    heights = [np.ptp(r["points"][r["points"][:, 2] >= threshold, 1]) for r in records]
    root = (records[0]["points"][8, :2] + records[0]["points"][11, :2]) / 2
    ankles = np.concatenate([r["points"][[10, 13]] for r in records])
    valid_ankles = ankles[ankles[:, 2] >= threshold]
    floor = float(valid_ankles[:, 1].max()) if len(valid_ankles) else float(hi[1])
    scale_limits = [580.0 / max(30.0, float(np.median(heights))),
                    302.0 / max(1.0, float(root[0] - lo[0])),
                    386.0 / max(1.0, float(hi[0] - root[0])),
                    660.0 / max(1.0, float(floor - lo[1]))]
    if hi[1] > floor:
        scale_limits.append(28.0 / max(1.0, float(hi[1] - floor)))
    scale = min(scale_limits)
    offset = np.array([342.0 - root[0] * scale, 700.0 - floor * scale])
    return scale, offset, root, {
        "scale": float(scale), "translation_xy": offset.tolist(), "source_bounds_xyxy": [*lo.tolist(), *hi.tolist()],
        "first_source_hip_xy": root.tolist(), "first_canvas_hip_xy": (root * scale + offset).tolist(),
        "logical_ground_origin_xy": [342, 700], "source_floor_proxy_y": floor,
        "floor_proxy_method": "lowest confident ankle observed across the sequence; not automatic support-contact recognition",
        "method": "one isotropic scale and one translation for the complete analyzed sequence; no per-frame recentering or scaling",
        "horizontal_flip": False, "margin_px": 40,
    }


def pose_image(points, threshold):
    from PIL import Image, ImageDraw
    image = Image.new("RGB", (768, 768), "black")
    draw = ImageDraw.Draw(image)
    for (a, b), color in zip(LIMBS, COLORS):
        if min(points[a, 2], points[b, 2]) < threshold:
            continue
        p, q = points[a, :2], points[b, :2]
        middle = (p + q) / 2
        half = float(np.linalg.norm(p - q)) / 2
        angle = math.atan2(float(q[1] - p[1]), float(q[0] - p[0]))
        ca, sa = math.cos(angle), math.sin(angle)
        polygon = []
        for degrees in range(0, 361, 3):
            t = math.radians(degrees)
            u, v = half * math.cos(t), 4 * math.sin(t)
            polygon.append((round(middle[0] + u * ca - v * sa), round(middle[1] + u * sa + v * ca)))
        draw.polygon(polygon, fill=tuple(int(c * 0.6) for c in color))
    for p, color in zip(points, COLORS):
        if p[2] >= threshold:
            x, y = int(p[0]), int(p[1])
            draw.ellipse((x - 4, y - 4, x + 4, y + 4), fill=color)
    return image


def describe(points):
    root = (points[8, :2] + points[11, :2]) / 2
    dx = float(points[1, 0] - root[0])
    torso = "torso leaning screen-right" if dx > 20 else "torso leaning screen-left" if dx < -20 else "torso approximately upright"
    phrases = [torso]
    for side, wrist in [("right", 4), ("left", 7)]:
        if points[wrist, 2] < 0.2:
            phrases.append(f"{side} wrist occluded or uncertain")
            continue
        x, y = points[wrist, :2]
        horizontal = "in front of" if x > root[0] + 20 else "behind" if x < root[0] - 20 else "near"
        level = "above the shoulders" if y < points[1, 1] else "near waist height" if y < root[1] + 35 else "below the pelvis"
        phrases.append(f"{side} wrist {horizontal} the pelvis, {level}")
    return "; ".join(phrases) + ". Match the reference leg configuration."


def canonical_neutral():
    """Independent fixed-camera COCO18 side stance; never presented as inference."""
    return np.asarray([
        [381, 146, 1], [346, 219, 1], [346, 236, 1], [394, 332, 1], [410, 430, 1],
        [340, 238, 1], [318, 340, 1], [318, 441, 1], [339, 423, 1], [351, 560, 1],
        [362, 696, 1], [345, 423, 1], [330, 560, 1], [322, 696, 1], [366, 130, 1],
        [0, 0, 0], [345, 141, 1], [0, 0, 0],
    ], dtype=float)


def contact_sheet(output, frames, records, selected):
    from PIL import Image, ImageDraw
    columns, tile_w, tile_h = 3, 512, 294
    image = Image.new("RGB", (columns * tile_w, math.ceil(len(frames) / columns) * tile_h), (30, 32, 38))
    draw = ImageDraw.Draw(image)
    for i, (frame, index) in enumerate(zip(frames, selected)):
        x, y = (i % columns) * tile_w, (i // columns) * tile_h
        draw.text((x + 8, y + 6), f'{frame["id"]} | source {frame["source_frame"]} @ {frame["source_time_ms"]}ms', fill="white")
        thumb = records[index]["thumbnail"].copy()
        thumb.thumbnail((256, 256))
        image.paste(thumb, (x + (256 - thumb.width) // 2, y + 30 + (256 - thumb.height) // 2))
        pose = Image.open(output / frame["pose"]).resize((256, 256), Image.Resampling.LANCZOS)
        image.paste(pose, (x + 256, y + 30))
    image.save(output / "contact.png")


def run(args):
    global np, cv2
    model, deps = locations(args)
    np, cv2 = importlib.import_module("numpy"), importlib.import_module("cv2")
    ort = importlib.import_module("onnxruntime")
    from PIL import Image
    video, output = args.video.resolve(), args.output.resolve()
    if not video.is_file():
        raise FileNotFoundError(video)
    output.mkdir(parents=True, exist_ok=True)
    (output / "poses").mkdir(exist_ok=True)
    options = ort.SessionOptions()
    options.intra_op_num_threads, options.inter_op_num_threads = args.threads, 1
    session = ort.InferenceSession(str(model), sess_options=options, providers=["CPUExecutionProvider"])
    session.disable_fallback()
    info, records, excluded = {}, [], []
    start_ms = args.start * 1000
    end_ms = args.end * 1000 if args.end is not None else float("inf")
    next_sample = start_ms
    last_decoded = None
    window_end = start_ms

    def add(index, time, duration, rgb):
        points, bbox, strategy = infer(session, rgb, args.roi)
        body_valid = int((points[2:14, 2] >= args.confidence).sum())
        if body_valid < 6 or min(points[8, 2], points[11, 2]) < args.confidence:
            excluded.append({"frame_index": index, "source_time_ms": time, "reason": "insufficient confident body/hip landmarks", "source_keypoints_coco18": rounded(points)})
            return
        thumb = Image.fromarray(rgb)
        thumb.thumbnail((320, 240))
        records.append({"frame_index": index, "time_ms": time, "duration_ms": duration,
                        "points": points, "bbox": bbox, "crop_strategy": strategy, "thumbnail": thumb})
        if len(records) % 10 == 0 or len(records) == 1:
            print(json.dumps({"status": "infer", "accepted_analysis_frames": len(records), "source_frame": index, "source_time_ms": round(time, 3), "provider": "CPUExecutionProvider"}), flush=True)

    for index, time, duration, rgb in decode(video, info):
        if time < start_ms:
            continue
        if time >= end_ms:
            break
        window_end = min(end_ms, time + duration)
        last_decoded = (index, time, duration, rgb)
        if time + 0.01 < next_sample:
            continue
        if len(records) + len(excluded) >= args.max_analysis_frames:
            raise ValueError("Analysis frame safety limit reached; pass --start/--end, lower --analysis-fps, or raise --max-analysis-frames")
        add(index, time, duration, rgb)
        next_sample += 1000 / args.analysis_fps
        next_sample = max(next_sample, time + 0.01)
    if last_decoded and (not records or last_decoded[0] != records[-1]["frame_index"]):
        add(*last_decoded)
    if not records:
        raise ValueError("No usable pose was detected in the selected window. Check the crop/time range or pass --roi X Y WIDTH HEIGHT for one visible subject.")
    selected, selection = choose_keyframes(records, args)
    scale, offset, first_root, transform = common_transform(records, args.confidence)
    first_time = records[0]["time_ms"]
    source_span = max(1.0, window_end - first_time)
    playback_ms = round(args.duration * 1000)
    if playback_ms < len(selected):
        raise ValueError("Output duration must allow at least one millisecond per selected keyframe")
    output_times = [round((records[i]["time_ms"] - first_time) / source_span * playback_ms) for i in selected]
    for i in range(1, len(output_times)):
        output_times[i] = max(output_times[i - 1] + 1,
                              min(output_times[i], playback_ms - (len(output_times) - i)))
    frames = []
    for number, index in enumerate(selected, 1):
        record = records[index]
        points = record["points"].copy()
        points[:, :2] = points[:, :2] * scale + offset
        root = (points[8, :2] + points[11, :2]) / 2
        root_offset = ((record["points"][8, :2] + record["points"][11, :2]) / 2 - first_root) * scale
        identifier = f"motion_{number:03d}"
        pose = f"poses/{identifier}.png"
        pose_image(points, args.confidence).save(output / pose)
        description = describe(points)
        next_time = output_times[number] if number < len(selected) else playback_ms
        center = points[[1, 8, 11], :2].mean(axis=0)
        frame = {
            "id": identifier, "frame_index": number - 1, "source_frame": record["frame_index"], "time_ms": output_times[number - 1],
            "duration_ms": max(1, next_time - output_times[number - 1]), "action_id": "reference_motion",
            "phase": f"observed_key_{number:03d}; semantic phase unclassified", "role": "key", "pose": pose,
            "pose_description": description,
            "prompt": "Match the supplied body-pose control. " + description,
            "support_contact": "unknown; review required",
            "center_of_mass": "Estimated torso landmark center only; physical center of mass is unknown; review required.",
            "center_of_mass_estimate": {"xy": [round(float(v), 3) for v in center], "method": "torso landmark proxy; not physical center of mass", "review_required": True},
            "weapon_trajectory": "Weapon path unknown; reference wrist motion only. Adapt to the target character weapon contract; review required.",
            "hand_trajectory_estimate": {"kind": "reference wrist trajectory only; no weapon inference", "right_wrist_xy": [round(float(v), 3) for v in points[4, :2]], "left_wrist_xy": [round(float(v), 3) for v in points[7, :2]], "adaptation": "adapt to the target character weapon contract downstream", "review_required": True},
            "root_offset": [round(float(v), 3) for v in root_offset],
            "transition": "follow measured reference order; review interpolation and occlusion",
            "source_time_ms": round(record["time_ms"], 3), "keypoints": rounded(points),
            "source_keypoints_coco18": rounded(record["points"]), "hip_root_xy": [round(float(v), 3) for v in root],
            "pose_quality": {"manual_adjustments": [], "confidence_threshold": args.confidence, "review_required": True},
        }
        frames.append(frame)
        dump(output / f"poses/{identifier}.json", {"version": 1.3, "canvas_width": 768, "canvas_height": 768,
             "people": [{"pose_keypoints_2d": [v for p in frame["keypoints"] for v in p],
                         "face_keypoints_2d": [], "hand_left_keypoints_2d": [], "hand_right_keypoints_2d": []}]})
    # Canonical side stance is deliberately separate from extracted action poses.
    pose_image(np.asarray(frames[0]["keypoints"]), args.confidence).save(output / "poses/first_pose.png")
    profile = pose_image(canonical_neutral(), args.confidence)
    profile_note = {"method": "programmatically authored canonical strict right-facing side standing COCO18 skeleton; not a model result from this video", "canvas": [768, 768], "logical_ground_origin_xy": [342, 700], "keypoints": rounded(canonical_neutral()), "used_for_action_inference": False}
    if args.neutral_pose:
        if args.neutral_pose.suffix.lower() in (".png", ".webp", ".jpg", ".jpeg"):
            profile = Image.open(args.neutral_pose).convert("RGB")
            if profile.size != (768, 768):
                raise ValueError("Explicit neutral image must use the common 768x768 canvas")
        else:
            neutral_data = json.loads(args.neutral_pose.read_text(encoding="utf-8"))
            kp = neutral_data.get("keypoints")
            if isinstance(kp, dict):
                aliases = ["Nose", "Neck", "RShoulder", "RElbow", "RWrist", "LShoulder", "LElbow", "LWrist", "RHip", "RKnee", "RAnkle", "LHip", "LKnee", "LAnkle", "REye", "LEye", "REar", "LEar"]
                kp = [kp.get(n, kp.get(a)) for n, a in zip(NAMES, aliases)]
            if kp is None:
                flat = neutral_data["people"][0]["pose_keypoints_2d"]
                kp = np.asarray(flat).reshape(-1, 3)
            profile_points = np.asarray(kp, dtype=float)
            profile = pose_image(profile_points, args.confidence)
        profile_note = {"method": "explicit caller-supplied profile pose; not a network result for this video", "path": str(args.neutral_pose.resolve()), "sha256": sha256(args.neutral_pose), "camera_alignment_review_required": True}
    profile.save(output / "poses/neutral.png")
    motion = {
        "schema": "video-pose-motion-template-v1", "status": "candidate; automatic poses require visual review",
        "canvas": [768, 768], "canvas_width": 768, "canvas_height": 768,
        "profile_pose": "poses/neutral.png", "profile_pose_provenance": profile_note,
        "first_action_pose": "poses/first_pose.png",
        "facing": "right", "facing_note": "Target contract only; source orientation is preserved, not automatically classified or flipped.",
        "loop": False, "duration_ms": playback_ms, "suggested_duration_seconds": args.duration,
        "joint_order": "OpenPose COCO18", "joint_names": NAMES,
        "frame_index_convention": "frame_index is contiguous zero-based output order; source_frame is the zero-based decoded source-media index",
        "root_motion_policy": "One sequence-wide isotropic scale and translation. The first confident source hip x and the sequence ankle-floor proxy define logical ground origin O=(342,700). root_offset records each measured hip delta from that first hip in output pixels. No per-frame bounding-box centering, no root-motion zeroing, no horizontal flip. The floor is an observed-ankle proxy, not automatic support-contact classification.",
        "normalization": transform, "source_video": str(video),
        "source_window": {"start_seconds": args.start, "end_seconds": args.end, "actual_first_source_time_ms": first_time, "actual_end_source_time_ms": window_end, "selection": "explicit time window" if args.start or args.end is not None else "complete input; no automatic semantic crop"},
        "keyframe_selection": selection, "frames": frames,
        "provenance": "provenance.json", "contact": "contact.png",
    }
    image_bounds = []
    for frame in frames:
        with Image.open(output / frame["pose"]) as image:
            box = image.getbbox()
        image_bounds.append({"id": frame["id"], "nonblack_bbox_xyxy_exclusive": list(box),
                             "margins_left_top_right_bottom": [box[0], box[1], 768 - box[2], 768 - box[3]],
                             "touches_canvas": box[0] == 0 or box[1] == 0 or box[2] == 768 or box[3] == 768})
    roots = np.asarray([frame["hip_root_xy"] for frame in frames])
    canvas_check = {"scope": "extracted skeleton pixels only; generated character, loose clothing and weapon silhouettes are not available at this stage",
                    "any_pose_touches_canvas": any(item["touches_canvas"] for item in image_bounds),
                    "hip_root_bounds_xyxy": [*roots.min(axis=0).tolist(), *roots.max(axis=0).tolist()],
                    "minimum_pose_margin_px": min(min(item["margins_left_top_right_bottom"]) for item in image_bounds),
                    "frames": image_bounds}
    provenance = {
        "created_utc": datetime.now(timezone.utc).isoformat(), "method": "fresh DWPose ONNX CPU inference from decoded input",
        "source": {"path": str(video), "sha256": sha256(video), **info},
        "model": {"path": str(model), "sha256": sha256(model), "size_bytes": model.stat().st_size, "source": MODEL_SOURCE, "providers": session.get_providers()},
        "dependencies": {"isolated_path": str(deps) if deps else None, "numpy": np.__version__, "opencv": cv2.__version__, "onnxruntime": ort.__version__},
        "inference_reference": INFERENCE_SOURCE, "renderer_reference": RENDER_SOURCE,
        "normalization": transform, "selection": selection, "profile_pose": profile_note,
        "frame_index_convention": "motion.frames[].frame_index is contiguous output order; motion.frames[].source_frame and analysis_frames[].source_frame identify the original media frame. analysis_frames[].frame_index is retained as the source-analysis index.",
        "selected_motion_frame_mapping": [{"frame_index": f["frame_index"], "source_frame": f["source_frame"], "source_time_ms": f["source_time_ms"]} for f in frames],
        "canvas_check": canvas_check,
        "manual_adjustments": [],
        "review_required": ["Occluded joints and loose clothing can confuse pose estimation.", "Single-subject top-down extraction; complex or multi-person scenes may need --roi.", "No reliable action semantics, support-contact, physical center-of-mass or weapon trajectory recognition is claimed.", "Target facing is metadata; source camera direction is not automatically corrected.", "A keyframe safety cap may omit smaller pose changes; inspect contact.png and selection.cap_reached."],
        "excluded_analysis_frames": excluded,
        "analysis_frames": [{"frame_index": r["frame_index"], "source_frame": r["frame_index"], "source_time_ms": r["time_ms"], "source_duration_ms": r["duration_ms"], "source_bbox_xyxy": r["bbox"], "crop_strategy": r["crop_strategy"], "source_keypoints_coco18": rounded(r["points"]), "selected": i in selected} for i, r in enumerate(records)],
    }
    dump(output / "motion.json", motion)
    dump(output / "provenance.json", provenance)
    contact_sheet(output, frames, records, selected)
    print(json.dumps({"status": "complete", "motion": str(output / "motion.json"), "keyframes": len(frames), "analysis_frames": len(records), "cap_reached": selection.get("cap_reached", False), "duration_ms": playback_ms}), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--video", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--duration", type=float, default=2.5, help="Suggested output duration in seconds; does not crop the input")
    parser.add_argument("--start", type=float, default=0.0, help="Explicit source window start in seconds")
    parser.add_argument("--end", type=float, help="Explicit exclusive source window end in seconds")
    parser.add_argument("--max-keyframes", type=int, default=16, help="Safety upper bound; selected count is adaptive")
    parser.add_argument("--analysis-fps", type=float, default=12.0)
    parser.add_argument("--max-analysis-frames", type=int, default=1500)
    parser.add_argument("--change-threshold", type=float, default=0.09, help="Pose trajectory simplification error in body-height units")
    parser.add_argument("--max-gap", type=float, default=0.9, help="Preferred maximum source-time gap between keys; safety cap takes precedence")
    parser.add_argument("--confidence", type=float, default=0.2)
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--roi", nargs=4, type=float, metavar=("X", "Y", "WIDTH", "HEIGHT"), help="Optional fixed source crop for one subject")
    parser.add_argument("--model", type=Path)
    parser.add_argument("--deps-dir", type=Path)
    parser.add_argument("--neutral-pose", type=Path, help="Override the canonical side stance with a 768x768 pose PNG or COCO18 JSON; provenance is separate from video inference")
    args = parser.parse_args()
    if args.duration <= 0 or args.start < 0 or (args.end is not None and args.end <= args.start):
        parser.error("duration must be positive; require 0 <= start < end")
    if args.max_keyframes < 2 or args.analysis_fps <= 0 or args.change_threshold <= 0 or args.max_gap <= 0 or args.threads < 1 or args.max_analysis_frames < 2:
        parser.error("positive rates/thresholds/threads and at least two safety-limit frames are required")
    if not 0 < args.confidence < 1:
        parser.error("confidence must be between zero and one")
    try:
        run(args)
    except (ImportError, FileNotFoundError, ValueError) as error:
        parser.exit(2, f"video_pose_template: {error}\n")


if __name__ == "__main__":
    main()
