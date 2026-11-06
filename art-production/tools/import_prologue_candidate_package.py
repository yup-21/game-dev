#!/usr/bin/env python3
"""Safely import the two prologue art candidates into editable native scenes.

The artist-delivered zip is NOT automatically fetched by GitHub.
Download prologue_scene_art_candidates_v01.zip, then from repository root:

  python art-production/tools/import_prologue_candidate_package.py \
    --package /path/to/prologue_scene_art_candidates_v01.zip

Afterwards run Godot import and PROLOGUE_REQUIRE_ART=1 visual contract QA.
This imports only PRO-02B and PRO-00; PRO-02 and PRO-01 reuse the existing
ruined_temple / rainy_bridge official, already bound texture resources.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import shutil
import tempfile
import zipfile
from pathlib import Path

from PIL import Image, ImageChops

SIZE = (1600, 1000)
SCENES = ("temple_hall", "mountain_road")
LAYERS = ("background", "ground", "foreground")
PREFIX = "prologue_scene_art/assets"


def verify_source(archive: zipfile.ZipFile, scene: str) -> dict[str, bytes]:
    prefix = f"{PREFIX}/{scene}/"
    names = ["master", *LAYERS, "preview"]
    result: dict[str, bytes] = {}
    images: dict[str, Image.Image] = {}
    for role in names:
        entry = prefix + role + ".png"
        result[role] = archive.read(entry)
        with Image.open(io.BytesIO(result[role])) as im:
            if im.size != SIZE:
                raise ValueError(f"{entry}: expected 1600x1000, got {im.size}")
            if im.mode not in ("RGBA", "RGB"):
                raise ValueError(f"{entry}: unexpected mode {im.mode}")
            images[role] = im.convert("RGBA")
    for role in LAYERS:
        if images[role].getchannel("A").getextrema() == (255, 255):
            raise ValueError(f"{scene}/{role}: expected a real alpha layer")
    assembled = Image.new("RGBA", SIZE)
    for role in LAYERS:
        assembled = Image.alpha_composite(assembled, images[role])
    if ImageChops.difference(assembled, images["master"]).getbbox() is not None:
        raise ValueError(f"{scene}: layer composite is not pixel-aligned with master")
    if ImageChops.difference(assembled, images["preview"]).getbbox() is not None:
        raise ValueError(f"{scene}: preview is not pixel-aligned")
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", type=Path, required=True,
                        help="Original prologue_scene_art_candidates_v01.zip")
    parser.add_argument("--repo-root", type=Path,
                        default=Path(__file__).resolve().parents[2])
    parser.add_argument("--check", action="store_true",
                        help="Verify imported files match the archive, no writes")
    parser.add_argument("--force", action="store_true",
                        help="Overwrite different existing candidate files")
    args = parser.parse_args()
    repo = args.repo_root.resolve()
    package = args.package.resolve()
    if not (repo / "demos/changfeng-battle/project.godot").is_file():
        parser.error(f"not a game-dev repository root: {repo}")
    if not package.is_file():
        parser.error(f"candidate archive missing: {package}")

    prepared: list[tuple[Path, bytes]] = []
    manifest = {"status": "candidate_unapproved", "size": list(SIZE),
                "scenes": {}}
    with zipfile.ZipFile(package, "r") as archive:
        for scene in SCENES:
            contents = verify_source(archive, scene)
            game_dir = repo / "demos/changfeng-battle/assets/candidates/prologue" / scene
            author_dir = repo / "art-production/candidates/scenes" / (
                "prologue_temple_hall" if scene == "temple_hall"
                else "prologue_mountain_road")
            hashes = {}
            for role in LAYERS:
                prepared.append((game_dir / (role + ".png"), contents[role]))
                hashes[role] = hashlib.sha256(contents[role]).hexdigest()
            for role in ("master", "preview"):
                prepared.append((author_dir / (role + ".png"), contents[role]))
            manifest["scenes"][scene] = {
                "layers": hashes, "source": f"{PREFIX}/{scene}",
                "required_resolution": list(SIZE),
                "status": "pending_visual_signoff"}

    for target, content in prepared:
        if target.exists() and target.read_bytes() != content and not args.force:
            raise FileExistsError(f"{target} already has different contents: use --force")
        if args.check and (not target.exists() or target.read_bytes() != content):
            raise AssertionError(f"missing/different imported file: {target}")
    if not args.check:
        for target, content in prepared:
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists() and target.read_bytes() == content:
                continue
            with tempfile.NamedTemporaryFile(dir=target.parent, delete=False) as tmp:
                tmp.write(content)
                staged = Path(tmp.name)
            staged.replace(target)
        manifest_path = (repo / "demos/changfeng-battle/assets/candidates/prologue"
                         / "manifest.json")
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)
                                 + "\n", encoding="utf-8")
    print("PROLOGUE_CANDIDATE_IMPORT_PASS: 2 scenes, 6 aligned RGBA layers, "
          "2 master/preview pairs; " + ("checked" if args.check else "imported"))
    print("Art status: CANDIDATE ONLY; run Godot and manual walk/occlusion review.")


if __name__ == "__main__":
    main()
