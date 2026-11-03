#!/usr/bin/env python3
"""Inspect the actual Godot art bindings; no second runtime asset registry."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "demos/changfeng-battle"
OUT = ROOT / "art-production/inventory"
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".svg"}
REF = re.compile(r"""res://assets/[^"'\s)\],}]+""")
TEXT_EXTS = {".gd", ".tres", ".tscn", ".godot", ".cfg"}
IGNORE = ("checks/", "data/templates/", "data/art_previews/", "addons/", "assets/", ".godot/")


def current_bindings() -> dict[str, list[str]]:
    refs: dict[str, set[str]] = {}
    for path in sorted(GAME.rglob("*")):
        if not path.is_file() or path.suffix not in TEXT_EXTS:
            continue
        relative = path.relative_to(GAME).as_posix()
        if relative.startswith(IGNORE):
            continue
        for match in REF.finditer(path.read_text(encoding="utf-8")):
            ref = match.group().rstrip(".,;")
            if Path(ref).suffix.lower() in IMAGE_EXTS and "%" not in ref:
                refs.setdefault(ref, set()).add(relative)
    return {key: sorted(owners) for key, owners in sorted(refs.items())}


def validate(bindings: dict[str, list[str]]) -> list[str]:
    errors = []
    mirror_root = ROOT / "art-production/in-use"
    expected_mirrors = set()
    for path in bindings:
        prefix = "res://assets/imported/in-use/"
        if not path.startswith(prefix):
            errors.append("Bound artwork must be under imported/in-use/: " + path)
            continue
        if ".." in path:
            errors.append("Unsafe imported art: " + path)
            continue
        source = GAME / path.removeprefix("res://")
        mirror = mirror_root / path.removeprefix(prefix)
        expected_mirrors.add(mirror)
        if not source.is_file():
            errors.append("Missing imported art: " + path)
        if not mirror.is_file():
            errors.append("Missing in-use mirror: " + mirror.relative_to(ROOT).as_posix())
        if source.is_file() and mirror.is_file():
            source_sha = hashlib.sha256(source.read_bytes()).digest()
            mirror_sha = hashlib.sha256(mirror.read_bytes()).digest()
            if source_sha != mirror_sha:
                errors.append("In-use mirror differs: " + path)
    for path in mirror_root.rglob("*"):
        if path.is_file() and path.suffix.lower() in IMAGE_EXTS and path not in expected_mirrors:
            errors.append("Unbound image in in-use mirror: " + path.relative_to(ROOT).as_posix())
    # Date is metadata, not a directory classification key.
    for root in (ROOT / "art-production/candidates", mirror_root,
                 GAME / "assets/imported"):
        if root.is_dir():
            for folder in root.rglob("*"):
                if folder.is_dir() and re.fullmatch(r"\d{4}-\d{2}-\d{2}", folder.name):
                    errors.append("Date-based asset folder: " + folder.relative_to(ROOT).as_posix())
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    bindings = current_bindings()
    errors = validate(bindings)
    for error in errors:
        print(error)
    if errors:
        return 1
    if args.write:
        OUT.mkdir(parents=True, exist_ok=True)
        data = {"schema_version": 2, "purpose": "Read-only in-use art references; runtime authority remains Godot .tres",
                "assets": [{"res_path": path, "resources": owners, "prompt": ""}
                           for path, owners in bindings.items()]}
        (OUT / "asset-index.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        lines = ["# 使用中素材（根据 Resource 与游戏代码生成）", "", "候选不在清单中；当前引用代表使用中。提示词保存在对应候选工作单，未知来源不编造。", "",
                 "| 图片 | 对应 Resource / 消费者 |", "| --- | --- |"]
        for path, owners in bindings.items():
            lines.append("| `" + path + "` | " + ", ".join("`" + p + "`" for p in owners) + " |")
        (OUT / "usage-report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(("Written" if args.write else "Checked") + " in-use native art paths: " + str(len(bindings)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
