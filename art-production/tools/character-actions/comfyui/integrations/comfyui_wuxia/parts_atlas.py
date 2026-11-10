"""Guide FLUX.2 with the rig's atlas layout and save artwork for review."""
import json
from pathlib import Path
import time
from uuid import uuid4

import folder_paths
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps
import torch

from character_action_paths import ALPHA_MODEL, POSE_DEPS
from character_alpha import process_frame


ATLAS_SIZE = (1536, 1024)


def resolve_template(value):
    if not value.strip():
        raise ValueError("请填写 parts_template，或使用 --templates-root 安装工作流。")
    path = Path(value).expanduser().resolve()
    if not path.is_file():
        raise ValueError(f"找不到部件布局模板：{path}")
    return path


class WuxiaPartsAtlasGuide:
    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {
            "character": ("STRING", {"forceInput": True}),
            "parts_template": ("STRING", {"default": ""}),
            "identity_notes": ("STRING", {"default": "", "multiline": True}),
        }}

    RETURN_TYPES = ("IMAGE", "STRING", "IMAGE")
    RETURN_NAMES = ("部件布局参考", "拆件绘图提示词", "角色原画")
    FUNCTION = "prepare"
    CATEGORY = "武侠角色动作/输入"

    @classmethod
    def IS_CHANGED(cls, character, parts_template, identity_notes):
        from . import resolve_input, sha

        portrait = resolve_input(character)
        if portrait is None:
            return float("nan")
        return sha(portrait), sha(resolve_template(parts_template))

    def prepare(self, character, parts_template, identity_notes):
        from . import resolve_input

        path = resolve_input(character)
        if path is None:
            raise ValueError("请先上传角色原画。")
        with Image.open(path) as source:
            portrait = ImageOps.exif_transpose(source).convert("RGBA")
        background = Image.new("RGBA", portrait.size, "#f5f5f5")
        background.alpha_composite(portrait)

        parts = json.loads(resolve_template(parts_template).read_text("utf-8"))["parts"]
        image = Image.new("RGB", ATLAS_SIZE, "#f5f5f5")
        draw = ImageDraw.Draw(image)
        font = ImageFont.load_default(size=20)
        for part in parts:
            polygon = [tuple(point) for point in part["polygon"]]
            draw.polygon(polygon, fill="#a6c8d8", outline="#344e64", width=3)
        for part in parts:
            polygon = part["polygon"]
            left = min(point[0] for point in polygon)
            top = min(point[1] for point in polygon)
            draw.text((left + 4, top + 2), part["name"], fill="#152231", font=font)
        guide = image.resize((768, 512), Image.Resampling.LANCZOS)
        prompt = (
            "Paint a modular sprite-parts atlas for a right-facing 90-degree orthographic side-view game character. "
            "Image 1 is the labeled part layout; image 2 is the character reference. "
            "Preserve the character's face, hair, clothing, palette and painterly style. "
            "Paint exactly one matching detached part in each indicated region, keeping its position and orientation. "
            "Paint the hidden joint overlap at shoulders, elbows, wrists, knees and ankles. "
            "Right hand grips one straight sword, left hand is empty; keep the sword and tassel separate. "
            "Use a flat light neutral background with gaps between parts. Omit labels, guides, shadows and assembled figures."
        )
        if identity_notes.strip():
            prompt += " Character details: " + identity_notes.strip()
        return (
            torch.from_numpy(np.asarray(guide, dtype=np.float32) / 255).unsqueeze(0),
            prompt,
            torch.from_numpy(np.asarray(background.convert("RGB"), dtype=np.float32) / 255).unsqueeze(0),
        )


class WuxiaPartsAtlasOutput:
    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {"images": ("IMAGE",)}, "hidden": {"prompt": "PROMPT"}}

    RETURN_TYPES = ("STRING",)
    RETURN_NAMES = ("检查报告",)
    OUTPUT_NODE = True
    FUNCTION = "save"
    CATEGORY = "武侠角色动作/输出"

    def save(self, images, prompt=None):
        width, height = ATLAS_SIZE
        if tuple(images.shape) != (1, height, width, 3):
            raise ValueError(f"拆件图集须为单张原生 {width}×{height} RGB 图。")
        output = Path(folder_paths.get_output_directory()).resolve()
        run = output / "WuxiaPartsAtlas" / (time.strftime("%Y%m%d_%H%M%S") + "_" + uuid4().hex[:8])
        run.mkdir(parents=True)
        raw = run / "atlas_raw.png"
        rgba = run / "atlas_candidate.png"
        pixels = np.rint(np.clip(images[0].detach().cpu().numpy(), 0, 1) * 255).astype(np.uint8)
        Image.fromarray(pixels).save(raw)
        report = {"status": "candidate", "binding_ready": False, "prompt_graph": prompt, "alpha_ok": False}
        try:
            result = process_frame(raw, rgba, ALPHA_MODEL, POSE_DEPS, keep_margin_failure=True)
            report.update(alpha_ok=result["ok"], alpha_report=Path(result["report_path"]).name)
        except Exception as error:
            report["alpha_error"] = str(error)
        report_path = run / "review.json"
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", "utf-8")
        preview = rgba if rgba.is_file() else raw
        status = "已保存去背景候选" if rgba.is_file() else "去背景失败，已保存原始稿"
        message = f"{status}。请检查部件位置和接缝后再生成绑定清单。\n{report_path}"
        return {"ui": {"images": [{"filename": preview.name, "subfolder": run.relative_to(output).as_posix(),
                                   "type": "output"}], "text": [message]}, "result": (str(report_path),)}
