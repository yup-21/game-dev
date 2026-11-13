"""Run or preflight a local 2D rig project, one action or the full set."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from hashlib import sha256
from html import escape
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from uuid import uuid4

from PIL import Image

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
TOOLS = ROOT.parents[3].parent / "tools"
ID = re.compile(r"[a-z][a-z0-9_]{0,63}")
sys.path.insert(0, str(SCRIPTS))
from verify_preview import inspect


def read(path):
    return json.loads(path.read_text("utf-8-sig"))


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", "utf8")


def child(root, value):
    path = (root / value).resolve(strict=True)
    if not path.is_relative_to(root):
        raise ValueError(f"输入必须位于角色项目目录内：{value}")
    return path


def blender_path(explicit):
    if explicit:
        return Path(explicit).resolve(strict=True)
    candidates = sorted((TOOLS / "blender").glob("blender-*/blender.exe"), reverse=True)
    system = shutil.which("blender")
    if candidates:
        return candidates[0]
    if system:
        return Path(system)
    raise FileNotFoundError("未找到 Blender，请通过 -Blender 或 --blender 指定 blender.exe。")


def validate_parts(root, manifest):
    if not manifest.is_file():
        raise ValueError("部件清单应为 JSON 文件")
    art = read(manifest)
    atlas = child(root, art["generated_atlas"]["path"])
    if digest(atlas) != art["generated_atlas"]["sha256"]:
        raise ValueError("图集 SHA-256 与 parts.json 不一致")
    paths = {atlas, manifest}
    for part in art["parts"]:
        paths.add(child(root, part["texture"]))
    for path in paths - {manifest}:
        with Image.open(path) as im:
            if im.format != "PNG" or im.mode != "RGBA":
                raise ValueError(f"需要真实 RGBA PNG：{path}")
            lo, hi = im.getchannel("A").getextrema()
            if lo != 0 or hi < 128:
                raise ValueError(f"部件需要透明背景和有效内容：{path}")
    return {path: digest(path) for path in paths}


def review_page(out, project, results):
    cards = []
    for action, info in results.items():
        label = escape(project["actions"][action])
        if info["status"] == "error":
            cards.append(f'<article><h2>{label}</h2><p>运行失败</p><a href="{action}/render.log">日志</a></article>')
            continue
        status = "候选" if info["status"] == "candidate" else "需检查"
        cards.append(f'<article><h2>{label}</h2><p>{info["frames"]} 帧 · {info["duration_ms"]} ms · {status}</p>'
                     f'<img src="{action}/{action}_preview.gif" alt="{label}">'
                     f'<p><button type="button">重播</button> · <a href="{action}/frames/">透明帧</a> · '
                     f'<a href="{action}/{project["character_id"]}_{action}.blend">Blender</a></p></article>')
    title = escape(project["display_name"])
    html = f"""<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>{title}</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{{background:#141822;color:#edf0f5;font:16px system-ui;margin:24px}}
main{{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,300px),1fr));gap:16px}}
article{{padding:12px;background:#212836;border-radius:8px}}article img{{width:100%}}a{{color:#abdcff}}</style>
<h1>{title}</h1><main>{''.join(cards)}</main>
<script>for(const b of document.querySelectorAll("button")){{
 const img=b.closest("article").querySelector("img"), src=img.getAttribute("src");
 b.addEventListener("click",()=>{{img.removeAttribute("src");requestAnimationFrame(()=>{{img.src=src;}});}});
}}</script></html>"""
    (out / "动作预览.html").write_text(html, "utf8")


def render_one(blender, project, parts, motion, action, folder, check_only):
    folder.mkdir()
    log = folder / "render.log"
    argv = [str(blender), "--background", "--factory-startup", "--python-exit-code", "1",
            "--python", str(SCRIPTS / "render_rig.py"), "--", "--parts", str(parts),
            "--motion", str(motion), "--character-id", project["character_id"]]
    argv += ["--check-only"] if check_only else ["--output", str(folder)]
    with log.open("wb") as stream:
        result = subprocess.run(argv, stdout=stream, stderr=subprocess.STDOUT, check=False)
    if result.returncode:
        raise RuntimeError(f"Blender 退出码 {result.returncode}，见 {log}")
    if check_only:
        lines = log.read_text("utf8", errors="replace").splitlines()
        record = next(line.removeprefix("RIG_PREFLIGHT ") for line in lines if line.startswith("RIG_PREFLIGHT "))
        return {"status": "preflight", **json.loads(record)}
    report, preview, timing, receipt = inspect(folder)
    mode = {"loop": 0} if receipt["loop"] else {}
    preview[0].save(folder / f"{action}_preview.gif", save_all=True,
                    append_images=preview[1:], duration=timing, **mode)
    keys = ("sword_grip_error_px", "left_wrist_reach_correction_px",
            "left_boot_reach_correction_px", "right_boot_reach_correction_px")
    maximum = {key: max(f["diagnostics"][key] for f in receipt["frames"]) for key in keys}
    report["maximum_reach_corrections_px"] = maximum
    n = len(receipt["frames"])
    passed = report["pass_8px_margin_count"] == report["sword_axis_coverage_frames"] == n and max(maximum.values()) <= .05
    save(folder / "geometry_report.json", report)
    return {"status": "candidate" if passed else "needs_review", "frames": n,
            "duration_ms": report["duration_ms"], "min_margin_px": report["min_margin_px"],
            "max_reach_correction_px": max(maximum.values()), "motion_sha256": receipt["motion_sha256"]}


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--project", type=Path,
                     default=os.environ.get("WUXIA_RIG_PROJECT") or ROOT / "project.json")
    cli.add_argument("--action", action="append", help="Repeat to select multiple actions; default all")
    cli.add_argument("--parts-override", type=Path, help="Alternate manifest next to parts.json")
    cli.add_argument("--motion-override", type=Path, help="Alternate motion for exactly one selected action")
    cli.add_argument("--blender", type=Path)
    cli.add_argument("--output", type=Path)
    cli.add_argument("--jobs", type=int, choices=(1, 2, 3, 4), default=2)
    cli.add_argument("--check-only", action="store_true")
    args = cli.parse_args()
    if not args.project.is_file():
        cli.error("请用 --project 指向角色项目的 project.json，或设置 WUXIA_RIG_PROJECT。")
    project_path = args.project.resolve(strict=True)
    base = project_path.parent
    project = read(project_path)
    actions = project["actions"]
    if project["schema_version"] != 1 or not ID.fullmatch(project["character_id"]):
        raise ValueError("角色项目版本或 character_id 不合法")
    if not actions or any(not ID.fullmatch(a) or not isinstance(label, str) for a, label in actions.items()):
        raise ValueError("actions 应为合法动作 ID 到显示名称的映射")
    selected = list(dict.fromkeys(args.action or actions))
    if set(selected) - actions.keys() or (args.motion_override and len(selected) != 1):
        raise ValueError("动作不存在，或给多组动作指定了单份替代清单")
    parts = child(base, args.parts_override or project["parts"])
    if parts.parent != base:
        raise ValueError("parts.json 必须与 project.json 在同一目录")
    hashes = validate_parts(base, parts)
    motion_dir = child(base, project["motion_dir"])
    motions, shared_geometry = {}, None
    for action in selected:
        path = child(base, args.motion_override or motion_dir / action / "motion.json")
        doc = read(path)
        if doc["action_id"] != action or len(doc["frames"]) != doc["frame_count"]:
            raise ValueError(f"动作清单分组或帧数不匹配：{path}")
        geometry = (doc["canvas"], doc["logical_origin"])
        if shared_geometry is not None and geometry != shared_geometry:
            raise ValueError("同一角色动作必须共享画布和根点")
        shared_geometry = geometry
        motions[action] = path
        hashes[path] = digest(path)
    blender = blender_path(args.blender)
    batch = datetime.now().strftime("%Y%m%d_%H%M%S") + "_" + uuid4().hex[:8]
    out = (args.output or ROOT / "outputs" / batch).resolve()
    out.mkdir(parents=True, exist_ok=False)
    print(f"输出目录 {out}", flush=True)

    def one(action):
        try:
            info = render_one(blender, project, parts, motions[action], action, out / action, args.check_only)
            if args.check_only and info["max_reach_correction_px"] > .05:
                info["status"] = "needs_review"
        except Exception as exc:
            info = {"status": "error", "message": str(exc)}
        print(f"{action} {info['status']}", flush=True)
        return info

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = dict(zip(selected, pool.map(one, selected)))
    changed = [str(path) for path, expected in hashes.items() if not path.is_file() or digest(path) != expected]
    bad = [action for action, row in results.items() if row["status"] in {"needs_review", "error"}]
    save(out / "批次报告.json", {
        "status": "needs_review" if bad or changed else "preflight" if args.check_only else "candidate",
        "project": str(project_path), "parts": str(parts), "frame_count": sum(r.get("frames", 0) for r in results.values()),
        "inputs_changed": changed, "actions": results,
    })
    if not args.check_only:
        review_page(out, project, results)
    return int(bool(bad or changed))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError) as exc:
        print(f"无法启动：{exc}", file=sys.stderr)
        sys.exit(2)
