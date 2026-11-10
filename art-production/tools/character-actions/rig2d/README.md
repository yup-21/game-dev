# Blender 2D 角色动作工作流

以独立的朝右 90° 侧视拆件作为纹理，用动作清单驱动固定长度的关节链。原立绘只供角色外观参考。当前绑定适用于右手持单剑、左手空的平面角色。支持原生 328×256 或 384×288，同一角色的动作共享整数根点和地线。

## 本机运行

需要 Blender 和安装了 Pillow 的 Python。Windows 可直接执行以下命令。工具会优先查找工作区相邻的 `tools`，也可显式指定 Blender 和 Python。

```powershell
.\生成2D骨骼动画.cmd -Project 'C:\角色项目\project.json' -Action walk -CheckOnly
.\生成2D骨骼动画.cmd -Project 'C:\角色项目\project.json' -Action walk,attack_thrust
.\生成2D骨骼动画.cmd -Project 'C:\角色项目\project.json'
```

可选参数包括 `-Blender`、`-Python`、`-Jobs`、`-Output`。把本地项目路径设为 `WUXIA_RIG_PROJECT` 后，双击 CMD 就可使用该项目。不传动作参数会处理清单中的全部动作。每次生成使用新的输出目录，包含透明 PNG、GIF、Blender 工程、预览页和批次报告。预检执行真实绑定求解，成图阶段另外检查 PNG 的 Alpha、8 px 透明边距和剑轴覆盖。失败记录保留在本批。

可用 Python 直接运行 `scripts/run_workflow.py --project <路径> --action walk`，适用于已有 Blender 和 Pillow 的环境。

已具备部件清单和动作坐标时，也可用 [ComfyUI 08](../comfyui/README.md) 生成工程，或运行 `python scripts/build_rig_project.py --parts <部件清单> --motion <动作清单或目录> --output <新工程目录> --character-id <角色ID> --display-name <显示名>`。输出可交给 06 或上面的命令行渲染入口。

## 准备一个角色项目

1. 克隆 [pose_templates](https://github.com/yup-21/pose_templates.git)。使用 `rig2d/parts-template` 里的 SVG 和清单模板制作拆件图集。补画肩窝、肘部、腕部和衣摆被挡住的区域。
2. 在独立角色目录放入 `parts.json`、带 Alpha 的 PNG 纹理和 `motion/<动作ID>/motion.json`。每个部件声明纹理、`pivot`、`axis`、固定长度和层级。重新绘制纹理后重新标定关节，更新图集 SHA-256。
3. 保存下面形式的 `project.json`，填入你的实际动作列表。路径相对于项目文件。可用 `rig2d/gu-qingshuang-v6/motion` 对照骨架字段或在同一骨长的试样上复用。

```json
{
  "schema_version": 1,
  "character_id": "my_character",
  "display_name": "我的角色",
  "parts": "parts.json",
  "motion_dir": "motion",
  "actions": {"idle": "待机", "walk": "行走", "attack_thrust": "直刺"}
}
```

## 手臂和补件

见[骨骼动作优化方法](骨骼动作优化方法.md)。先分别调整肩、肘和腕的运动节奏，再检查剪影、袖口和握点。渲染器支持 `shoulder_overlaps`、`elbow_cuffs`、独立剑穗、肩位移、手腕角度和衣摆运动。备选手型的逐帧切换仍需独立实现。

`scripts/build_arm_example.py --project <项目> --patch <肩片UV补丁>` 可生成肩腕试样，要求补丁标注的图集 SHA-256 与项目一致。生成后用 `-Action walk -PartsOverride parts_with_shoulders.json -MotionOverride walk_shoulder_wrist.json` 单独比较。其他角色须重新画或标定肩片。

### 可选的发梢／衣摆柔性试样

传统拆件会把整片发束、前后衣摆当成刚体旋转。需要对比局部弯曲时，在同级的替代 `parts.json` 中增加 `"soft_deformation": ["hair", "front_hem", "back_hem"]`，对应部件使用矩形 UV 区域。动作每帧可填写：

- `rig_soft_bend_degrees`：部件名 → 局部弯曲角度（度）。
- `rig_soft_tip_px`：部件名 → 自锚点向末端渐增的局部水平形变（源像素）。

Blender 为这些部件建立细分网格与可编辑形态键；源贴图、关节骨长、逻辑根点、动作时长和帧数均不更改。不填写时仍按原刚性拆件渲染。此功能用于候选效果对照，不能替代重新绘制肩窝、袖内衬和裙摆遮挡纹理；角度或末端位移过大可能产生不自然拉伸。先针对单个 `walk` 或 `attack_thrust` 用 `-PartsOverride` 和 `-MotionOverride` 对照预览。
