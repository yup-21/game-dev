"""One-shot disposable Godot/Pillow integration test; no approved art is edited."""

import os
import re
import shutil
import subprocess
import sys
import uuid
from pathlib import Path

from PIL import Image


def main() -> None:
    project = Path(__file__).resolve().parents[1]
    repo = project.parents[1]
    ident = "native_gif_test_" + uuid.uuid4().hex[:12]
    actions = repo / "art-production" / "candidates" / "characters" / ident / "actions"
    target = project / "data" / "native" / "characters" / (ident + ".tres")
    assets = project / "assets" / "imported" / "characters" / ident
    candidate_resources = project / "data" / "art_candidates" / "characters" / ident
    profiles = [project / "data" / "native" / "animations" / (ident + suffix)
                for suffix in (".tres", "_frames.tres")]
    assert not actions.exists() and not target.exists() and not assets.exists()
    journal = None
    try:
        actions.mkdir(parents=True)
        for action in ("idle", "attack1"):
            frames = []
            for x in (80, 85):
                image = Image.new("RGBA", (328, 256), (0, 0, 0, 0))
                for row in range(20, 180):
                    for col in range(x, x + 40):
                        image.putpixel((col, row), (180, 115, 60, 255))
                frames.append(image)
            frames[0].save(actions / (action + ".gif"), save_all=True,
                           append_images=frames[1:], duration=[100, 200],
                           disposal=2, transparency=0)
        env = os.environ.copy()
        env["WUXIA_GIF_TEST_ID"] = ident
        for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            env[key] = "/tmp/wuxia-native-gif-integration-" + key.lower()
        run = subprocess.run(["godot", "--headless", "--path", str(project),
                              "--script", "res://checks/test_native_gif_import_roundtrip.gd"],
                             text=True, capture_output=True, env=env, timeout=120)
        print(run.stdout)
        if run.stderr:
            print(run.stderr, file=sys.stderr)
        match = re.search(r"GIF_TEST_JOURNAL=(.*)", run.stdout)
        if match:
            journal = Path(match.group(1).strip())
        if run.returncode:
            raise AssertionError("Godot GIF import/rollback integration failed")
    finally:
        # This unique fixture is created above; never remove any other user asset.
        if target.exists():
            target.unlink()
        for file in profiles:
            if file.exists():
                file.unlink()
        if assets.exists():
            shutil.rmtree(assets)
        if candidate_resources.exists():
            shutil.rmtree(candidate_resources)
        shutil.rmtree(actions.parent, ignore_errors=True)
        if journal is not None and journal.name == "import-log.json" and journal.exists():
            shutil.rmtree(journal.parent)


if __name__ == "__main__":
    main()
