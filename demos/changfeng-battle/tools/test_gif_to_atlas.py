"""Disposable Pillow fixtures for GIF -> PNG, duration, alpha and boundary QA."""

import json
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image


def make_frame(x: int) -> Image.Image:
    frame = Image.new("RGBA", (328, 256), (0, 0, 0, 0))
    for row in range(20, 180):
        for col in range(x, x + 40):
            frame.putpixel((col, row), (120, 90, 20, 255))
    return frame


def main() -> None:
    decoder = Path(__file__).with_name("gif_to_atlas.py")
    with TemporaryDirectory(prefix="wuxia-gif-check-") as temp:
        folder = Path(temp)
        gif = folder / "idle.gif"
        output = folder / "atlas.png"
        frames = [make_frame(80), make_frame(90)]
        frames[0].save(gif, format="GIF", save_all=True, append_images=frames[1:],
                       duration=[100, 250], disposal=2, transparency=0)
        cmd = [sys.executable, str(decoder), str(gif), str(output), "328", "256"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        report = json.loads(result.stdout)
        assert report["error"] == ""
        assert report["durations_ms"] == [100, 250]
        assert (report["columns"], report["rows"]) == (2, 1)
        assert Image.open(output).size == (656, 256)
        wrong = subprocess.run(cmd[:-2] + ["384", "288"], capture_output=True, text=True)
        assert wrong.returncode != 0
        assert "画布" in json.loads(wrong.stdout)["error"]
    print("GIF_TO_ATLAS_PASS")


if __name__ == "__main__":
    main()
