# 2D 骨骼可视化编辑与真实拆件验收

本功能位于 Godot 原生 `Art Production Importer` 插件内的 **「2D 骨骼」Dock**。它从 `pose_templates` 已补绘的顾清霜 v6 JSON/PNG 读取姿态与绑定，在 Godot 中预览真人物拆件，并导出可继续原生编辑的候选 `.tscn`。

## 直接查看已提交的候选动画

1. 在 Godot 导入 `demos/changfeng-battle/project.godot`（项目声明 Godot 4.7；使用对应版本打开为宜）。
2. 在 FileSystem 打开：`assets/imported/characters/gu_qingshuang/rig2d/rig_pose_candidate.tscn`。
3. Scene 树中展开 `Skeleton2D`：有 25 个 `Bone2D`，每个子节点 `Art` 是引用真实 PNG 的 `Polygon2D`。点选骨骼并用 2D 编辑器检查肩、肘、腕和脚踝衔接。
4. 选择 `AnimationPlayer`，在底部动画时间轴切换 `idle`、`walk`、`run`、`attack_sweep` 等 **12 组动作**，播放或逐帧查看；每个部件的位置、旋转有可编辑的原生轨道。该候选场景直接引用仓库中的五张 PNG，无需单独克隆 `pose_templates` 才能查看。

这是 **独立候选**：不会自动替换游戏当前的 `SpriteFrames.tres`、`WuxiaActorAnimationProfile`、角色 Manifest 或在用 `battle_actor.tscn`，也不能将 F5 运行正式游戏当作这一候选的效果验收。

## 可视化修正左臂及绑定

1. 在本地检出包含顾清霜 v6 工程的 `pose_templates` 工作树，保证 `project_leftarm_v6_candidate.json`、`parts_leftarm_v6_candidate.json`、`source/*.png`、`art_v4/*/*.png` 和 `motion_reference_v5/*/motion.json` 相对路径不变。项目 JSON 是本次导入来源，不是 Godot 内的正式编辑权威。
2. 打开 Godot 右侧 **「2D 骨骼」** 标签，使用「浏览」选择本地 `project_leftarm_v6_candidate.json`，点击「读取部件和 12 组姿态」。
3. 选择动作、拖动帧进度或使用播放/暂停查看贴图与骨骼。画面中**黄色左肘、左腕**可拖动：左腕调整本帧手臂两段式 IK 目标；左肘在保持上臂长度的条件下改变弯曲方向及手腕终点。其它姿态帧保持不变。
4. 勾选「编辑部件绑定」，选择部件如 `left_upper_arm`、`left_forearm`、`left_hand`：
   - 画面显示来自 PNG 的原始裁切区域和绿色轮廓。
   - 拖动**橙色点**修改源图局部 `pivot`（旋转原点）；拖动**蓝色点**修改 `axis`（骨段末端）。
   - 也可在下方输入 `pivot_x / pivot_y / axis_x / axis_y / length_px / depth`，后者用于角色层叠排序。
5. 在底部填写**尚不存在的** `res://.../候选名.tscn`，点击「生成原生 Skeleton2D 候选场景」，确认后会在目标旁自动复制所需 PNG、等待 Godot 导入贴图并保存原生场景。点击「打开刚生成的原生场景」进入 Godot 2D / AnimationPlayer 编辑器。必须填写新文件名；工具会拒绝覆盖已在 Godot 修改的场景或内容不一致的贴图。

注意：内存中的拖动只是候选姿态，不会回写原有 JSON，也不会自动生成对应游戏运行时精灵帧。新导出的 `.tscn` 才是后续 Godot 原生编辑的保存结果。需要额外的结果图或 GIF，可在原生场景动画时间轴验收后再导出截图/采样帧。

[pose_templates PR #2](https://github.com/yup-21/pose_templates/pull/2) 另外提供六张**未配骨骼元数据**的补绘 PNG（包括六姿态参考表）。这批图与 v6 工程源 atlas 是**两组不同的文件**：本示例场景目前使用 v6 已登记的五张源 PNG，**尚未将 PR #2 的六张 PNG 自动替换或绑定到 25 个 Bone2D**。需要采用补绘部件时，须先在候选 `parts_*.json` 中登记对应贴图、裁切多边形、轴点和长度，再由本 Dock 重新导入并验收；不能仅因为文件名相似就猜测绑定。

## 第一版边界

- **已支持**：真实 25 拆件和 12 组动作预览、117 帧批量解析、左臂两段 IK 控制、部件局部轴点/骨长/层级微调、带真实 PNG 引用的原生 `Skeleton2D + Bone2D + Polygon2D + AnimationPlayer` 候选场景。
- **未支持**：全身每处关节的交互式 IK、网格蒙皮形变、直接在游戏正式角色中热替换、从 Godot 场景反向覆盖 `pose_templates` JSON。**所有 25 根 Bone2D 当前是 Skeleton2D 下的独立节点**：姿态由导出器按帧计算并烘焙，Godot 里可通过时间轴单独调骨骼；它不是已配置完整父子传递/蒙皮权重的高级骨架。
- 源 JSON 里的多个帧若存在透视部件缺失、前后手层次错误或布料遮挡，即使 IK 算法正确仍需美术手工验收，工具不把自动测试成功等同于动画质感验收。

## 测试

候选场景始终可运行资源加载测试：

```bash
godot --headless --path demos/changfeng-battle --script res://checks/test_rig2d_pose_editor.gd
```

在本地有配套 `pose_templates` 工程时，还能逐帧计算全部姿态、检查导入约束、左腕拖动与防覆盖：

```bash
RIG2D_TEST_PROJECT=/absolute/path/to/pose_templates/rig2d/gu-qingshuang-v6/project_leftarm_v6_candidate.json \
  godot --headless --path demos/changfeng-battle --script res://checks/test_rig2d_pose_editor.gd
```

结构测试验证资源和数值；具体手肘弯曲、手腕方向、脚尖接地与剪影仍需以 Godot 预览逐帧人工验收。
