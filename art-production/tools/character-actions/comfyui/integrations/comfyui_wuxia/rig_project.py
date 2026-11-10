"""Build a local rig project and show its target-joint preview in ComfyUI."""
from pathlib import Path
import subprocess
import sys
import time
from uuid import uuid4

import folder_paths
from character_action_paths import BUNDLE


BUILDER = BUNDLE.parent / "rig2d/scripts/build_rig_project.py"


def local_source_path(value, label, allow_directory=False):
    value = value.strip()
    path = Path(value)
    if not value:
        raise ValueError(f"请填写{label}的本地路径。")
    if "://" in value or path.as_posix().startswith("//"):
        raise ValueError(f"{label}须使用本地文件：{value}")
    path = (BUNDLE / path).resolve()
    if path.as_posix().startswith("//") or not (
        (path.is_file() and path.suffix.lower() == ".json") or (allow_directory and path.is_dir())
    ):
        raise ValueError(f"找不到有效的{label}本地路径：{path}")
    return path


class WuxiaRig2DProject:
    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {
            "parts_path": ("STRING", {"default": "", "tooltip": "已审核的拆件绑定 parts.json，可填写工作流目录下的相对路径。"}),
            "motion_path": ("STRING", {"default": "", "tooltip": "单组、合并的 motion.json，或按动作分子目录存放清单的本地目录。"}),
            "character_id": ("STRING", {"default": "", "tooltip": "角色标识，如 gu_qingshuang。"}),
            "display_name": ("STRING", {"default": "", "tooltip": "角色显示名。"}),
            "action_filter": ("STRING", {"default": "", "tooltip": "留空使用全部动作，填 walk 或 walk,run 选择动作。"}),
        }}

    RETURN_TYPES = ("STRING",)
    RETURN_NAMES = ("project_path",)
    OUTPUT_NODE = True
    FUNCTION = "build"
    CATEGORY = "武侠角色动作/输出"

    @classmethod
    def IS_CHANGED(cls, **inputs):
        # The contents of local files can change without changes to the widget values.
        return float("nan")

    def build(self, parts_path, motion_path, character_id, display_name, action_filter):
        parts = local_source_path(parts_path, "拆件绑定")
        motion = local_source_path(motion_path, "动作", allow_directory=True)
        output = Path(folder_paths.get_output_directory()).resolve()
        run = output / "WuxiaRig2DProject" / f"{time.strftime('%Y%m%d_%H%M%S')}_{uuid4().hex[:8]}"
        argv = [sys.executable, "-X", "utf8", "-s", str(BUILDER),
                "--parts", str(parts), "--motion", str(motion), "--output", str(run),
                f"--character-id={character_id.strip()}", f"--display-name={display_name.strip()}"]
        actions = dict.fromkeys(action.strip() for action in action_filter.split(",") if action.strip())
        argv.extend(f"--action={action}" for action in actions)
        result = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        run.mkdir(parents=True, exist_ok=True)
        log = run / "build-project.log"
        log.write_bytes(result.stdout)
        project = run / "project.json"
        report = run / "report.json"
        preview = run / "skeleton_preview.png"
        if result.returncode or not all(path.is_file() for path in (project, report, preview)):
            detail = result.stdout.decode("utf8", errors="replace").strip()
            evidence = f"报告：{report}\n" if report.is_file() else ""
            raise RuntimeError(f"生成 2D 骨骼工程失败。\n{evidence}日志：{log}\n{detail}")

        message = f"已生成 2D 骨骼工程。\n工程：{project}\n报告：{report}"
        print(message, flush=True)
        return {"ui": {"images": [{"filename": preview.name, "subfolder": run.relative_to(output).as_posix(),
                                   "type": "output"}], "text": [message]}, "result": (str(project),)}
