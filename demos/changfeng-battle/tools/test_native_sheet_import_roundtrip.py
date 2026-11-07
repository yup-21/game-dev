"""Disposable end-to-end PNG -> polygon mask -> native SpriteFrames.tres/rollback test."""

import os
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

from PIL import Image, ImageDraw


def main() -> None:
    project = Path(__file__).resolve().parents[1]
    repo = project.parents[1]
    actor_id = "native_sheet_test_" + uuid.uuid4().hex[:12]
    source_dir = repo / "art-production" / "candidates" / "characters" / actor_id
    card = project / "data" / "native" / "characters" / (actor_id + ".tres")
    candidate_dir = project / "data" / "art_candidates" / "characters" / actor_id
    imported_dir = project / "assets" / "imported" / "characters" / actor_id
    profile = project / "data" / "native" / "animations" / (actor_id + ".tres")
    frames = None
    journal = None
    isolation = Path(tempfile.mkdtemp(prefix="wuxia-native-sheet-"))
    assert not source_dir.exists() and not card.exists() and not candidate_dir.exists()

    def godot(phase: str = "", editor_import: bool = False) -> str:
        env = os.environ.copy()
        env["WUXIA_SHEET_TEST_ID"] = actor_id
        env["WUXIA_SHEET_TEST_PHASE"] = phase
        for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            env[key] = str(isolation / key.lower())
        command = ["godot", "--headless", "--path", str(project)]
        command += (["--editor", "--import", "--quit"] if editor_import else
                    ["--script", "res://checks/test_native_sheet_import_roundtrip.gd"])
        run = subprocess.run(command, text=True, capture_output=True,
                             env=env, timeout=180)
        print(run.stdout)
        if run.stderr:
            print(run.stderr[-6000:], file=sys.stderr)
        if run.returncode:
            raise AssertionError(f"Godot phase {phase or 'import'} failed: {run.returncode}")
        return run.stdout

    try:
        sheet_dir = source_dir / "sheets"
        sheet_dir.mkdir(parents=True)
        sheet = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
        draw = ImageDraw.Draw(sheet)
        for index in range(25):
            x, y = (index % 5) * 40, (index // 5) * 40
            draw.rectangle((x + 12, y + 12, x + 19, y + 19),
                           fill=(150, 130, 65, 255))
        # Within crop 0 but outside the manually authored silhouette mask.
        sheet.putpixel((35, 12), (255, 0, 0, 255))
        sheet.save(sheet_dir / "test.png")

        # A freshly cloned project has no imported textures yet. The template
        # Profile may reference runtime textures, so import the project first.
        godot(editor_import=True)
        prepared = godot("prepare")
        match = re.search(r"SHEET_TEST_FRAMES=(.+)", prepared)
        assert match, "Missing generated frames path"
        frames = project / match.group(1).strip().removeprefix("res://")
        godot(editor_import=True)
        applied = godot("apply")
        match = re.search(r"SHEET_TEST_JOURNAL=(.+)", applied)
        if match:
            journal = Path(match.group(1).strip())
        assert "SHEET_TEST_ROLLBACK=true" in applied
    finally:
        # Only unique, test-owned paths are removed; approved resources are untouched.
        if card.exists():
            card.unlink()
        if profile.exists():
            profile.unlink()
        if frames is not None and frames.exists():
            frames.unlink()
        if imported_dir.exists():
            shutil.rmtree(imported_dir)
        if candidate_dir.exists():
            shutil.rmtree(candidate_dir)
        if source_dir.exists():
            shutil.rmtree(source_dir)
        if journal is not None and journal.name == "import-log.json" and journal.exists():
            shutil.rmtree(journal.parent)
        shutil.rmtree(isolation)


if __name__ == "__main__":
    main()
