#!/usr/bin/env python3
"""Inspect the actual Godot art bindings; no second runtime asset registry."""
from __future__ import annotations
import argparse
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
    for path in bindings:
        if not path.startswith("res://assets/imported/"):
            errors.append("Legacy art path still referenced: " + path)
        if ".." in path or not (GAME / path.removeprefix("res://")).is_file():
            errors.append("Missing / unsafe imported art: " + path)
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
