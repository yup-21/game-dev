#!/usr/bin/env python3
"""Decode arbitrary GIF canvas sizes into independent lossless RGBA frames.

Editor-only helper. No source preflight on dimensions/Alpha/margins: those are
checked after the user has repaired and standardized the frames in Godot.
"""

import json
import sys
from pathlib import Path


def decode(source: Path, folder: Path) -> dict:
    try:
        from PIL import Image, ImageSequence
    except ImportError as exc:
        raise ValueError("GIF 编辑需要 Pillow (pip install pillow)") from exc
    if not source.is_file() or source.suffix.lower() != ".gif":
        raise ValueError("源文件不是 GIF")
    with Image.open(source) as gif:
        if gif.format != "GIF" or gif.n_frames < 1 or gif.n_frames > 256:
            raise ValueError("GIF 必须含 1..256 帧")
        folder.mkdir(parents=True, exist_ok=True)
        frames = []
        for index, frame in enumerate(ImageSequence.Iterator(gif)):
            # Pillow performs disposal/compositing on seek, preserving full frames.
            out = folder / f"frame_{index:03d}.png"
            frame.convert("RGBA").save(out)
            duration = int(frame.info.get("duration", gif.info.get("duration", 100)))
            frames.append({"path": str(out), "duration_ms": max(1, duration)})
        return {"error": "", "size": list(gif.size), "frames": frames}


if __name__ == "__main__":
    try:
        if len(sys.argv) != 3:
            raise ValueError("用法: gif_to_frames.py source.gif temporary_directory")
        print(json.dumps(decode(Path(sys.argv[1]), Path(sys.argv[2])), ensure_ascii=False))
    except (OSError, ValueError, RuntimeError) as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False))
        raise SystemExit(1)
