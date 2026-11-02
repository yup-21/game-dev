# 沈长风既有素材 → 通用 22 骨人体：兼容性视觉验收

**结论：部分可复用，不可将旧 V2/V3 图集直接作为新 22 骨骨架的正式蒙皮。**

旧 V3 具有能辨认沈长风的侧身外观与已拆开的头、躯干、骨盆、腿、长发、长袍；但其视觉拼接仍基于 V2 自行估算的关节位置，不能满足通用肩→肘→腕和髋→膝→踝链的稳定蒙皮需求。旧攻击附件 `attack_swing` 是手臂与剑组合图片，不能单独随 `WeaponSocket` 转动。

## 验证方法

1. `checks/capture_shen_old_asset_compatibility.gd` 在完全一致的 Godot 世界脚点 `(800,730)` 和同一 200px 高度下，同时实例化现有 V3 角色与新 22 骨核心角色。
2. 隐藏新核心角色的舞台渲染，实时描绘其 22 根人体骨骼的关节到 **旧素材** 上；不改变旧图像的 pivot、缩放或贴图。
3. 同步播放 `idle`、`walk`、`attack_sword`，每个动作抽取 8 帧，分别导出关键帧总览和 GIF。
4. CI 自动生成 `captures/shen-rig-first/old-asset-compatibility/new-core-over-old-sprites.png`、`bind-with-new-core.png`、3 段 `*-retarget.gif`，并随 `unified-wuxia-hud-visual-evidence` artifact 上传。
5. 骨点准确性和关节运动必须通过**人工逐帧视觉审查**；CI 能保证图像生成，不等于所有旧部件具备可用蒙皮质量。

## 部件结论

| 旧素材 | 判断 | 下一步 |
| --- | --- | --- |
| `head` | 可作为外观基础 | 保留造型，按新 Head/Neck 枢轴校准 |
| `torso`、`pelvis`、`belt` | 有条件复用 | 和 Chest/Waist/Pelvis 对位，补肩髋遮挡边 |
| `arm_front`、`arm_back` | 不可直接用于三段手臂 | 需拆为上臂、前臂、独立手；肩肘腕重叠完善 |
| `attack_swing`（双手与剑组合） | 不可直接绑定新骨架 | 分离持剑手和剑，剑柄对齐 WeaponSocket |
| `thigh_*`、`shin_*`、`foot_*` | 有条件复用 | 轮廓可参考，但髋膝踝接缝/重叠需重绘校准，重测行走 |
| `hair_back` | 装饰候选 | 绑定到独立 HairRig，沿发束轮廓重建 Mesh，不占用人体骨骼 |
| `robe_left/right/inner` | 装饰候选 | 按独立 CoatRig 制作轮廓 Mesh/权重并验收遮挡；不直接复用旧矩形网格 |
| 原完整精灵图 / 帧动画 | 外观和动作参考 | 不能自动分离为 22 骨分件，可继续作为原 SpriteFrames 模式候选 |

## 视觉验收要求

- 待机：头颈、肩髋与素材真正重合；部件不会因为稍许摆动断裂。
- 行走：膝踝随新骨架移动时，旧靴子与腿部必须同步且不漏出明显空隙。
- 攻击：手部和武器柄点随肩、肘、腕链同步；剑不是整块自由附件。
- 两套装饰骨架的世界绑定点分别与 Head/HairSocket、Pelvis/CoatSocket 一致。
- 验收未过前不能把旧贴图标为 `in_use`，新图集仍是 `candidate`。

**本轮不要求重新生成整张人物立绘。** 建议先重绘手臂三段与单独武器，随后修正腿部膝踝接缝，再复查新旧素材混用效果。
