#!/usr/bin/env python3
"""List only images currently referenced by game Resources, scenes or runtime scripts."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "demos/changfeng-battle"
INDEX = ROOT / "art-production/inventory/asset-index.json"
REPORT = ROOT / "art-production/inventory/usage-report.md"
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".svg"}
TEXT_EXTS = {".gd", ".tres", ".tscn", ".godot", ".cfg", ".json"}
ASSET_REF = re.compile(r"""res://assets/[^"'\s)\],}]+""")
TICK = chr(96)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def destination(path: str) -> str:
    rel = path.removeprefix("assets/")
    name = Path(rel).name
    prefix = "art-production/in-use/"
    if rel.startswith(("imported/", "ui/", "scenes/")):
        return prefix + rel
    if rel.startswith("fallback/"):
        return prefix + "fallback/" + name
    if "/scenes/" in rel:
        return prefix + "scenes/concepts/" + name
    if "portrait" in name:
        return prefix + "characters/portraits/" + name
    if "injured" in name or "story_pose" in name:
        return prefix + "characters/story_poses/" + name
    if rel.startswith("kenney/"):
        return prefix + "vfx/" + name
    return prefix + "characters/animations/" + name


def active_source(path: str) -> bool:
    return (path.startswith("scripts/") or path.startswith("scenes/")
            or path.endswith(".tscn")
            or (path.startswith("data/")
                and not path.startswith(("data/native/assets/", "data/templates/"))))


def generate() -> tuple[dict, str, list[str]]:
    references: dict[str, set[str]] = {}
    for path in sorted(GAME.rglob("*")):
        if not path.is_file() or path.suffix not in TEXT_EXTS:
            continue
        origin = path.relative_to(GAME).as_posix()
        if origin.startswith(("assets/", ".godot/")):
            continue
        for match in ASSET_REF.finditer(path.read_text(encoding="utf-8")):
            if active_source(origin):
                references.setdefault(match.group(), set()).add(origin)

    assets = []
    missing = []
    for res_path, used_by in sorted(references.items()):
        if Path(res_path).suffix.lower() not in IMAGE_EXTS or "%" in res_path:
            continue
        relative = res_path.removeprefix("res://")
        source = GAME / relative
        if not source.is_file():
            missing.append(res_path)
            continue
        assets.append({
            "res_path": res_path,
            "used_by": sorted(used_by),
            "production_path": destination(relative),
            "sha256": sha256(source),
            "usage_state": "in_use",  # Keep compatibility with Godot export checks.
        })
    data = {"schema_version": 2, "assets": assets}
    lines = [
        "# 当前使用中的素材", "",
        "本清单只记录游戏当前直接引用的图片；每个 Resource 槽位只绑定一个使用中版本。",
        "候选文件不限数量，不列在这里；生成提示词与目标 Resource 保存在候选目录。",
        "旧副本可留作回退，磁盘中存在不代表仍在使用。", "",
        "使用中图片数：" + str(len(assets)), "",
        "| 图片 | 使用中的 Resource 或脚本 | SHA-256 |",
        "| --- | --- | --- |",
    ]
    for item in assets:
        owners = "、".join(TICK + p + TICK for p in item["used_by"])
        lines.append("| " + TICK + item["res_path"] + TICK + " | "
                     + owners + " | " + TICK + item["sha256"][:12] + TICK + " |")
    lines.append("")
    return data, "\n".join(lines), missing


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check and (not INDEX.is_file() or not REPORT.is_file()):
        print("Missing active inventory output", file=sys.stderr)
        return 1
    data, report, missing = generate()
    if missing:
        print("Missing active images: " + ", ".join(missing), file=sys.stderr)
        return 1
    rendered = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    failures = []
    if args.check:
        if INDEX.read_text(encoding="utf-8") != rendered:
            failures.append("asset-index.json drift")
        if REPORT.read_text(encoding="utf-8") != report:
            failures.append("usage-report.md drift")
    for item in data["assets"]:
        copy = ROOT / item["production_path"]
        if copy.is_file() and sha256(copy) != item["sha256"]:
            failures.append("Different archived copy: " + item["production_path"])
        elif args.check and not copy.is_file():
            failures.append("Missing archived copy: " + item["production_path"])
    if failures:
        for failure in failures:
            print(failure, file=sys.stderr)
        return 1
    if args.write:
        for item in data["assets"]:
            source = GAME / item["res_path"].removeprefix("res://")
            copy = ROOT / item["production_path"]
            if not copy.is_file():
                copy.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, copy)
        INDEX.parent.mkdir(parents=True, exist_ok=True)
        INDEX.write_text(rendered, encoding="utf-8")
        REPORT.write_text(report, encoding="utf-8")
    print(("Checked" if args.check else "Written") + ": in_use=" + str(len(data["assets"])))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
