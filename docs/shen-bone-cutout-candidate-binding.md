# 沈长风：20 件骨骼分件候选 + Godot 绑定验证

## 实施性质与边界

这一阶段开始执行原定的“按骨骼拆分素材 → 绑定 → 视觉验收”，**不是将骨架上的几何矩形称作正式美术**。本次提供 20 张真实 RGBA 独立透明候选图，使用此前沈长风的真实发束、衣料和服装纹理作为底稿；针对肩肘、膝踝以及原图被遮挡部分做几何重叠补全。需要原画师再检查具体边缘、纹理与接缝；目前所有图片为 `candidate`，**不等于视觉定稿**。

### 准备画布与素材

从游戏仓库根目录执行：

```bash
python3 tools/build_shen_rig_art_templates.py
python3 tools/build_shen_motion_asset_spec.py
python3 tools/build_shen_bone_candidate_cutouts.py
```

输入：通用 22 骨 Rest Pose、20 类部件的四倍源图画布/pivot、旧版沈长风独立拆片 WebP 内容（仅作纹理参考；不回收复合持剑手臂）。

输出：
- `demos/changfeng-battle/prototypes/shen_rig_first/candidate_cutouts/`：`head/torso/pelvis`、前后上臂/前臂/手、大腿/小腿/靴、`sword`、`hair_back`、三片衣摆，一件一张透明 RGBA PNG，共 20 件。
- `candidate-manifest.json`：每件骨骼、绘图画布、pivot、z-index、严格候选状态。
- `captures/shen-rig-first/candidate-cutout-sheet.png`：20 件可视化检查页。

**重绘原则**：素材不来自旧一整条复合攻击手臂+剑；缺失关节遮挡内容用有遮盖的连续部件补齐。当前 PNG 是算法辅助重分件候选，因此一定要依靠播放和接缝验收确认是否需要人工补绘；它不自动通过美术质量门槛。武器单独绘制并挂载到 `WeaponSocket`。

### 在 Godot 预览真实绑骨

`res://prototypes/shen_rig_first/shen_candidate_bound_animation.tscn`

- `candidate_cutout_binding.gd` 根据 manifest 的 `attach_to_bone` 在 `Bone2D` 下分别生成 `Sprite2D`；每件不裁透明边界、不修改 pivot。
- 头发和三片衣摆是独立装饰骨架，使用 `Polygon2D` 权重，**不**加到 22 骨人体骨架里。
- 待机、行走、攻击沿用同一组人体骨骼动画；持剑是独立 Sprite2D，不再换掉整条手臂。

### CI 验收

- `checks/test_shen_candidate_binding.gd`：20 件真实 PNG 加载、15 件人体 +1 件剑 +1 件头发 +3 件衣摆的对应骨骼/挂点与层级、动画播放、标准脚点、恢复 Bind Pose。
- `checks/capture_shen_candidate_bound.gd`：真实 Godot 渲染，产出静态 bind pose、骨骼叠加图和三段动作 24 帧。
- `tools/build_shen_candidate_visual_evidence.py`：总览图和 3 段 GIF，以及明确的 `candidate_not_approved` 人工验收记录。

重点看前肩、后肩、肘部、膝部、脚踝、手剑柄、长袍下摆。原始图集 attack #6–8 的悬空靴子碎片不再用于生成骨骼分件的结构真值。此版本没有修改正式游戏角色，不将任何候选图注册为 `in_use`。

正式分件若要上线，还需结合上述截图人工精修，解决纹理拉伸、关节轮廓不自然、长袍遮挡与攻击手腕的错位。当前 PR #99 保持 Draft。
