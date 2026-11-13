"""Run the local Blender rig renderer and expose its original RGBA frames."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from uuid import uuid4

import folder_paths
from character_action_paths import BUNDLE


RUNNER = BUNDLE.parent / "rig2d/scripts/run_workflow.py"


class WuxiaRig2DRender:
    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {
            "project_path": ("STRING", {"default": "", "tooltip": "拆件角色的 project.json。留空使用 WUXIA_RIG_PROJECT。"}),
            "action_filter": ("STRING", {"default": "", "tooltip": "留空渲染全部。填 walk 或 walk,run 选择动作。"}),
            "parts_override": ("STRING", {"default": "", "tooltip": "可选。相对于 project.json 所在目录，留空使用工程部件。"}),
            "motion_override": ("STRING", {"default": "", "tooltip": "可选。仅限单组动作，相对于 project.json 所在目录。"}),
        }}

    RETURN_TYPES = ("STRING",)
    RETURN_NAMES = ("批次报告路径",)
    OUTPUT_NODE = True
    FUNCTION = "render"
    CATEGORY = "武侠角色动作/输出"

    @classmethod
    def IS_CHANGED(cls, **inputs):
        # Project files can be edited between queues without changing widget values.
        return float("nan")

    def render(self, project_path, action_filter, parts_override, motion_override):
        value = project_path.strip() or os.environ.get("WUXIA_RIG_PROJECT")
        if not value:
            raise ValueError("请填写角色工程 project.json 的路径，或设置 WUXIA_RIG_PROJECT。")
        project = (BUNDLE / value).resolve()
        if not project.is_file():
            raise ValueError(f"找不到角色工程 JSON：{project}")
        actions = list(dict.fromkeys(a.strip() for a in action_filter.split(",") if a.strip()))
        output = Path(folder_paths.get_output_directory()).resolve()
        run = output / "WuxiaRig2D" / (time.strftime("%Y%m%d_%H%M%S") + "_" + uuid4().hex[:8])
        argv = [sys.executable, "-X", "utf8", "-s", str(RUNNER),
                "--project", str(project), "--output", str(run)]
        for action in actions:
            argv.extend(("--action", action))
        for flag, value in (("--parts-override", parts_override), ("--motion-override", motion_override)):
            if value.strip():
                argv.extend((flag, str((project.parent / value.strip()).resolve())))

        result = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        run.mkdir(parents=True, exist_ok=True)
        log = run / "render-batch.log"
        log.write_bytes(result.stdout)
        report_path = run / "批次报告.json"
        if result.returncode not in (0, 1) or not report_path.is_file():
            detail = result.stdout.decode("utf8", errors="replace").strip()
            raise RuntimeError(f"2D 骨骼渲染失败。日志：{log}\n{detail}")

        report = json.loads(report_path.read_text("utf8"))
        if report["inputs_changed"]:
            raise RuntimeError(f"渲染期间工程输入有变化，请重新排队。报告：{report_path}")
        previews = []
        for action, info in report["actions"].items():
            if info["status"] == "error":
                continue
            frames = run / action / "frames"
            previews.extend(
                {"filename": f"{action}_{index:03d}.png",
                 "subfolder": frames.relative_to(output).as_posix(), "type": "output"}
                for index in range(info["frames"])
            )
        if not previews:
            raise RuntimeError(f"各动作均渲染失败。报告：{report_path}")
        status = "待复核" if report["status"] == "needs_review" else "候选"
        message = f"已保存 {len(previews)} 张透明帧（{status}）。\n{report_path}"
        print(message, flush=True)
        return {"ui": {"images": previews, "text": [message]}, "result": (str(report_path),)}
