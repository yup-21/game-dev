# 沈长风：从精灵关键帧到通用骨骼动作，再到分件素材（v2）

## 目的与顺序

此前 V1–V3 原型曾把固定攻击姿势切片直接挂在 Bone2D 上，导致肩肘腕无法独立活动，腿脚和衣摆错位。此阶段彻底改为：

1. **用原精灵图帧只作为动作姿势参考**，先通过无贴图的 22 Bone2D 通用人体实现动作关键姿势。
2. **人体动作验收之后**，以该骨架 Rest Pose 和各部件可见范围生成独立透明素材。不得再次从完整战斗帧中按矩形裁切出“上臂 + 前臂 + 剑”的复合件。
3. 每件贴图绑定到自己的骨骼或专用装饰骨骼，复验绑定姿势、全动画逐帧、刀剑轨迹与接地。

本阶段仓库只提交了第 1 步的真正可播放骨骼动画和第 2 步的精确生产输入规范；**尚未生成完成并验收的最终分件 PNG**，新素材仍为 candidate。

## 原版精灵动作来源

按 `data/native/animations/shen_changfeng.tres` 读取，图集源为 `assets/imported/candidates/2026-11-01/shen_changfeng/sprite_shen_changfeng_atlas_normalized_v02.png`（6×4，每格 256px）。

| 动作 | 精灵帧 | 骨骼改造焦点 |
| --- | --- | --- |
| idle | #1 | 稳定脚底、微呼吸、头颈反向补偿，无整体原地左右摇摆 |
| walk | #2、#3、#4、#5 | 精灵参考是偏奔跑的前倾步态：支撑、抬脚、摆腿、踩地；骨盆轻微前后位移与上下起伏；脚底不能穿地 |
| attack | #6、#7、#8 | 预备、蓄力、蹬地、挥剑、命中、收势；剑柄挂点而非复合剑臂贴图 |

构建参考板：

```bash
python3 tools/build_shen_action_reference_board.py
```

输出 `captures/shen-rig-first/original-sprite-motion-reference.png`。它是**参考图**，不是可直接绑定的身体贴图。

## 通用人体动作关键帧

关键姿势及角度由 `prototypes/humanoid_rig/motion_keyposes_v2.gd` 统一编写，`shen_skeleton_first.gd` 只负责调用和预览。所有骨骼键值使用 Godot 原生 `AnimationPlayer/AnimationLibrary`，保留既有 22 骨核心、可选 HairRig/CoatRig，不向核心增加装饰骨骼。

| Clip | 长度 | 姿势节点/时间 (s) | 主要约束 |
| --- | ---: | --- | --- |
| idle | 1.30 | 0、.325、.65、.975、1.30 | 小幅颈腰胸呼吸，左右腿/脚不移位，周期首尾一致 |
| walk | 0.80 | 每 .10s，0～.80 | 双腿按接地目标点解 2-bone IK，躯干前倾、双臂屈肘摆动以匹配原图快速移动；支撑脚不穿地，脚踝补偿保持脚掌方向 |
| attack_sword | 0.76 | 0、.12、.24、.36、.43、.57、.76 | .24 蓄力，.36 前挥，.43 命中，.57 收势，.76 回归标准姿势，骨盆前后位移而世界脚点固定 |

行走/攻击的实际关节角度取自“骨骼静态点 + 目标脚底位置”，每帧由余弦几何求解髋、膝、踝的旋转轨迹。它们**不再是人为随意摆动一整条腿的角度**。为了便于目视验收，输出图保留蓝色人体骨架、橙色装饰骨架，以及灰色剑柄/剑尖轨迹。脚底原点仍为 (0,0)，不更改角色移动范围、实际攻击距离、战斗单位。

注意：此 IK 是**离线预计算并写入 Animation 轨道的目标约束**，不是运行时新寻路算法；不影响正式战斗逻辑。动作播放顺序及 `play_motion()` 重置逻辑已统一，确保上一个 Clip 造成的骨盆位移不会污染下一个 Clip。

## 分件素材生产

`rig_contract.json` 是人体/附件骨点来源；`tools/build_shen_rig_art_templates.py` 生成严格的 `art_frames.json` 和 20 份分件绘制套版；`tools/build_shen_motion_asset_spec.py` 额外生成 `required-parts.json`，冻结每件源画布尺寸、pivot、遮挡层、骨骼父级、重叠区。

必须单件绘制的 16 类关键物件包括：head、torso、pelvis、前后上臂、前后前臂、前后手掌、前后大腿、前后小腿、前后靴、sword。头发与前/后/内衣摆分别在独立 Skeleton2D 里渲染；可以候选复用纹理，但 Mesh 权重必须依照本装饰骨架重做。

**制作禁令**：`attack_swing`、`guard_arms` 复合贴图不作为新蒙皮资产；不能用完整人物精灵图矩形裁切代替分件；不能自动剔除素材边缘透明空白而丢失 pivot；不能把剑和手腕画成不可拆的一张图。

正式美术生产仍遵循既有 `art-production` 标准和 candidate / in_use 状态，不增加新的元数据系统。

## 验收层级

- **动作阶段 P1**：`test_shen_motion_v2.gd` 检查待机接地、行走无脚底穿地、迈步幅度、周期接缝、出剑剑尖轨迹和肩肘腕协作、播放完恢复 Bind Pose；`capture_shen_rig_first.gd` 捕获骨架动作 24 帧并生成三段 GIF。
- **分件阶段 P2**：`required-parts.json` 中 16 个必需部件均为独立 RGBA 纹理，尺寸/pivot 与模板一致，头发和衣摆独立；静态关节接缝目视合格。
- **绑定阶段 P3**：实际在 Godot 用各节点纹理完成蒙皮，验证 idle/walk/attack 及各关键帧高低层遮挡，输出肩肘、髋膝踝、剑柄的局部放大图。人工视觉不合格则不能标为 in_use。

PR #99 保持 Draft。骨架技术测试通过不等于动作艺术质量或最终分件素材通过。
