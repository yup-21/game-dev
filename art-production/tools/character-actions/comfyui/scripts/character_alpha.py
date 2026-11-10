"""CPU foreground alpha for character frames; preserves source pixels and coordinates.

Only ONNX segmentation is used, followed by removal of tiny low-confidence
alpha dust. There is no colour key, largest-component selection, cropping,
recentering, or resizing of the delivered RGB image. The supported
pre/postprocessing follows rembg's u2net.py and dis_general_use.py sessions:
https://github.com/danielgatis/rembg/tree/main/rembg/sessions
This module never downloads models or installs dependencies.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
from functools import lru_cache


ALPHA_SCHEMA = 1
ALGORITHM = "onnx-foreground-alpha-v2-component-dust"


class AlphaValidationError(ValueError):
    """The mask cannot be published as an uncropped transparent frame."""

    def __init__(self, message: str, report: dict | None = None):
        super().__init__(message)
        self.report = report or {}


def _dependencies(deps_dir=None):
    if deps_dir:
        directory = Path(deps_dir).resolve()
        if not directory.is_dir():
            raise FileNotFoundError(f"Alpha dependency directory missing: {directory}")
        if str(directory) not in sys.path:
            sys.path.insert(0, str(directory))
    try:
        import numpy as np
        from PIL import Image
    except ImportError as exc:
        raise RuntimeError("Character alpha requires Pillow and numpy; supply --deps-dir.") from exc
    return np, Image


def sha256_file(path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


@lru_cache(maxsize=4)
def _model_hash(path: str, size: int, mtime_ns: int) -> str:
    return sha256_file(path)


def model_identity(model_path) -> dict:
    model = Path(model_path).resolve()
    stat = model.stat()
    return {
        "path": str(model),
        "sha256": _model_hash(str(model), stat.st_size, stat.st_mtime_ns),
        "size_bytes": stat.st_size,
    }


def discover_model(model_dir):
    """Find an installed supported model without fetching one."""
    directory = Path(model_dir)
    for name in ("isnet-general-use.onnx", "u2net.onnx", "u2netp.onnx"):
        candidate = directory / name
        if candidate.is_file():
            return candidate.resolve()
    return None


def _family(model: Path) -> str:
    name = model.stem.lower()
    if name == "isnet-general-use":
        return "isnet-general-use"
    if name in ("u2net", "u2netp"):
        return name
    raise ValueError(
        f"Unsupported model {model.name}; use isnet-general-use.onnx, u2net.onnx or u2netp.onnx. "
        "Other models require their own explicit preprocessing."
    )


@lru_cache(maxsize=2)
def _session(path: str, size: int, mtime_ns: int):
    try:
        import onnxruntime as ort
    except ImportError as exc:
        raise RuntimeError("CPU alpha inference requires onnxruntime; supply --deps-dir.") from exc
    options = ort.SessionOptions()
    # Bound CPU resources and leave the GPU generation runtime untouched.
    options.intra_op_num_threads = min(4, os.cpu_count() or 1)
    options.inter_op_num_threads = 1
    session = ort.InferenceSession(path, sess_options=options, providers=["CPUExecutionProvider"])
    if session.get_providers() != ["CPUExecutionProvider"]:
        raise RuntimeError("Alpha inference must use CPUExecutionProvider only.")
    return session


def _remove_alpha_dust(alpha_values, np):
    """Remove only tiny, weak 8-connected components, anywhere on the canvas.

    All pixels in every other component remain byte-identical, including soft
    edges, connected wisps and disconnected strong or large foreground pieces.
    The canvas boundary does not participate in the removal decision.
    """
    try:
        import cv2
    except ImportError as exc:
        raise RuntimeError("Alpha dust filtering requires OpenCV; supply --deps-dir.") from exc
    count, labels, stats, _ = cv2.connectedComponentsWithStats(
        (alpha_values > 0).astype("uint8"), connectivity=8
    )
    maxima = np.zeros(count, dtype=np.uint8)
    np.maximum.at(maxima, labels.ravel(), alpha_values.ravel())
    removable = (stats[:, cv2.CC_STAT_AREA] <= 64) & (maxima <= 8)
    removable[0] = False  # Label zero is background, never a foreground component.
    removed_components = []
    for label in np.flatnonzero(removable):
        left, top, width, height, area = map(int, stats[label])
        removed_components.append({
            "label": int(label),
            "area": area,
            "max_alpha": int(maxima[label]),
            "bbox": [left, top, left + width, top + height],
        })
    filtered = alpha_values.copy()
    filtered[removable[labels]] = 0
    return filtered, {
        "connectivity": 8,
        "max_component_area": 64,
        "max_component_alpha": 8,
        "selection": "area<=64 AND max_alpha<=8; independent of canvas position",
        "global_alpha_threshold": None,
        "previous_global_alpha_threshold_cancelled": True,
        "removed_component_count": len(removed_components),
        "removed_components": removed_components,
        "removed_pixels": sum(component["area"] for component in removed_components),
        "retained_component_count": count - 1 - len(removed_components),
    }


def _predict_alpha(rgb, model: Path, np, Image):
    family = _family(model)
    stat = model.stat()
    session = _session(str(model), stat.st_size, stat.st_mtime_ns)
    inputs = session.get_inputs()
    if len(inputs) != 1 or len(inputs[0].shape) != 4:
        raise ValueError("Foreground model must expose one NCHW image input.")
    shape = inputs[0].shape
    default_size = 1024 if family == "isnet-general-use" else 320
    height = shape[2] if isinstance(shape[2], int) and shape[2] > 0 else default_size
    width = shape[3] if isinstance(shape[3], int) and shape[3] > 0 else default_size
    if shape[1] not in (3, "3", None, "channels"):
        raise ValueError(f"Unsupported foreground model channel shape: {shape}")
    resized = np.asarray(rgb.resize((width, height), Image.Resampling.LANCZOS), dtype=np.float32)
    # rembg BaseSession.normalize scales by the image maximum, then normalizes
    # channels. This is model input only; the delivered RGB stays byte-identical.
    resized /= max(float(resized.max()), 1e-6)
    if family == "isnet-general-use":
        resized -= np.array([0.5, 0.5, 0.5], dtype=np.float32)
    else:
        resized = (resized - np.array([0.485, 0.456, 0.406], dtype=np.float32)) / np.array(
            [0.229, 0.224, 0.225], dtype=np.float32
        )
    tensor = np.ascontiguousarray(resized.transpose(2, 0, 1)[None], dtype=np.float32)
    output = session.run([session.get_outputs()[0].name], {inputs[0].name: tensor})[0]
    if output.ndim != 4 or output.shape[:2] != (1, 1):
        raise ValueError(f"Unexpected foreground output shape: {output.shape}")
    mask = output[0, 0]
    if not np.isfinite(mask).all():
        raise AlphaValidationError("Foreground model returned non-finite alpha values.")
    minimum, maximum = float(mask.min()), float(mask.max())
    if maximum - minimum <= 1e-8:
        raise AlphaValidationError("Foreground model returned an empty or constant mask.")
    mask = np.clip((mask - minimum) / (maximum - minimum), 0, 1)
    # Keep the model's soft boundary; no global alpha cutoff is applied.
    alpha = Image.fromarray((mask * 255).astype("uint8")).resize(rgb.size, Image.Resampling.LANCZOS)
    alpha_values, dust_report = _remove_alpha_dust(np.asarray(alpha), np)
    alpha = Image.fromarray(alpha_values)
    return alpha, {
        "family": family,
        "provider": "CPUExecutionProvider",
        "input_size": [width, height],
        "mask_raw_range": [minimum, maximum],
        "mask_postprocessing": "minmax_uint8_lanczos; remove only tiny weak 8-connected alpha dust; no global alpha cutoff or colour key",
        "alpha_dust_filter": dust_report,
    }


def _inspect_rgba(rgba, np) -> dict:
    alpha = np.asarray(rgba.getchannel("A"))
    width, height = rgba.size
    bbox = rgba.getchannel("A").getbbox()  # Includes every nonzero soft-edge pixel.
    minimum, maximum = int(alpha.min()), int(alpha.max())
    margins = None if bbox is None else {
        "left": bbox[0], "top": bbox[1], "right": width - bbox[2], "bottom": height - bbox[3]
    }
    transparent = int(np.count_nonzero(alpha == 0))
    visible = int(np.count_nonzero(alpha > 0))
    soft = int(np.count_nonzero((alpha > 0) & (alpha < 255)))
    errors = []
    if minimum == maximum == 0:
        errors.append("alpha is entirely transparent")
    if minimum == maximum == 255:
        errors.append("alpha is entirely opaque")
    if not transparent:
        errors.append("alpha has no fully transparent background pixels")
    if not visible or maximum < 128:
        errors.append("foreground has no substantial visible content")
    if margins is None or min(margins.values()) < 8:
        errors.append("nonzero alpha must leave at least 8 transparent pixels on all four sides")
    return {
        "ok": not errors,
        "mode": rgba.mode,
        "size": [width, height],
        "alpha_range": [minimum, maximum],
        "alpha_bbox": list(bbox) if bbox else None,
        "alpha_margins": margins,
        "margins": margins,
        "required_margin_px": 8,
        "transparent_pixels": transparent,
        "visible_pixels": visible,
        "soft_alpha_pixels": soft,
        "object_content_nonempty": visible > 0 and maximum >= 128,
        "errors": errors,
        "warnings": ["Transparent margin below the preferred 16 pixels; review full silhouette."]
        if margins and 8 <= min(margins.values()) < 16 else [],
    }


def inspect_frame(source, deps_dir=None) -> dict:
    """Validate a PNG/RGBA candidate without loading an inference model."""
    np, Image = _dependencies(deps_dir)
    source = Path(source).resolve()
    with Image.open(source) as image:
        image.load()
        original_mode = image.mode
        original_format = image.format
        rgba = image.convert("RGBA")
    report = _inspect_rgba(rgba, np)
    if original_mode != 'RGBA' or original_format != 'PNG':
        report['errors'].append('delivery must be a genuine RGBA PNG')
        report['ok'] = False
    report.update({"source": str(source), "source_mode": original_mode, "input_sha256": sha256_file(source)})
    return report


def _write_json(path: Path, report: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary = tempfile.mkstemp(prefix=path.stem + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as stream:
            json.dump(report, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def process_frame(source, target, model_path, deps_dir=None, *, report_path=None, keep_margin_failure=False) -> dict:
    """Write validated RGBA and a same-stem .json report; return that report.

    Existing real alpha is validated and reused directly. Opaque input requires
    an installed supported ONNX model. Validation failure raises
    AlphaValidationError before publishing a PNG, unless the caller explicitly
    saves a margin-only failure as a candidate. Output keeps the original RGB,
    dimensions and pixel positions, including strong or large detached weapon/
    hair components. Only tiny low-confidence alpha dust is removed.
    """
    np, Image = _dependencies(deps_dir)
    source, target = Path(source).resolve(), Path(target).resolve()
    if source == target:
        raise ValueError("Keep the original frame: source and output paths must differ.")
    if target.suffix.lower() != ".png":
        raise ValueError("Transparent frame output must be .png.")
    report_file = Path(report_path).resolve() if report_path else target.with_suffix(".json")
    protected = {source, target}
    if model_path:
        protected.add(Path(model_path).resolve())
    if report_file in protected:
        raise ValueError("Alpha report path must differ from source, output and model paths.")
    with Image.open(source) as image:
        image.load()
        source_mode = image.mode
        rgba = image.convert("RGBA")
    rgb = rgba.convert("RGB")
    report = {
        "schema_version": ALPHA_SCHEMA,
        "algorithm": ALGORITHM,
        "processor_sha256": sha256_file(__file__),
        "source": str(source),
        "output": str(target),
        "input_sha256": sha256_file(source),
        "source_mode": source_mode,
        "source_size": list(rgba.size),
        "model": None,
        "model_sha256": None,
    }
    report["source_sha256"] = report["input_sha256"]
    if rgba.getchannel("A").getextrema()[0] < 255:
        report["method"] = "existing_alpha"
    else:
        if model_path is None:
            raise FileNotFoundError("Opaque frame requires an installed foreground ONNX model; supply --model.")
        model = Path(model_path).resolve()
        report["model"] = model_identity(model)
        report["model_sha256"] = report["model"]["sha256"]
        alpha, inference = _predict_alpha(rgb, model, np, Image)
        rgba.putalpha(alpha)
        report.update({"method": "onnx_segmentation", "inference": inference})
    report.update(_inspect_rgba(rgba, np))
    report["source_dimensions_preserved"] = list(rgba.size) == report["source_size"]
    report["source_rgb_preserved"] = rgba.convert("RGB").tobytes() == rgb.tobytes()
    margin_only = report["errors"] == ["nonzero alpha must leave at least 8 transparent pixels on all four sides"]
    if not report["ok"] and not (keep_margin_failure and margin_only):
        raise AlphaValidationError("Invalid character alpha: " + "; ".join(report["errors"]), report)
    target.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary = tempfile.mkstemp(prefix=target.stem + ".", suffix=".png", dir=target.parent)
    os.close(handle)
    try:
        rgba.save(temporary, format="PNG")
        with Image.open(temporary) as check:
            check.load()
            if check.mode != "RGBA" or check.size != rgba.size or check.tobytes() != rgba.tobytes():
                raise AlphaValidationError("Written PNG does not preserve validated RGBA pixels.", report)
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    report["output_sha256"] = sha256_file(target)
    report["report_path"] = str(report_file)
    _write_json(report_file, report)
    return report


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--model", type=Path, help="Installed isnet-general-use/u2net/u2netp ONNX; no downloads")
    parser.add_argument("--deps-dir", type=Path, help="Directory containing numpy/Pillow/onnxruntime")
    parser.add_argument("--report", type=Path, help="Explicit report path; default is output with .json extension")
    args = parser.parse_args(argv)
    report_file = args.report.resolve() if args.report else args.output.resolve().with_suffix(".json")
    protected = {args.source.resolve(), args.output.resolve()}
    if args.model:
        protected.add(args.model.resolve())
    if report_file in protected:
        parser.error("--report must differ from source, output and model paths")
    try:
        report = process_frame(args.source, args.output, args.model, args.deps_dir, report_path=args.report)
    except Exception as exc:
        report = dict(getattr(exc, "report", {}))
        report.update({"ok": False, "error": str(exc)})
        _write_json(report_file, report)
        print(json.dumps(report, ensure_ascii=False), file=sys.stderr)
        return 1
    print(json.dumps(report, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
