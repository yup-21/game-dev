"""Check one rigid-rig motion and optionally compare with the corresponding older render."""
import argparse
from hashlib import sha256
import json
import math
from pathlib import Path

from PIL import Image


def inspect(folder):
    receipt = json.loads((folder / "receipt.json").read_text("utf-8"))
    action = receipt.get("action_id", "walk")
    width, height = receipt["canvas"]
    expected = [folder / frame["file"] for frame in receipt["frames"]]
    assert set(expected) == set((folder / "frames").glob("*.png"))
    assert len(expected) >= 2
    preview = []
    metrics = []
    for source, item in zip(expected, receipt["frames"]):
        with Image.open(source) as image:
            image.load()
            assert image.size == (width, height) and image.mode == "RGBA"
            alpha = image.getchannel("A")
            bounds = alpha.getbbox()
            alpha_range = alpha.getextrema()
            assert bounds and alpha_range[0] == 0 and alpha_range[1] >= 128
            x0, y0, x1, y1 = bounds
            grip, tip = item["weapon_grip"], item["weapon_tip"]
            blade_center_samples = []
            for fraction in (0.3, 0.6, 0.85):
                x = round(grip[0] + (tip[0] - grip[0]) * fraction)
                y = round(grip[1] + (tip[1] - grip[1]) * fraction)
                blade_center_samples.append(alpha.crop((x - 1, y - 1, x + 2, y + 2)).getextrema()[1])
            background = Image.new("RGBA", image.size, "#303641")
            background.alpha_composite(image)
            preview.append(background.convert("RGB"))
        margins = (x0, y0, width - x1, height - y1)
        metrics.append({
            "file": item["file"], "alpha_bounds": list(bounds),
            "transparent_margin_px_left_top_right_bottom": list(margins),
            "passes_8px_margin": min(margins) >= 8,
            "planned_sword_length_px": round(math.dist(grip, tip), 4),
            "sword_axis_3x3_peak_alpha": blade_center_samples,
            "png_sha256": sha256(source.read_bytes()).hexdigest(),
        })
    times = [item["time_ms"] for item in receipt["frames"]] + [receipt["duration_ms"]]
    timing = [b - a for a, b in zip(times, times[1:])]
    assert timing == [item["duration_ms"] for item in receipt["frames"]]
    gif_times = [((t + 5) // 10) * 10 for t in times]
    gif_timing = [b - a for a, b in zip(gif_times, gif_times[1:])]
    fingerprints = [item["png_sha256"] for item in metrics]
    comparable = fingerprints[:-1] if receipt.get("end_contract") == "return_to_guard" and fingerprints[0] == fingerprints[-1] else fingerprints
    assert len(set(comparable)) == len(comparable)
    return {
        "action_id": action, "loop": receipt["loop"], "end_contract": receipt.get("end_contract"),
        "source_motion_sha256": receipt["motion_sha256"],
        "source_generated_atlas_sha256": receipt["generated_atlas"]["sha256"],
        "canvas": receipt["canvas"], "logical_origin": receipt["logical_origin"],
        "native_rgba_count": len(metrics), "unique_native_rgba": len(set(fingerprints)), "duration_ms": sum(timing),
        "gif_duration_ms": sum(gif_timing),
        "sword_axis_coverage_frames": sum(all(a >= 128 for a in item["sword_axis_3x3_peak_alpha"]) for item in metrics),
        "min_margin_px": min(min(item["transparent_margin_px_left_top_right_bottom"]) for item in metrics),
        "pass_8px_margin_count": sum(item["passes_8px_margin"] for item in metrics),
        "frames": metrics,
    }, preview, gif_timing, receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--action-dir", type=Path, required=True)
    parser.add_argument("--baseline-dir", type=Path)
    args = parser.parse_args()
    data, new, timing, receipt = inspect(args.action_dir)
    action = data["action_id"]
    playback = {"loop": 0} if receipt["loop"] else {}
    new[0].save(args.action_dir / f"{action}_preview.gif", save_all=True,
                append_images=new[1:], duration=timing, **playback)
    keys = ("sword_grip_error_px", "left_wrist_reach_correction_px",
            "left_boot_reach_correction_px", "right_boot_reach_correction_px")
    data["maximum_reach_corrections_px"] = {
        key: round(max(item["diagnostics"][key] for item in receipt["frames"]), 3) for key in keys
    }
    if args.baseline_dir:
        baseline, old, old_timing, _ = inspect(args.baseline_dir)
        assert baseline["action_id"] == action
        assert baseline["canvas"] == data["canvas"]
        assert baseline["source_generated_atlas_sha256"] == data["source_generated_atlas_sha256"]
        assert len(old) == len(new) and old_timing == timing
        side_by_side = []
        for left, right in zip(old, new):
            width, height = left.size
            combined = Image.new("RGB", (width * 2, height))
            combined.paste(left, (0, 0))
            combined.paste(right, (width, 0))
            side_by_side.append(combined)
        side_by_side[0].save(args.action_dir / f"{action}_comparison.gif", save_all=True,
                             append_images=side_by_side[1:], duration=timing, **playback)
        data["baseline_comparison"] = {
            "path": str(args.baseline_dir.resolve()), "min_margin_px": baseline["min_margin_px"],
            "sword_axis_coverage_frames": baseline["sword_axis_coverage_frames"],
            "source_motion_sha256": baseline["source_motion_sha256"],
        }
    (args.action_dir / "geometry_report.json").write_text(json.dumps(data, indent=2) + "\n", "utf-8")
    for key in ("native_rgba_count", "unique_native_rgba", "pass_8px_margin_count",
                "min_margin_px", "sword_axis_coverage_frames", "duration_ms", "gif_duration_ms",
                "maximum_reach_corrections_px"):
        print(key, data[key])


if __name__ == "__main__":
    main()
