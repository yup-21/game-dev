#!/usr/bin/env python3
"""Regression: arbitrary-sized GIFs must reach the V3 editor without hard gates."""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image


def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        frames = []
        for x in (10, 32):
            frame = Image.new("RGBA", (120, 80), (0, 0, 0, 0))
            for py in range(5, 65):
                for px in range(x, x + 24):
                    frame.putpixel((px, py), (160, 20, 30, 255))
            frames.append(frame)
        source = root / "raw.gif"
        frames[0].save(source, save_all=True, append_images=frames[1:], duration=[70, 130],
                       disposal=2, loop=0, transparency=0)
        command = [sys.executable, str(Path(__file__).with_name("gif_to_frames.py")),
                   str(source), str(root / "decoded")]
        decoded = subprocess.run(command, text=True, capture_output=True, check=True)
        result = json.loads(decoded.stdout)
        assert result["error"] == ""
        assert result["size"] == [120, 80]
        assert [entry["duration_ms"] for entry in result["frames"]] == [70, 130]
        for entry in result["frames"]:
            with Image.open(entry["path"]) as image:
                assert image.size == (120, 80) and image.mode == "RGBA"
        print("PASS raw GIF decoder: arbitrary canvas and original frame durations")


if __name__ == "__main__":
    main()
