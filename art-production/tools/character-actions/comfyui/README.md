# ComfyUI 角色动作候选工作流

输入角色原画与动作骨架，按组生成候选帧。原画作为同批参考，输出保留原生画布。规范与正式导入流程见 [角色美术 Skill](../../../skills/wuxia-character-art/SKILL.md) 和 [美术验收合同](../../../standards/SPRITE_ANIMATION_QA.md)。

## 安装

使用 ComfyUI 及其运行环境中的 Python 3.12 或更新版本。02、04、05 的扩散路线需要 FLUX.2 Klein、ReferenceLatent 和 Flux2Scheduler 节点。将 `settings.example.json` 复制为 `settings.local.json`，可填写 ComfyUI 安装目录、模板仓库检出路径和外部模型路径。相对配置路径以本目录为基准。

在本目录运行以下命令。用对应 ComfyUI 安装的 Python 代替 `python`，并填写真实安装位置。

```powershell
git clone https://github.com/yup-21/pose_templates.git <模板检出目录>
python scripts/install_comfy_ui.py --comfy-root <ComfyUI安装目录> --templates-root <模板检出目录>
```

安装器在 ComfyUI 的 `custom_nodes/wuxia_character_actions` 放置指向本目录的加载器，并将 UI 工作流装到 `user/default/workflows/角色动作工作流`。本目录的 `workflows/ComfyUI统一入口` 另有 UI 和 API 两种 JSON。自定义 ComfyUI 用户目录可传 `--user-directory`。已有不同来源的同名加载器时，明确要迁移可加 `--replace-loader`。安装后重启现有 ComfyUI；也可加 `--launch --keep-alive` 启动新的本机实例，默认端口 8189。

模板从 [pose_templates](https://github.com/yup-21/pose_templates) 独立维护。传入检出目录时，03、04、05 自动填入 `comfyui/12-actions/motion.json`。未传入时，可在节点中填写清单或骨架路径。各工作流的角色原画由使用者上传。

## 外部资源

| 用途 | 文件与目录 |
| --- | --- |
| 生图采样 | `models/diffusion_models/flux-2-klein-4b-fp8.safetensors` |
| 姿态引导 | `models/loras/refcontrol-pose-klein-4b.safetensors` |
| 文本编码 | `models/text_encoders/qwen_3_4b_fp4_flux2.safetensors` |
| 图像编解码 | `models/vae/full_encoder_small_decoder.safetensors` |
| 去背景 | `settings.local.json` 中的 `alpha_model`，默认 `resources/alpha/isnet-general-use.onnx` |
| 视频提取与样帧姿态检查 | `settings.local.json` 中的 `pose_model`，默认 `resources/pose/dw-ll_ucoco_384.onnx` |

生成图的四个 ComfyUI 模型名可在 `settings.local.json` 的 `models` 中修改，安装器会重新生成工作流。去背景需要 ONNX Runtime (`onnxruntime`)。姿态检查和视频提取还需要 OpenCV (`opencv-python`)，MP4 等非 GIF 视频的解码使用 PyAV (`av`)。可在 ComfyUI 的 Python 安装依赖，或用 `pose_dependencies` 指定已有的本机依赖目录。已有骨架的预览只需 ComfyUI 自带的 Pillow、NumPy 和 Torch。文字规划可使用已有分镜 JSON，未指定分镜时调用本机已登录的 Codex CLI。

## 工作流

| 入口 | 用途 |
| --- | --- |
| 01 准备与预览骨架 | 预览上传或提取的骨架和固定原画参考 |
| 02 骨架原画生成透明动作帧 | 独立骨架的小范围调试，默认样帧 |
| 03 12 组骨架一次性预览 | 预览整套动作；标准模板含 117 帧 |
| 04 12 组动作批量生成 | 默认直接生成全部，可填 `action_filter` 只跑指定动作 |
| 05 12 组动作样帧校准 | 每组抽代表帧并记录姿态与透明度检查 |
| 06 2D 骨骼渲染 | 用 Blender 将本地拆件工程渲染为透明 PNG，按动作分组 |

输出可在 ComfyUI 画廊查看，完整清单与逐帧证据位于本目录的 `outputs`。04 的候选如果边距不足或去背景失败，报告与画廊会标明相应状态。尺寸以骨架清单和实际角色身高为准，参考骨架默认采用 384×288。姿态、透明与模型检查属于候选验收的一部分，最终仍按角色美术 Skill 做目视与 Godot 实速复核。

### 06 2D 骨骼渲染

在工作流列表打开 `06_2D骨骼渲染`，把 `project_path` 填为本地 [2D 拆件工程](../rig2d/README.md)的 `project.json` 路径。路径可用绝对路径或相对于本目录，留空使用 `WUXIA_RIG_PROJECT`。Blender 可放在工作区的 `tools/blender/blender-*/blender.exe` 或加入 ComfyUI 进程的 `PATH`。此入口只需 Blender 与 ComfyUI 自带的 Pillow。

`action_filter` 留空处理工程中的全部动作，或填 `walk`、`walk,run` 选择动作。需要试用替代部件或单组动作清单时，可填 `parts_override` 或 `motion_override`，相对路径从 `project.json` 所在目录解析。

运行后画布预览原生 RGBA PNG。实际文件保存在 ComfyUI 输出目录的 `WuxiaRig2D/<批次>/<动作>/frames`，同批还包含带原动作时序的灰底 GIF、HTML 预览页、Blender 工程和技术检查报告。尺寸和根点由拆件工程决定。输出保持美术候选状态。
