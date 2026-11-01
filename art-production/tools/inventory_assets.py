#!/usr/bin/env python3
"""Regenerate the offline Godot art inventory; never used by the game runtime."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "demos/changfeng-battle"
INDEX = ROOT / "art-production/inventory/asset-index.json"
REPORT = ROOT / "art-production/inventory/usage-report.md"
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".svg"}
TEXT_EXTS = {".gd", ".tres", ".tscn", ".godot", ".cfg", ".json"}
ASSET_REF = re.compile(r"""res://assets/[^"'\s)\],}]+""")
SOURCE_PREFIX = "demos/changfeng-battle/"
TICK = chr(96)


def assignment(text: str, key: str) -> str:
    match = re.search(r"(?m)^" + re.escape(key) + r'\s*=\s*"([^"]*)"', text)
    return match.group(1) if match else ""


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git_blob_sha1(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def sources() -> dict[str, str]:
    result = {}
    for path in sorted(GAME.rglob("*")):
        if path.is_file() and path.suffix in TEXT_EXTS:
            name = path.relative_to(GAME).as_posix()
            if not name.startswith("assets/") and not name.startswith(".godot/"):
                result[name] = path.read_text(encoding="utf-8")
    return result


def destination(path: str) -> str:
    rel = path.removeprefix("assets/")
    name = Path(rel).name
    prefix = "art-production/in-use/"
    if rel.startswith("fallback/"):
        return prefix + "fallback/" + name
    if rel.startswith("ui/"):
        return prefix + rel
    if rel.startswith("scenes/"):
        return prefix + rel
    if "/scenes/" in rel:
        return prefix + "scenes/concepts/" + name
    if "portrait" in name:
        return prefix + "characters/portraits/" + name
    if "injured" in name or "story_pose" in name:
        return prefix + "characters/story_poses/" + name
    if rel.startswith("kenney/"):
        return prefix + "vfx/" + name
    return prefix + "characters/animations/" + name


def kind(path: str) -> str:
    if path.startswith("assets/fallback/"):
        return "fallback"
    if path.startswith("assets/ui/"):
        return "ui"
    if path.startswith("assets/scenes/") or "/scenes/" in path:
        return "scene"
    if path.startswith("assets/kenney/"):
        return "third_party"
    if "portrait" in path:
        return "portrait"
    if "injured" in path:
        return "story_pose"
    return "animation"


def usage(origins: set[str]) -> tuple[str, dict]:
    active = sorted(p for p in origins if p.startswith("scripts/")
                    or p.startswith("scenes/") or p.endswith(".tscn")
                    or (p.startswith("data/") and not p.startswith("data/native/assets/")
                        and not p.startswith("data/templates/")))
    registered = sorted(p for p in origins if p.startswith("data/native/assets/"))
    tests = sorted(p for p in origins if p.startswith("checks/"))
    templates = sorted(p for p in origins if p.startswith("data/templates/"))
    state = ("in_use" if active else "registered_only" if registered
             else "test_only" if tests else "template_only" if templates else "unreferenced")
    return state, {"runtime": active, "registrations": registered,
                   "tests": tests, "templates": templates}


def generate(commit: str) -> tuple[dict, str]:
    texts = sources()
    refs: dict[str, set[str]] = {}
    for name, text in texts.items():
        for match in ASSET_REF.finditer(text):
            refs.setdefault(match.group(), set()).add(name)
    manifest = json.loads((GAME / "assets/production_manifest.json").read_text(encoding="utf-8"))
    provenance: dict[str, list[dict]] = {}
    for record in manifest.get("assets", []):
        provenance.setdefault(record["path"], []).append({
            "record": "assets/production_manifest.json",
            "id": record.get("id", ""), "status": record.get("status", ""),
            "source": record.get("source", ""), "rights": record.get("rights", ""),
        })
    for name, text in texts.items():
        if name.startswith("data/native/assets/"):
            for match in ASSET_REF.finditer(text):
                provenance.setdefault(match.group(), []).append({
                    "record": name, "id": assignment(text, "content_id"),
                    "status": assignment(text, "status"),
                    "source": assignment(text, "source"),
                    "rights": assignment(text, "rights"),
                    "owner_character_id": assignment(text, "owner_character_id"),
                })
    items = []
    for path in sorted((GAME / "assets").rglob("*")):
        if not path.is_file() or path.suffix.lower() not in IMAGE_EXTS:
            continue
        rel = path.relative_to(GAME).as_posix()
        res = "res://" + rel
        raw = path.read_bytes()
        state, references = usage(refs.get(res, set()))
        records = provenance.get(res, [])
        statuses = sorted({r["status"] for r in records if r["status"]})
        rights = sorted({r["rights"] for r in records if r["rights"]})
        approved = bool(records) and all(
            r["status"] == "approved" and r["rights"] == "verified" for r in records)
        items.append({
            "source_path": SOURCE_PREFIX + rel,
            "res_path": res,
            "production_path": destination(rel) if state == "in_use" else None,
            "kind": kind(rel),
            "usage_state": state,
            "review_state": "approved" if approved else "review_required",
            "registered_statuses": statuses,
            "rights": rights or ["unknown"],
            "source_records": records,
            "sha256": sha256(raw),
            "git_blob_sha1": git_blob_sha1(raw),
            "size_bytes": len(raw),
            "references": references,
        })
    by_digest: dict[str, list[str]] = {}
    for item in items:
        by_digest.setdefault(item["sha256"], []).append(item["source_path"])
    dupes = [{"sha256": h, "paths": paths}
             for h, paths in sorted(by_digest.items()) if len(paths) > 1]
    missing = sorted(ref for ref in refs if Path(ref).suffix.lower() in IMAGE_EXTS
                     and "%" not in ref and not (GAME / ref.removeprefix("res://")).is_file())
    result = {
        "schema_version": 1,
        "purpose": "Offline production inventory only; Godot .tres is the runtime source of truth.",
        "source_snapshot": {
            "repository": "yup-21/game-dev", "commit": commit,
            "project_root": SOURCE_PREFIX.rstrip("/"),
        },
        "usage_states": {
            "in_use": "Statically referenced by a non-test game Resource, scene, or runtime script.",
            "registered_only": "Only referenced by an asset registration Resource; not proven displayed.",
            "test_only": "Only referenced by test code.",
            "template_only": "Only referenced by authoring templates.",
            "unreferenced": "No static asset reference detected; dynamic loads may not be visible.",
        },
        "missing_image_references": missing,
        "duplicate_groups": dupes,
        "assets": items,
    }
    return result, report_text(result)


def report_text(result: dict) -> str:
    items = result["assets"]
    lines = [
        "# 游戏美术素材使用清单", "",
        "源版本：" + TICK + result["source_snapshot"]["commit"] + TICK, "",
        "由 art-production/tools/inventory_assets.py 生成，检查 Godot Resource、场景与脚本的静态 res://assets/ 引用。",
        "in_use 表示被游戏正式资源或脚本直接引用，不保证每局都显示，更不等于 approved。",
        "registered_only 仅在资产登记卡中出现；test_only 不计入正式游戏。",
        "动态路径、运行条件、编辑器临时载入需人工补充验证。", "",
        "| 使用状态 | 文件数 | 总字节数 |", "| --- | ---: | ---: |",
    ]
    for state in result["usage_states"]:
        group = [item for item in items if item["usage_state"] == state]
        lines.append(f"| {state} | {len(group)} | {sum(x['size_bytes'] for x in group)} |")
    lines += ["", f"SHA-256 重复内容组：{len(result['duplicate_groups'])}",
              f"静态图像缺失引用：{len(result['missing_image_references'])}", "",
              "## 当前直接引用（已复制）", "",
              "| Godot 来源 | 制作区副本 | 审核 |", "| --- | --- | --- |"]
    for item in items:
        if item["usage_state"] == "in_use":
            lines.append(f"| {TICK}{item['res_path']}{TICK} | {TICK}{item['production_path']}{TICK} | {item['review_state']} |")
    lines += ["", "## 仅登记 / 测试专用", ""]
    for item in items:
        if item["usage_state"] in ("registered_only", "test_only", "template_only"):
            lines.append(f"- {item['usage_state']}: {TICK}{item['res_path']}{TICK}")
    lines += ["", "## 使用注意", "",
              "- in-use 副本与原始图像逐字节相同；不修改游戏的 .tres 或资源路径。",
              "- SHA-256 用于内容检查，git_blob_sha1 用于 Git 源文件核对。",
              "- review_required 表示尚未有完整美术、动作和授权验收，不得当作 approved。",
              "- 如 assets/ui/original/painted/card_%s.png 这种动态候选路径，不代表图像已存在。",
              "- 美术审核与真实运行时的动态路径覆盖仍需后续人工核对。", ""]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    parser.add_argument("--source-commit", help="Pinned source commit for a new snapshot")
    args = parser.parse_args()
    if args.check:
        if not INDEX.is_file() or not REPORT.is_file():
            print("Missing inventory output", file=sys.stderr)
            return 1
        commit = json.loads(INDEX.read_text(encoding="utf-8"))["source_snapshot"]["commit"]
    else:
        commit = args.source_commit or subprocess.check_output(
            ["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
    data, report = generate(commit)
    rendered = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    if data["missing_image_references"]:
        print("Missing images: " + ", ".join(data["missing_image_references"]), file=sys.stderr)
        return 1
    if args.check:
        failures = []
        if INDEX.read_text(encoding="utf-8") != rendered:
            failures.append("asset-index.json drift")
        if REPORT.read_text(encoding="utf-8") != report:
            failures.append("usage-report.md drift")
        for item in data["assets"]:
            if item["usage_state"] != "in_use":
                continue
            copy = ROOT / item["production_path"]
            if not copy.is_file() or sha256(copy.read_bytes()) != item["sha256"]:
                failures.append("Missing or stale copy: " + item["production_path"])
        for failure in failures:
            print(failure, file=sys.stderr)
        if failures:
            return 1
    else:
        # Refuse altered destinations; never overwrite hand-edited art.
        for item in data["assets"]:
            if item["usage_state"] == "in_use":
                copy = ROOT / item["production_path"]
                if copy.exists() and sha256(copy.read_bytes()) != item["sha256"]:
                    print("Refusing to overwrite: " + str(copy), file=sys.stderr)
                    return 1
        for item in data["assets"]:
            if item["usage_state"] == "in_use":
                copy = ROOT / item["production_path"]
                copy.parent.mkdir(parents=True, exist_ok=True)
                if not copy.exists():
                    shutil.copy2(ROOT / item["source_path"], copy)
        INDEX.parent.mkdir(parents=True, exist_ok=True)
        INDEX.write_text(rendered, encoding="utf-8")
        REPORT.write_text(report, encoding="utf-8")
    counts = {state: sum(item["usage_state"] == state for item in data["assets"])
              for state in data["usage_states"]}
    print(("Checked" if args.check else "Written") + ": " + str(counts))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
