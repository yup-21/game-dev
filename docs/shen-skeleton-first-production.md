# 沈长风：骨架先行制作流程

此原型以 **可编辑的 Godot 原生 Bone2D 骨架为唯一骨点来源**，拒绝“根据生成的完整人物 PNG 猜关节位置”。

## 1. 骨架定稿（当前阶段）

- 打开 `res://prototypes/shen_rig_first/shen_skeleton_first.tscn`。
- 当前场景不引用任何沈长风立绘或旧矩形裁片。骨骼在场景树中是真正的 `Skeleton2D/Bone2D` 节点。
- 右向侧身、脚底原点 `(0,0)`、可见角色高度 `200px`；距离单位仍以 `CombatScale.PIXELS_PER_UNIT = 80` 定义。
- `B`：还原标准绑定姿势；`1`：待机；`2`：行走；`3`：简单前劈。
- 画面中的半透明部件只是 **尺寸/挂点指导区**，不是正式角色素材或已完成 Mesh 蒙皮。
- 攻击骨骼从 `FrontShoulder → FrontElbow → FrontWrist → FrontHand → SwordGrip → SwordBlade` 传递旋转；不再以整块持剑手臂贴图绕角落转动。

## 2. 从骨架生成素材绘制规范

源文件：`rig_contract.json`。它记录每个骨点的绝对世界像素坐标，以及 20 类素材的绑定部位、宽度、关节遮挡安全区、前后层级。

生成命令：

```bash
python3 tools/build_shen_rig_art_templates.py
```

输出：`demos/changfeng-battle/captures/shen-rig-first/art-templates/`。

- `master-rig-template.svg`：透明标准全身骨架和 20 件部件的尺寸参考。
- `art_frames.json`：每件素材的 **独立透明画布尺寸、画布内 pivot、原点世界位置、z_index 和关节重叠**。
- `per-part-svg/*.svg`：每个部件对应的独立透明绘制参考；它们是用于绘制的框和骨点，不是把旧人物裁成的“成品”。

**正式素材生产规则**：只在这些模板内重新绘制完整透明部件，每件 PNG 使用 `art_frames.json` 给定的画布尺寸与 pivot，不自行裁切导致枢轴漂移。被袖子和衣摆遮挡的肩肘膝附近必须补足重叠区。武器作为独立 Sprite 绑定到 `SwordGrip`，剑尖对应 `SwordBlade`。角色仍采用已有沈长风外观/服装作为风格参考，不改变角色设定。

当前模板采用 4x 画稿分辨率（200 游戏世界像素 → 800 源像素角色高度）；游戏内统一缩回 200px，不改变移动、攻击距离。所有部件统一只有 `candidate` / `in_use` 两种管理状态，这一轮均保持 `candidate`。

## 3. 自动验收与暂不扩展范围

`godot-spatial` 中 `test_shen_rig_first.gd` 检查骨骼数量、父子关系、34 个 Rest Pose 坐标、持剑链、三段动画播放、根脚点不移动、以及停止动画后还原骨点。

`visual-evidence` 中 `capture_shen_rig_first.gd` 生成 `bind-pose.png`、`scene-overview.png` 和 3 个动作各 8 帧；`build_shen_rig_motion_gifs.py` 汇总 GIF 和关键帧。

当前阶段 **只验收骨架的几何/关节链及动作可播放**，尚不宣称这批骨架能够直接让 AI 生成分层素材自动达到正式美术质量。先人工验收骨骼线与四肢运动，再按模板画独立的透明 PNG 部件。只有素材装配后再做关节/蒙皮的二次视觉验收。

PR #99 保持 Draft，V1–V3 作为对照原型，不进入正式运行场景。
