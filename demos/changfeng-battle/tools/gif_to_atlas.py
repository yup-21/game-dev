#!/usr/bin/env python3
"""Editor-only GIF decoder: preserve whole transparent frames and real durations.

Prints one JSON object to stdout; never changes runtime Resources or source GIFs.
Requires Pillow in the editor's Python environment, not in exported games.
"""

import hashlib
import json
import sys
from pathlib import Path


def convert(source: Path, destination: Path, width: int, height: int) -> dict:
    try:
        from PIL import Image, ImageSequence
    except ImportError as error:
        raise ValueError("缺少 Pillow：请在 Godot 编辑器使用的 Python 中安装 pillow") from error

    if not source.is_file() or source.suffix.lower() != ".gif":
        raise ValueError("源文件不是 GIF")
    if width not in (328, 384) or height != (256 if width == 328 else 288):
        raise ValueError("请选用角色统一的 328×256 或 384×288 帧画布")
    with Image.open(source) as gif:
        if gif.format != "GIF" or gif.size != (width, height):
            raise ValueError(f"GIF 画布必须是 {width}×{height}，实际 {gif.size}")
        total = getattr(gif, "n_frames", 1)
        if total < 1 or total > 256:
            raise ValueError("单动作 GIF 必须包含 1..256 帧")
        cols = min(5, total)
        rows = (total + cols - 1) // cols
        atlas = Image.new("RGBA", (cols * width, rows * height), (0, 0, 0, 0))
        durations = []
        for index, frame in enumerate(ImageSequence.Iterator(gif)):
            # Pillow applies GIF disposal and frame compositing on seek.
            rgba = frame.convert("RGBA")
            alpha = rgba.getchannel("A")
            box = alpha.getbbox()
            if box is None:
                raise ValueError(f"第 {index + 1} 帧没有角色像素")
            if box[0] < 8 or box[1] < 8 or box[2] > width - 8 or box[3] > height - 8:
                raise ValueError(f"第 {index + 1} 帧未保留四边至少 8px 透明留白")
            # GIF frame timing is in milliseconds and commonly quantized to 10ms.
            millis = int(frame.info.get("duration", gif.info.get("duration", 0)))
            if millis <= 0:
                raise ValueError(f"第 {index + 1} 帧缺少有效的 GIF 帧时长")
            durations.append(millis)
            atlas.paste(rgba, ((index % cols) * width, (index // cols) * height))

    destination.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(destination, "PNG")
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    return {"error": "", "frames": total, "columns": cols, "rows": rows,
            "width": width, "height": height, "durations_ms": durations, "sha256": digest}


if __name__ == "__main__":
    try:
        if len(sys.argv) != 5:
            raise ValueError("用法: gif_to_atlas.py input.gif output.png 328 256")
        result = convert(Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]))
        print(json.dumps(result, ensure_ascii=False))
    except (ValueError, OSError, RuntimeError) as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False))
        sys.exit(1)
